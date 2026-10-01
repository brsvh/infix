{
  hci-effects,
  name,
  outputs,
  pkgs,
}:
let
  inherit (pkgs.lib)
    attrValues
    concatMapStringsSep
    ;

  publicKey = "cache.bingshan.org-1:HqcG/vJ7jeSLU48jV4yg8Ot+rUPP2v0vIAAnDEqVSvk=";
in
hci-effects.mkEffect {
  name = "publish-${name}";
  dontUnpack = true;

  inputs = with pkgs; [
    jq
    nix
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
      public=https://cache.bingshan.org
      key=${publicKey}

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
    )
  '';
}
