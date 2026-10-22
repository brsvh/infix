final: prev:
let
  inherit (prev.lib)
    composeExtensions
    versionAtLeast
    ;

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
  nextcloud33Packages =
    prev.nextcloud33Packages.overrideScope
      (
        _nextcloudFinal: nextcloudPrev: {
          apps = nextcloudPrev.apps.extend (
            _appsFinal: _appsPrev: {
              drawio = packages.nextcloud-app-drawio;
            }
          );
        }
      );

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

  # Remove once the consumer includes NixOS/nixpkgs#576853.
  php84 =
    if versionAtLeast prev.php84.version "8.4.27" then
      prev.php84
    else
      (final.callPackage
        (prev.path + /pkgs/development/interpreters/php)
        {
          # Set extension overrides before the default buildEnv captures them.
          callPackage =
            path: args:
            final.callPackage path (
              args
              // {
                # CVE-2026-109618 and CVE-2026-109619.
                version = "8.4.27";
                hash = "sha256-slMKh3xyL0sIyeF0owywi6wrfhkD7m6eMV8KqfX4LCQ=";

                packageOverrides =
                  composeExtensions
                    (args.packageOverrides or (_: _: { }))
                    (
                      _phpFinal: phpPrev: {
                        extensions = phpPrev.extensions // {
                          filter =
                            phpPrev.extensions.filter.overrideAttrs
                              (prevAttrs: {
                                # The OOM subprocess tests must load the shared extension.
                                postConfigure =
                                  (prevAttrs.postConfigure or "")
                                  + ''
                                    substituteInPlace \
                                      tests/oom_filter_input.phpt \
                                      tests/oom_filter_input_array.phpt \
                                      tests/oom_filter_default_encoded.phpt \
                                      --replace-fail "'-n'," "'-n', '-d', 'extension=$PWD/modules/filter.so',"
                                  '';
                              });
                        };
                      }
                    );
              }
            );
        }
      ).php84;
}
