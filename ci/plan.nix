{
  cache,
  hci-effects,
  packages,
  pkgs,
  rev,
}:
let
  inherit (pkgs.lib)
    toJSON
    ;

  metadata =
    pkgs.writeText "package-metadata.json"
      (toJSON {
        inherit
          cache
          packages
          rev
          ;
      });

  plan = pkgs.writeText "plan.mjs" ''
    import fs from 'node:fs';
    import { randomUUID } from 'node:crypto';
    import { spawnSync } from 'node:child_process';

    const { cache, packages, rev } = JSON.parse(
      fs.readFileSync(process.argv[2], 'utf8'),
    );
    const secrets = JSON.parse(
      fs.readFileSync(process.env.HERCULES_CI_SECRETS_JSON, 'utf8'),
    );
    const gitToken = secrets.git?.data.token;
    const stateToken = secrets['hercules-ci']?.data.token;
    const github = 'https://api.github.com/repos/brsvh/infix';
    const stateApi = process.env.HERCULES_CI_API_BASE_URL +
      '/api/v1/current-task/state';

    if (
      process.env.HERCULES_CI_PROJECT_PATH !== 'github/brsvh/infix' ||
      !/^[0-9a-f]{40}$/.test(rev) || !gitToken || !stateToken
    ) {
      throw new Error('Invalid planning context or missing credentials');
    }

    async function request(url, token, options = {}) {
      const {
        method = 'GET', body, missing = false,
        contentType = 'application/json',
      } = options;
      const response = await fetch(url, {
        method,
        headers: {
          authorization: `Bearer ''${token}`,
          'user-agent': 'infix-ci',
          ...(body === undefined ? {} : { 'content-type': contentType }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(30000),
      });

      if (missing && response.status === 404) {
        return null;
      }

      if (!response.ok) {
        throw new Error(`''${method} failed with HTTP ''${response.status}`);
      }

      const text = await response.text();
      return text ? JSON.parse(text) : null;
    }

    async function assertCurrent() {
      const head = await request(`''${github}/git/ref/heads/main`, gitToken);

      if (head.object.sha !== rev) {
        throw new Error('Superseded main revision');
      }
    }

    async function rootsAvailable(outputs) {
      for (const output of outputs) {
        const hash = output.match(/^\/nix\/store\/([0-9a-df-np-sv-z]{32})-/);

        if (!hash) {
          throw new Error('Invalid package output path');
        }

        const response = await fetch(`''${cache.url}/''${hash[1]}.narinfo`, {
          method: 'HEAD',
          signal: AbortSignal.timeout(30000),
        });

        if (response.status === 404) {
          return false;
        }

        if (!response.ok) {
          throw new Error(`Cache returned HTTP ''${response.status}`);
        }
      }

      return true;
    }

    async function alreadyPublished(outputs) {
      if (!(await rootsAvailable(outputs))) {
        return false;
      }

      // Bootstrap from signed closures, without scheduling every package.
      const result = spawnSync('nix', [
        'store', 'verify', '--recursive', '--no-contents', '--sigs-needed',
        '1', '--store', cache.url, '--option', 'trusted-public-keys',
        cache.publicKey, ...outputs,
      ], { stdio: 'inherit' });

      if (result.error) {
        throw result.error;
      }

      return result.status === 0;
    }

    await assertCurrent();
    const requestId = randomUUID();
    let selected = 0;

    for (const [name, packageInfo] of Object.entries(packages)) {
      if (!/^[a-z0-9-]+$/.test(name)) {
        throw new Error(`Invalid package name: ''${name}`);
      }

      const stateUrl = `''${stateApi}/published-''${name}/data`;
      const previous = await request(stateUrl, stateToken, { missing: true });

      if (previous !== null && previous.version !== 1) {
        throw new Error(`Unsupported publication state for ''${name}`);
      }

      if (
        previous?.drvPath === packageInfo.drvPath &&
        previous.cache?.url === cache.url &&
        previous.cache?.publicKey === cache.publicKey &&
        await rootsAvailable(packageInfo.outputs)
      ) {
        console.log(`Unchanged: ''${name}`);
        continue;
      }

      if (previous === null && await alreadyPublished(packageInfo.outputs)) {
        await assertCurrent();
        await request(stateUrl, stateToken, {
          method: 'PUT',
          contentType: 'application/octet-stream',
          body: { version: 1, cache, drvPath: packageInfo.drvPath, rev },
        });
        console.log(`Recorded existing publication: ''${name}`);
        continue;
      }

      await assertCurrent();
      const tag = `ci/package/''${name}/''${rev}/''${requestId}`;
      await request(`''${github}/git/refs`, gitToken, {
        method: 'POST',
        body: { ref: `refs/tags/''${tag}`, sha: rev },
      });
      selected += 1;
      console.log(`Requested build and publication: ''${name}`);
    }

    // Do not wait for child Effects: Hercules runs repository Effects in order.
    console.log(`Scheduled ''${selected} affected packages`);
  '';
in
hci-effects.mkEffect {
  name = "plan-infix-packages";
  dontUnpack = true;

  inputs = with pkgs; [
    nix
    nodejs
  ];

  secretsMap = {
    git = {
      type = "GitToken";
    };
  };

  NIX_CONFIG = ''
    experimental-features = nix-command
    narinfo-cache-negative-ttl = 0
  '';

  effectScript = ''
    node ${plan} ${metadata}
  '';
}
