{
  description = "Reusable Nix layer exposing modules, overlays, and packages";

  inputs = {
    flake-parts = {
      inputs = {
        nixpkgs-lib = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=main";
    };

    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable";
    };
  };

  nixConfig = {
    experimental-features = [
      "ca-derivations"
      "flakes"
    ];
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      ...
    }:
    let
      inherit (flake-parts.lib)
        mkFlake
        ;

      infix-lib = import ./lib {
        inherit (nixpkgs)
          lib
          ;
      };

      inherit (infix-lib)
        dirToAttrs
        mapAttrsRecursive'
        stemOf
        ;

      inherit (nixpkgs.lib)
        filterAttrs
        filterAttrsRecursive
        hasSuffix
        isAttrs
        last
        nameValuePair
        packagesFromDirectoryRecursive
        pipe
        toCamelCase
        ;

      dev = pipe (dirToAttrs ./src/dev) [
        (filterAttrsRecursive (
          name: value:
          if (isAttrs value) || (name == "__path") then
            true
          else
            hasSuffix ".nix" (toString value)
        ))
        (mapAttrsRecursive' (
          path: value:
          let
            basename = last path;
          in
          nameValuePair (
            if basename == "__path" then
              "__path"
            else
              (toCamelCase (stemOf basename))
          ) value
        ))
      ];

      infix = pipe (dirToAttrs ./src) [
        (filterAttrs (name: _: name != "dev"))
        (filterAttrsRecursive (
          name: value:
          if isAttrs value then
            true
          else
            hasSuffix ".nix" (toString value)
        ))
        (mapAttrsRecursive' (
          path: value:
          nameValuePair (toCamelCase (stemOf (last path))) value
        ))
      ];
    in
    mkFlake
      {
        inherit
          inputs
          ;
      }
      {
        imports = [
          flake-parts.flakeModules.partitions
        ];

        flake = {
          inherit (infix)
            flakeModules
            ;

          lib = infix-lib;

          overlays = {
            default =
              final: prev:
              packagesFromDirectoryRecursive {
                inherit (final)
                  callPackage
                  ;

                inherit (prev)
                  newScope
                  ;

                directory = ./src/packages;
              };

            emacs-packages = final: prev: {
              emacsPackagesFor =
                emacs:
                let
                  inherit (prev)
                    emacsPackagesFor
                    fetchgit
                    ;

                  manual-packages = ./src/emacs-packages/manual-packages;

                  melpa-packages = ./src/emacs-packages/melpa-packages;

                  scope =
                    f: p:
                    p.override {
                      manualPackages =
                        p.manualPackages
                        // packagesFromDirectoryRecursive {
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
            };
          };
        };

        partitionedAttrs = {
          devShells = "dev";
          formatter = "dev";
        };

        partitions = {
          dev = {
            extraInputsFlake = dev.__path;

            module = {
              imports = [
                dev.flakeModule
              ];
            };
          };
        };

        systems = [ ];
      };
}
