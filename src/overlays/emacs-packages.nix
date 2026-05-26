final: prev: {
  emacsPackagesFor =
    emacs:
    let
      inherit (prev)
        emacsPackagesFor
        fetchgit
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
                      rev = "3924c3f05084ce36a6434f1c08de411d6817988e";
                      hash = "sha256-upXOFJr+SpS21LZNwYjaE0U3TXsNT+YU/tjP5vSJqbA=";
                    };
                  }
                );
          };
        };
    in
    (emacsPackagesFor emacs).overrideScope scope;
}
