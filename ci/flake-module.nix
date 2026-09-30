{
  lib,
  packageNixpkgs,
  self,
  ...
}:
let
  inherit (lib)
    filterAttrs
    genAttrs
    isDerivation
    mapAttrs
    ;

  system = "x86_64-linux";

  # Private tool inputs may use a different Nixpkgs revision.
  base = import packageNixpkgs {
    inherit
      system
      ;

    config = {
      allowUnfree = false;
    };
  };

  overlay = self.overlays.default;
  pkgs = base.extend overlay;

  packages = filterAttrs (_: isDerivation) (
    overlay pkgs base
  );
in
{
  flake = {
    herculesCI = {
      ciSystems = [
        system
      ];

      onPush = {
        default = {
          outputs = {
            checks = self.checks.${system};

            packages = mapAttrs (
              _: package:
              genAttrs package.outputs (
                output: package.${output}
              )
            ) packages;
          };
        };
      };
    };
  };
}
