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
            sly-macrostep =
              p.melpaPackages.sly-macrostep.overrideAttrs
                (
                  finalAttrs: prevAttrs: {
                    version = "20191211.1630";

                    src = fetchgit {
                      url = "https://github.com/joaotavora/sly-macrostep.git";
                      rev = "5113e4e926cd752b1d0bcc1508b3ebad5def5fad";
                      hash = "sha256-GVDlwWUIT/IiTPqDQ3w54Tsz6NNl2bMtB3Y4Yh8Srts=";
                    };

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
