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

      infix-lib = import ./src/lib {
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
