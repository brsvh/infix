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

      infix-lib = import ./infix/lib {
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
        filterAttrsRecursive
        hasSuffix
        isAttrs
        last
        nameValuePair
        pipe
        toCamelCase
        ;

      parts = pipe (dirToAttrs ./.) [
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

        partitionedAttrs = {
          flakeModules = "infix";
          lib = "infix";
        };

        partitions = {
          infix = {
            extraInputsFlake = parts.infix.__path;

            module = {
              imports = [
                parts.infix.flakeModule
              ];
            };
          };
        };

        systems = [ ];
      };
}
