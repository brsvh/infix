final: prev: {
  emacsPackagesFor =
    emacs:
    let
      inherit (prev)
        emacsPackagesFor
        fetchgit
        fetchurl
        runCommandLocal
        ;

      inherit (prev.lib)
        concatMapStringsSep
        escapeShellArg
        importJSON
        ;

      manual-packages = ../emacs-packages/manual-packages;

      melpa-packages = ../emacs-packages/melpa-packages;

      scope =
        f: p:
        p.override {
          manualPackages =
            p.manualPackages
            // prev.lib.packagesFromDirectoryRecursive {
              inherit (f)
                callPackage
                ;

              directory = manual-packages;
            }
            // {
              ghostel = p.manualPackages.ghostel.overrideAttrs (
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
                      # Keep these archives in sync with ghostel's Zig dependency graph.
                      dependencies = importJSON (
                        manual-packages + /ghostel/zig-deps.json
                      );
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

                        mv zig-pkg "$out"
                      '';
                }
              );
            };

          melpaPackages = p.melpaPackages // {
            # Upstream Package-Requires omits denote-sequence.
            denote-explore =
              p.melpaPackages.denote-explore.overrideAttrs
                (
                  finalAttrs: prevAttrs: {
                    packageRequires =
                      (prevAttrs.packageRequires or [ ])
                      ++ [
                        p.denote-sequence
                      ];

                    propagatedBuildInputs =
                      (prevAttrs.propagatedBuildInputs or [ ])
                      ++ [
                        p.denote-sequence
                      ];
                  }
                );

            sly-macrostep =
              p.melpaPackages.sly-macrostep.overrideAttrs
                (
                  finalAttrs: prevAttrs: {
                    patches = prevAttrs.patches or [ ] ++ [
                      (
                        melpa-packages
                        + /sly-macrostep/0001-Make-autoloads-cache-use-lexical-binding.patch
                      )
                    ];
                  }
                );

            sly-named-readtables =
              p.melpaPackages.sly-named-readtables.overrideAttrs
                (
                  finalAttrs: prevAttrs: {
                    patches = prevAttrs.patches or [ ] ++ [
                      (
                        melpa-packages
                        + /sly-named-readtables/0001-Make-autoloads-cache-use-lexical-binding.patch
                      )
                    ];
                  }
                );

            switch-window =
              p.melpaPackages.switch-window.overrideAttrs
                (
                  finalAttrs: prevAttrs: {
                    src = fetchgit {
                      url = "https://github.com/brsvh/switch-window.git";
                      rev = "869f2a668c6a0f7d5b23b0d52fa8f6be20f41cb1";
                      hash = "sha256-ZWp3+aPFh1h7ib0+InmPbsZBYwpAyFlIuAltM7No13M=";
                    };
                  }
                );
          };
        };
    in
    (emacsPackagesFor emacs).overrideScope scope;
}
