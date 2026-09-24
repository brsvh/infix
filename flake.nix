{
  description = "Reusable Nix layer exposing modules, overlays, and packages";

  inputs = {
    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs)
        lib
        ;

      infix-lib = import ./lib {
        inherit
          lib
          ;
      };

      inherit (infix-lib)
        dirsToAttrs
        mapAttrsRecursive'
        mkFlake
        readDir
        stemOf
        ;

      inherit (lib)
        attrNames
        filterAttrs
        filterAttrsRecursive
        foldl'
        hasSuffix
        isAttrs
        last
        nameValuePair
        pipe
        recursiveUpdate
        toCamelCase
        ;

      projectRoot = ./.;

      testArgs = {
        inherit
          infix-lib
          lib
          projectRoot
          ;
      };

      testFiles = filterAttrs (
        name: type:
        type == "regular"
        && name != "default.nix"
        && hasSuffix ".nix" name
      ) (readDir ./test);

      tests = foldl' recursiveUpdate { } (
        map (
          name: import (./test + "/${name}") testArgs
        ) (attrNames testFiles)
      );

      infix =
        (pipe
          (dirsToAttrs [
            ./dev
            ./src
          ])
          [
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
          ]
        )
        // {
          lib = infix-lib // {
            __tests = tests;
          };
        };
    in
    mkFlake
      {
        inherit
          inputs
          ;

        specialArgs = {
          inherit
            infix
            infix-lib
            projectRoot
            ;
        };
      }
      {
        imports = [
          ./doc/flake-module.nix
          ./src
        ];

        flake = {
          inherit (infix)
            lib
            flakeModules
            ;
        };

        private = {
          directory = ./dev;

          modules = [
            ./dev
            ./test
          ];

          outputs = [
            "checks"
            "devShells"
            "formatter"
          ];
        };

        systems = [
          "x86_64-linux"
        ];
      };
}
