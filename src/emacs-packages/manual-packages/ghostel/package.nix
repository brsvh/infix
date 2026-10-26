{
  fetchurl,
  lib,
  runCommandLocal,
  upstreamGhostel,
}:
let
  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    importJSON
    ;
in
upstreamGhostel.overrideAttrs (
  finalAttrs: prevAttrs: {
    passthru = prevAttrs.passthru // {
      module = prevAttrs.passthru.module.overrideAttrs (
        moduleFinalAttrs: modulePrevAttrs: {
          # Zig 0.16 reads dependencies from the project-local cache.
          postConfigure = ''
            cp -rLT ${moduleFinalAttrs.zigDeps} zig-pkg
            chmod -R u+w zig-pkg
          '';
        }
      );
    };

    # Fetch with Nix, then verify Zig content hashes without network access.
    zigDeps =
      let
        # Content-addressed entries can cover several ghostel versions.
        dependencies = importJSON ./zig-deps.json;
      in
      runCommandLocal
        "${finalAttrs.pname}-${finalAttrs.version}-zig-deps"
        {
          inherit (finalAttrs)
            src
            ;

          nativeBuildInputs = [
            finalAttrs.zig
          ];
        }
        ''
          export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
          mkdir -p "$ZIG_GLOBAL_CACHE_DIR/tmp"
          runHook unpackPhase
          cd "$sourceRoot"

          ${concatMapStringsSep "\n" (
            dependency:
            let
              archive = fetchurl {
                inherit (dependency)
                  hash
                  url
                  ;
              };
            in
            ''
              test "$(zig fetch ${archive})" = ${escapeShellArg dependency.zigHash}
            ''
          ) dependencies}

          # Check the current source's complete graph without network access.
          if ! zig build --fetch=all; then
            echo "ghostel ${finalAttrs.version}: refresh zig-deps.json for this dependency graph" >&2
            exit 1
          fi

          mv zig-pkg "$out"
        '';
  }
)
