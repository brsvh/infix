{
  cache,
  drvPath,
  hci-effects,
  name,
  outputs,
  pkgs,
  rev,
  tag,
}:
let
  inherit (pkgs.lib)
    attrValues
    concatMapStringsSep
    toJSON
    ;

  state =
    pkgs.writeText "published-${name}.json"
      (toJSON {
        inherit
          cache
          drvPath
          rev
          ;

        version = 1;
      });

  request =
    pkgs.writeText "publish-request.json"
      (toJSON {
        inherit
          name
          rev
          tag
          ;
      });

  prepare = pkgs.writeText "prepare-publication.mjs" ''
    import fs from 'node:fs';

    const { name, rev, tag } = JSON.parse(
      fs.readFileSync(process.argv[2], 'utf8'),
    );
    const secrets = JSON.parse(
      fs.readFileSync(process.env.HERCULES_CI_SECRETS_JSON, 'utf8'),
    );
    const token = secrets.git?.data.token;
    const github = 'https://api.github.com/repos/brsvh/infix';
    const expected = `ci/package/''${name}/''${rev}/`;

    if (
      process.env.HERCULES_CI_PROJECT_PATH !== 'github/brsvh/infix' ||
      !/^[a-z0-9-]+$/.test(name) || !/^[0-9a-f]{40}$/.test(rev) ||
      !tag.startsWith(expected) ||
      !/^[0-9a-f-]{36}$/.test(tag.slice(expected.length)) || !token
    ) {
      throw new Error('Invalid publication context');
    }

    async function githubRequest(path, method = 'GET', missing = false) {
      const response = await fetch(`''${github}/''${path}`, {
        method,
        headers: {
          authorization: `Bearer ''${token}`,
          'user-agent': 'infix-ci',
        },
        signal: AbortSignal.timeout(30000),
      });

      if (missing && response.status === 404) {
        return null;
      }

      if (method === 'DELETE' && response.status === 422) {
        const ref = await githubRequest(
          path.replace('git/refs/', 'git/ref/'), 'GET', true,
        );

        if (ref === null) {
          return null;
        }
      }

      if (!response.ok) {
        throw new Error(`GitHub returned HTTP ''${response.status}`);
      }

      return response.status === 204 ? null : response.json();
    }

    const head = await githubRequest('git/ref/heads/main');
    // Remove the trigger after its builds, while the GitToken is still fresh.
    await githubRequest(`git/refs/tags/''${tag}`, 'DELETE');

    if (head.object.sha === rev) {
      fs.writeFileSync('publish-current', "");
    } else {
      console.log('Skipping publication from a superseded main revision');
    }
  '';
in
hci-effects.mkEffect {
  name = "publish-${name}";
  dontUnpack = true;

  inputs = with pkgs; [
    jq
    nix
    nodejs
  ];

  # Referencing every output makes it a build dependency of the effect.
  ROOTS =
    pkgs.writeText "${name}-public-cache-roots"
      (
        concatMapStringsSep "\n" toString (
          attrValues outputs
        )
        + "\n"
      );

  secretsMap = {
    git = {
      type = "GitToken";
    };

    public-cache = "public-cache-upload";
  };

  NIX_CONFIG = ''
    experimental-features = nix-command
    narinfo-cache-negative-ttl = 0
    narinfo-cache-positive-ttl = 0
  '';

  effectScript = ''
    (
      set -euo pipefail
      umask 077
      node ${prepare} ${request}

      if [[ ! -f publish-current ]]; then
        exit 0
      fi

      public=${cache.url}
      key=${cache.publicKey}

      nix path-info --recursive --json --json-format 1 \
        --stdin < "$ROOTS" > source.json

      verifyMetadata() {
        jq -e --slurpfile source source.json '
          def metadata: map_values({narHash, narSize, references});
          metadata == ($source[0] | metadata)
        ' published.json > /dev/null
      }

      verifySignatures() {
        nix store verify --recursive --no-contents --sigs-needed 1 \
          --store "$public" --option trusted-public-keys "$key" \
          --stdin < "$ROOTS"
      }

      if nix path-info --recursive --json --json-format 1 \
          --store "$public" --stdin < "$ROOTS" > published.json \
        && verifyMetadata && verifySignatures; then
        echo "The package closure is already available in the public cache."
      else
        credential=$(mktemp)
        trap 'rm -f "$credential"' EXIT
        readSecretString public-cache .netrc > "$credential"
        nix copy --to "$public?compression=zstd" \
          --option netrc-file "$credential" --stdin < "$ROOTS"
        rm -f "$credential"
        trap - EXIT

        nix path-info --recursive --json --json-format 1 \
          --store "$public" --stdin < "$ROOTS" > published.json
        verifyMetadata
        verifySignatures

        probe=$(jq -r --rawfile roots "$ROOTS" '
          . as $closure | $roots | split("\n") | map(select(. != "")) |
          min_by($closure[.].narSize)
        ' source.json)
        nix store verify --sigs-needed 1 --store "$public" \
          --option trusted-public-keys "$key" "$probe"
        echo "The package closure has been published and verified."
      fi

      # A failed build, upload, or verification must not advance the baseline.
      putStateFile published-${name} ${state}
    )
  '';
}
