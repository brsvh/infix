final: prev:
let
  packages =
    prev.lib.packagesFromDirectoryRecursive
      {
        inherit (final)
          callPackage
          ;

        inherit (prev)
          newScope
          ;

        directory = ../packages;
      };
in
packages
// {
  onlyoffice-documentserver =
    let
      inherit (prev.lib)
        baseNameOf
        optionalAttrs
        ;

      fetchCore =
        args:
        let
          src = final.fetchFromGitHub args;
        in
        if
          args.owner == "ONLYOFFICE" && args.repo == "core"
        then
          final.applyPatches {
            # Upstream creates relative links to the directory named source.
            inherit (src)
              name
              ;

            inherit
              src
              ;

            patches = [
              ../packages/onlyoffice-documentserver/shared-cxx-runtime.patch
            ];
          }
        else
          src;
    in
    prev.onlyoffice-documentserver.override {
      # The upstream package binds x2t and its components internally.
      callPackage =
        path: args:
        final.callPackage path (
          args
          // optionalAttrs (baseNameOf path == "x2t.nix") {
            fetchFromGitHub = fetchCore;
          }
        );

      # Apply this before upstream captures the package in its FHS environment.
      stdenv = prev.stdenv // {
        mkDerivation =
          args:
          (prev.stdenv.mkDerivation args).overrideAttrs (
            finalAttrs: prevAttrs: {
              # The upstream install phase does not run postInstall.
              installPhase = prevAttrs.installPhase + ''
                config="$out/etc/onlyoffice/documentserver/production-linux.json"
                ${final.jq}/bin/jq \
                  --arg fontDir \
                  "${finalAttrs.passthru.x2t-with-fonts-and-themes}/converter" \
                  '.FileConverter.converter.fontDir = $fontDir' \
                  "$config" > "$config.tmp"
                mv "$config.tmp" "$config"
              '';
            }
          );
      };
    };
}
