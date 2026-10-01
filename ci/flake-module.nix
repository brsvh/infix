{
  inputs,
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
    mapAttrs'
    nameValuePair
    optionalAttrs
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

  hci-effects = inputs.hercules-ci-effects.lib.withPkgs base;

  overlay = self.overlays.default;
  pkgs = base.extend overlay;

  packages = filterAttrs (_: isDerivation) (
    overlay pkgs base
  );

  packageOutputs = mapAttrs (
    _: package:
    genAttrs package.outputs (
      output: package.${output}
    )
  ) packages;

in
{
  flake = {
    herculesCI =
      {
        branch ? null,
        ...
      }:
      {
        ciSystems = [
          system
        ];

        # Branch filtering here is scheduling, not an untrusted-code boundary.
        onPush = optionalAttrs (branch == "main") (
          {
            default = {
              outputs = {
                checks = self.checks.${system};
              };
            };
          }
          // mapAttrs' (
            name: outputs:
            nameValuePair "buildPackage/${name}" {
              outputs = {
                packages = outputs;
              };
            }
          ) packageOutputs
          // mapAttrs' (
            name: outputs:
            nameValuePair "publishPackage/${name}" {
              outputs = {
                effects = {
                  publish = import ./publish.nix {
                    inherit
                      hci-effects
                      name
                      outputs
                      ;

                    pkgs = base;
                  };
                };
              };
            }
          ) packageOutputs
        );
      };
  };
}
