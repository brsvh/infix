import { setTimeout as delay } from 'node:timers/promises';
import { stripVTControlCharacters } from 'node:util';

const networkCodes = new Set([
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EAI_AGAIN',
  'UND_ERR_CONNECT_TIMEOUT',
  'UND_ERR_HEADERS_TIMEOUT',
  'UND_ERR_BODY_TIMEOUT',
  'UND_ERR_SOCKET',
  'TimeoutError',
  'ERR_SSL_UNEXPECTED_EOF_WHILE_READING',
]);

function requestRejected(error) {
  return error.status >= 400 && error.status < 500 && error.status !== 408;
}

function kind(job) {
  return job.jobType === 'Legacy' ? 'Config' : job.jobType;
}

function sameTask(job, source) {
  return (
    job.projectId === source.projectId
    && job.ownerName === source.ownerName
    && job.repoName === source.repoName
    && job.source.ref === source.source.ref
    && job.source.revision === source.source.revision
    && kind(job) === kind(source)
    && job.jobName === source.jobName
  );
}

async function jobHistory(api, revision) {
  const project = '/site/github/account/brsvh/project/infix';
  const query = new URLSearchParams({
    rev: revision,
    limit: '100',
  });
  const jobs = [];

  for (let page = 0; page < 10; page += 1) {
    const { items } = await api(`${project}/jobs?${query}`);
    jobs.push(...items);

    if (items.length < 100) {
      return jobs;
    }

    query.set('offsetIndex', String(items.at(-1).index));
  }

  throw new Error('Too many jobs to establish the Hercules rerun history');
}

function jobFamily(source, jobs) {
  const tasks = jobs.filter((job) => sameTask(job, source));
  const byId = new Map(
    tasks.map((job) => [
      job.id,
      job,
    ]),
  );

  for (const job of tasks) {
    if (job.rerunOf) {
      const parent = byId.get(job.rerunOf);

      if (!parent || parent.index >= job.index) {
        throw new Error('Incomplete or invalid Hercules rerun history');
      }
    }
  }

  let root = source;

  while (root.rerunOf) {
    root = byId.get(root.rerunOf);
  }

  const family = new Map([
    [
      root.id,
      root,
    ],
  ]);

  for (const job of tasks.toSorted((a, b) => a.index - b.index)) {
    if (family.has(job.rerunOf)) {
      family.set(job.id, job);
    }
  }

  if (!family.has(source.id)) {
    throw new Error('The source job is outside its Hercules rerun family');
  }

  return {
    root,
    jobs: [
      ...family.values(),
    ],
  };
}

async function rerunJob(api, source, jobs) {
  const { root } = jobFamily(source, jobs);
  const before = new Set(jobs.map((job) => job.id));
  let created;

  try {
    created = await api(`/jobs/${source.id}/rerun`, {
      method: 'POST',
    });
  } catch (error) {
    if (requestRejected(error)) {
      throw error;
    }

    // A lost POST response must not cause another rerun request.
    for (let attempt = 0; attempt < 4 && !created; attempt += 1) {
      await delay(3000);
      let history;

      try {
        history = await jobHistory(api, source.source.revision);
      } catch (cause) {
        // A rejected GET says nothing about whether the POST was accepted.
        throw new Error('Rerun response lost and history unavailable', {
          cause,
        });
      }

      const matches = history.filter(
        (job) =>
          !before.has(job.id)
          && sameTask(job, source)
          && job.rerunOf === root.id,
      );

      if (matches.length > 1) {
        throw new Error('Multiple new Hercules reruns; inspect them manually', {
          cause: error,
        });
      }

      [created] = matches;
    }

    if (!created) {
      throw error;
    }
  }

  if (
    before.has(created.id)
    || !sameTask(created, source)
    || created.rerunOf !== root.id
    || created.index <= source.index
    || created.isCancelled
  ) {
    throw new Error('Unexpected Hercules rerun result');
  }

  return created;
}

export default async function ({ github, context, core }) {
  const { payload } = context;
  const revision = payload.sha;
  const jobBase = 'https://hercules-ci.com/github/brsvh/infix/jobs/';
  const target = payload.target_url;

  if (
    context.eventName !== 'status'
    || context.ref !== 'refs/heads/main'
    || context.repo.owner !== 'brsvh'
    || context.repo.repo !== 'infix'
    || typeof payload.context !== 'string'
    || !payload.context.startsWith('ci/hercules/')
    || ![
      'failure',
      'error',
    ].includes(payload.state)
    || !/^[0-9a-f]{40}$/.test(revision)
    || typeof target !== 'string'
    || !target.startsWith(jobBase)
    || !/^[1-9][0-9]*$/.test(target.slice(jobBase.length))
  ) {
    throw new Error('Invalid Hercules evaluation status');
  }

  const token = process.env.HERCULES_CI_API_TOKEN;

  if (!token) {
    throw new Error('Configure HERCULES_CI_API_TOKEN in ci-retry');
  }

  const herculesApi = 'https://hercules-ci.com/api/v1';
  const interval = 60000;
  const limit = 5;

  async function read(operation) {
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await operation();
      } catch (error) {
        // Octokit wraps transport errors in a synthetic HTTP 500.  Only
        // its response status represents an actual server response.
        const failure =
          error.name === 'HttpError' && !error.response ? error.cause : error;
        const code = failure?.cause?.code ?? failure?.code;
        const type = typeof code === 'string' ? code : failure?.name;
        const status =
          failure?.name === 'AbortError' ? undefined : failure?.status;
        const retryable = Number.isInteger(status)
          ? [
              408,
              429,
            ].includes(status)
            || (status >= 500 && status < 600)
          : networkCodes.has(type);

        if (attempt === 2 || !retryable) {
          throw error;
        }

        core.info('Retrying a CI API read in one minute.');
        await delay(interval);
      }
    }
  }

  async function request(path, { method = 'GET' } = {}) {
    const response = await fetch(`${herculesApi}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${token}`,
        'user-agent': 'infix-ci',
      },
      redirect: 'error',
      signal: AbortSignal.timeout(30000),
    });

    if (!response.ok) {
      await response.body?.cancel().catch(() => undefined);
      const error = new Error(`Hercules returned HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }

    return response.json();
  }

  const api = (path, options = {}) =>
    (options.method ?? 'GET') === 'GET'
      ? read(() => request(path, options))
      : request(path, options);

  async function currentJobs() {
    // Retry both reads together so a delayed branch read cannot leave us
    // acting on task history from before a manual or automatic rerun.
    return read(async () => {
      const jobs = await jobHistory(request, revision);
      const { data } = await github.rest.git.getRef({
        ...context.repo,
        ref: 'heads/main',
        request: {
          signal: AbortSignal.timeout(30000),
          redirect: 'error',
        },
      });

      return data.object.sha === revision ? jobs : null;
    });
  }

  function eligible(job) {
    return (
      job?.ownerName === 'brsvh'
      && job.repoName === 'infix'
      && /^[0-9a-f-]{36}$/.test(job.id)
      && job.source.revision === revision
      && job.source.ref === 'refs/heads/main'
      && (([
        'Config',
        'Legacy',
      ].includes(job.jobType)
        && job.jobName === null)
        || (job.jobType === 'OnPush'
          && (job.jobName === 'checkFlake'
            || /^(?:buildPackage|publishPackage)\/[a-z0-9-]+$/.test(
              job.jobName,
            ))))
    );
  }

  function failed(job) {
    return (
      eligible(job)
      && !job.isCancelled
      && job.jobPhase === 'Done'
      && job.jobStatus === 'Failure'
      && job.evaluationStatus === 'Failure'
    );
  }

  async function skip(reason) {
    core.info(reason);
    await core.summary.addHeading('No automatic retry').addRaw(reason).write();
  }

  let jobs = await currentJobs();

  if (!jobs) {
    await skip('The branch has moved to another revision.');
    return;
  }

  const index = Number(target.slice(jobBase.length));
  const source = jobs.find((job) => job.index === index);

  if (!failed(source)) {
    await skip('The job is not a failed repository evaluation.');
    return;
  }

  function budget(history) {
    const { root, jobs: family } = jobFamily(source, history);

    if (
      history.some(
        (job) =>
          sameTask(job, source)
          && (job.index > source.index
            || (!job.isCancelled && job.jobPhase !== 'Done')
            || job.evaluationStatus === 'Success'),
      )
    ) {
      return null;
    }

    // Retrying configuration after handlers were created could replay Effects.
    if (
      source.jobName === null
      && history.some(
        (job) =>
          job.projectId === source.projectId
          && job.source.ref === source.source.ref
          && job.source.revision === revision
          && job.jobType === 'OnPush',
      )
    ) {
      return null;
    }

    return {
      root,
      attempts: family.length - 1,
    };
  }

  let remaining = budget(jobs);

  if (!remaining || remaining.attempts >= limit) {
    await skip('Retry blocked by task history or the five-retry limit.');
    return;
  }

  const evaluation = await api(`/jobs/${source.id}/evaluation`);
  const attributes = evaluation.attributes;
  const message = attributes?.[0]?.value?.Error?.errorMessage;

  const input =
    typeof message === 'string'
      ? stripVTControlCharacters(message).match(
          /while fetching the input '([^']+)'/,
        )?.[1]
      : null;
  const repository = 'git+https://github.com/brsvh/infix.git';
  const url = input?.startsWith(`${repository}?`) ? new URL(input) : null;

  if (
    attributes?.length !== 1
    || attributes[0].path.length !== 0
    || !url
    || url.searchParams.get('rev') !== revision
    || url.searchParams.get('ref') !== source.source.ref
    || !stripVTControlCharacters(message).includes(
      'Failed to fetch git repository',
    )
    || Object.keys(evaluation.derivations).length !== 0
    || evaluation.evaluationDependencies.length !== 0
    || evaluation.ifdAttributes.length !== 0
  ) {
    await skip('The failure is outside the initial repository fetch.');
    return;
  }

  const logId = evaluation.evaluationLog;

  if (!/^[0-9a-f-]{36}$/.test(logId)) {
    throw new Error('Missing evaluation log');
  }

  const log = await api(
    `/jobs/${source.id}/evaluation/log/lines?logId=${logId}`,
  );

  if (
    !log.done
    || log.id !== logId
    || !Array.isArray(log.lines)
    || !log.lines.every(
      (line, index) => line.i === index && typeof line.t === 'string',
    )
  ) {
    throw new Error('The evaluation log is incomplete');
  }

  const text = stripVTControlCharacters(
    log.lines.map((line) => line.t).join('\n'),
  );
  const permanent = [
    /authentication failed|permission denied|access denied/i,
    /could not read (?:username|password)|repository .*not found/i,
    /requested URL returned error: (?:400|401|403|404|410)\b/i,
    /curl (?:51|60)\b|SSL (?:certificate problem|peer certificate)/i,
    /certificate (?:verify|verification) failed|certificate has expired/i,
    /certificate is not yet valid|unable to get local issuer certificate/i,
    /couldn't find remote ref|not our ref|hash mismatch/i,
    /no space left on device|disk quota exceeded/i,
  ];
  const transient = [
    [
      'HTTP/2 stream interrupted',
      /curl 92\b|HTTP\/2 stream .*reset/i,
    ],
    [
      'TLS connection interrupted',
      /\b(?:TLS|SSL)[^\r\n]*\bunexpected EOF while reading\b/i,
    ],
    [
      'Git transfer interrupted',
      /early EOF|unexpected disconnect/i,
    ],
    [
      'Connection reset',
      /connection reset|recv failure|send failure/i,
    ],
    [
      'Connection timed out',
      /timed? out|curl 28\b/i,
    ],
    [
      'Temporary DNS failure',
      /could not resolve (?:host|proxy)|temporary failure in name resolution/i,
    ],
    [
      'Temporary HTTP failure',
      /returned error: (?:408|429|5\d\d)\b/i,
    ],
  ];
  const diagnostics = text
    .split('\n')
    .filter((line) => /^\s*(?:remote: )?(?:error|fatal):/i.test(line));
  const reason = transient.find(([, pattern]) =>
    diagnostics.some((line) => pattern.test(line)),
  )?.[0];
  // Git can report this consequence after a confirmed interrupted transfer.
  const consequence = /^fatal: (?:fetch-pack: )?invalid index-pack output$/i;

  if (
    !reason
    || permanent.some((pattern) => pattern.test(text))
    || !diagnostics.every(
      (line) =>
        transient.some(([, pattern]) => pattern.test(line))
        || consequence.test(line.trim()),
    )
  ) {
    await skip('No recognized transient source-fetch failure was found.');
    return;
  }

  core.info(`${reason}; waiting one minute before retrying.`);
  await delay(interval);
  jobs = await currentJobs();
  remaining = jobs && budget(jobs);

  if (
    !remaining
    || !failed(jobs.find((job) => job.id === source.id))
    || remaining.attempts >= limit
  ) {
    await skip('The job was superseded, cancelled or has no retries left.');
    return;
  }

  const created = await rerunJob(api, source, jobs);

  await core.summary
    .addHeading(`Source fetch retry ${remaining.attempts + 1}/${limit}`)
    .addRaw(`${reason}. Revision: ${revision}.\n\n`)
    .addLink('Original job', jobBase + remaining.root.index)
    .addRaw('\n\n')
    .addLink(`Hercules job ${created.index}`, jobBase + created.index)
    .write();
}
