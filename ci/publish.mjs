import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const github = 'https://api.github.com/repos/brsvh/infix';
const storePath = /^\/nix\/store\/[0-9a-df-np-sv-z]{32}-[^/\s]+$/;
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

function transientNixError(stderr) {
  // Nix reports these failures without an "error:" prefix.
  if (/^path '[^\n]+' (?:was modified!|is untrusted)/m.test(stderr)) {
    return false;
  }

  const errors = stderr.match(/^error: .*$(?:\n[ \t]+.*$)*/gm) ?? [];
  const permanent = new RegExp(
    [
      'certificate|signature|hash mismatch|corrupt',
      'permission denied|no space left|HTTP (?:error )?(?:401|403)\\b',
    ].join('|'),
    'i',
  );
  const transient = new RegExp(
    [
      'connection (?:reset|refused|timed out)|timeout was reached',
      'temporary failure in name resolution|unexpected eof while reading',
      'HTTP (?:error )?(?:408|429|5\\d\\d)\\b',
    ].join('|'),
    'i',
  );

  return (
    errors.length > 0
    && errors.every((error) => !permanent.test(error) && transient.test(error))
  );
}

async function retry(name, stage, operation) {
  for (let attempt = 0; ; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      if (!error.retryable || attempt === 5) {
        throw new Error(`${name}: ${stage}: ${error.message}`, {
          cause: error,
        });
      }

      console.warn(
        `${name}: ${stage}: ${error.message}; retry ${attempt + 1}/5 in 60s`,
      );
      await sleep(60000);
    }
  }
}

async function currentRevision(rev, token) {
  let response;
  let body;

  try {
    response = await fetch(`${github}/git/ref/heads/main`, {
      headers: {
        authorization: `Bearer ${token}`,
        'user-agent': 'infix-ci',
      },
      redirect: 'error',
      signal: AbortSignal.timeout(30000),
    });

    if (response.ok) {
      body = await response.text();
    } else {
      // An error-body transport failure must not override the HTTP status.
      await response.body?.cancel().catch(() => undefined);
    }
  } catch (error) {
    const code = error.cause?.code ?? error.code ?? error.name;
    const failure = new Error(`Cannot read main: ${code}`);
    failure.retryable = networkCodes.has(code);
    throw failure;
  }

  if (!response.ok) {
    const error = new Error(`GitHub returned HTTP ${response.status}`);
    error.retryable =
      [
        408,
        429,
      ].includes(response.status)
      || (response.status >= 500 && response.status < 600);
    throw error;
  }

  const head = JSON.parse(body)?.object?.sha;

  if (typeof head !== 'string' || !/^[0-9a-f]{40}$/.test(head)) {
    throw new Error('GitHub returned an invalid main revision');
  }

  return head === rev;
}

async function nix(args, paths) {
  const child = spawn(
    'nix',
    [
      '--log-format',
      'raw',
      ...args,
      '--stdin',
    ],
    {
      stdio: [
        'pipe',
        'pipe',
        'pipe',
      ],
    },
  );
  let stdout = '';
  let stderr = '';
  let inputError;

  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  child.stdout.on('data', (chunk) => {
    stdout += chunk;
  });
  child.stderr.on('data', (chunk) => {
    process.stderr.write(chunk);
    stderr += chunk;
  });

  const result = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', (code, signal) => {
      resolve({
        code,
        signal,
      });
    });
    child.stdin.on('error', (error) => {
      inputError = error;

      if (error.code !== 'EPIPE') {
        child.kill();
      }
    });
    child.stdin.end(`${paths.join('\n')}\n`);
  });

  if (inputError && (inputError.code !== 'EPIPE' || result.code === 0)) {
    throw new Error(`Cannot send store paths to Nix: ${inputError.code}`, {
      cause: inputError,
    });
  }

  if (result.code !== 0) {
    const error = new Error(
      `nix ${args[0]} failed (${
        result.signal ?? result.code
      }); see the preceding diagnostic`,
    );
    // Startup errors use 1; verification I/O failures use 4.  Composite
    // verification failures and interrupted processes must not be retried.
    const retryableStatus =
      result.code === 1
      || (args[0] === 'store' && args[1] === 'verify' && result.code === 4);
    error.retryable =
      !result.signal && retryableStatus && transientNixError(stderr);
    throw error;
  }

  return stdout;
}

function metadata(value, item) {
  if (
    !value
    || typeof value.narHash !== 'string'
    || !Number.isSafeInteger(value.narSize)
    || value.narSize < 0
    || !Array.isArray(value.references)
    || !value.references.every((reference) => storePath.test(reference))
  ) {
    throw new Error(`Invalid store path metadata: ${item}`);
  }

  return {
    narHash: value.narHash,
    narSize: value.narSize,
    references: [
      ...value.references,
    ].sort(),
  };
}

async function publish({ cache, name, rev, roots }) {
  if (
    process.env.HERCULES_CI_PROJECT_PATH !== 'github/brsvh/infix'
    || !/^[a-z0-9-]+$/.test(name ?? '')
    || !/^[0-9a-f]{40}$/.test(rev ?? '')
    || cache?.url !== 'https://cache.bingshan.org'
    || typeof cache.publicKey !== 'string'
    || !Array.isArray(roots)
    || roots.length === 0
    || !roots.every((root) => storePath.test(root))
  ) {
    throw new Error('Invalid publication context');
  }

  let secrets;

  try {
    secrets = JSON.parse(
      await fs.readFile(process.env.HERCULES_CI_SECRETS_JSON, 'utf8'),
    );
  } catch (error) {
    throw new Error('Cannot read Effect credentials', {
      cause: error,
    });
  }

  const token = secrets?.git?.data?.token;

  if (typeof token !== 'string' || !token) {
    throw new Error('Missing GitHub credential');
  }

  if (!(await retry(name, 'Check main', () => currentRevision(rev, token)))) {
    console.log(`${name}: skipped superseded main revision ${rev}`);
    return;
  }

  const source = JSON.parse(
    await nix(
      [
        'path-info',
        '--recursive',
        '--json',
        '--json-format',
        '1',
      ],
      roots,
    ),
  );
  const paths = Object.keys(source);

  if (
    !roots.every((root) => source[root])
    || !paths.every((item) => storePath.test(item))
  ) {
    throw new Error(`${name}: local closure is incomplete`);
  }

  for (const item of paths) {
    source[item] = metadata(source[item], item);

    if (!source[item].references.every((reference) => source[reference])) {
      throw new Error(
        `${name}: local closure is missing references of ${item}`,
      );
    }
  }

  const remote = [
    '--store',
    cache.url,
    '--option',
    'narinfo-cache-negative-ttl',
    '0',
    '--option',
    'narinfo-cache-positive-ttl',
    '0',
  ];
  const verification = [
    'store',
    'verify',
    '--sigs-needed',
    '1',
    ...remote,
    '--option',
    'trusted-public-keys',
    cache.publicKey,
  ];

  async function inspectCache() {
    const published = JSON.parse(
      await nix(
        [
          'path-info',
          '--json',
          '--json-format',
          '1',
          ...remote,
        ],
        paths,
      ),
    );
    const missing = [];
    const present = [];

    for (const item of paths) {
      if (published[item] === null) {
        missing.push(item);
        continue;
      }

      const expected = source[item];
      const actual = metadata(published[item], item);
      const differences = Object.keys(expected).filter(
        (field) =>
          JSON.stringify(expected[field]) !== JSON.stringify(actual[field]),
      );

      if (differences.length > 0) {
        throw new Error(
          `Cache metadata mismatch: ${item}: ` + differences.join(', '),
        );
      }

      present.push(item);
    }

    if (present.length > 0) {
      await nix(
        [
          ...verification,
          '--no-contents',
        ],
        present,
      );
    }

    return missing;
  }

  let directory;
  let uploadAttempted = false;

  try {
    const current = await retry(name, 'Publish cache', async () => {
      const missing = await inspectCache();

      if (missing.length === 0) {
        return true;
      }

      if (!(await currentRevision(rev, token))) {
        return false;
      }

      if (!directory) {
        const netrc = secrets['public-cache']?.data?.netrc;

        if (typeof netrc !== 'string' || !netrc) {
          throw new Error('Missing public cache credential');
        }

        directory = await fs.mkdtemp(path.join(os.tmpdir(), 'infix-cache-'));
        await fs.writeFile(path.join(directory, 'netrc'), netrc, {
          mode: 0o600,
        });
      }

      console.log(`${name}: uploading ${missing.length} missing closure paths`);
      uploadAttempted = true;
      await nix(
        [
          'copy',
          '--to',
          `${cache.url}?compression=zstd`,
          '--option',
          'netrc-file',
          path.join(directory, 'netrc'),
        ],
        roots,
      );
      return true;
    });

    if (!current) {
      console.log(`${name}: skipped superseded main revision ${rev}`);
      return;
    }

    if (uploadAttempted) {
      await retry(name, 'Verify published closure', async () => {
        const missing = await inspectCache();

        if (missing.length > 0) {
          throw new Error(`Cache is still missing: ${missing.join(', ')}`);
        }
      });

      // Verify one complete NAR, preserving the existing download probe.
      const probe = roots.reduce((smallest, root) =>
        source[root].narSize < source[smallest].narSize ? root : smallest,
      );
      await retry(name, 'Download probe', () =>
        nix(verification, [
          probe,
        ]),
      );
      console.log(`${name}: published and verified ${rev}`);
    } else {
      console.log(`${name}: cache metadata and signatures already verified`);
    }
  } finally {
    if (directory) {
      await fs.rm(directory, {
        recursive: true,
        force: true,
      });
    }
  }
}

try {
  await publish(JSON.parse(await fs.readFile(process.argv[2], 'utf8')));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
