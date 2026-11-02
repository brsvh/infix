{
  inputs,
  lib,
  packageNixpkgs,
  self,
  ...
}:
let
  inherit (lib)
    mapAttrs'
    nameValuePair
    optionalAttrs
    ;

  system = "x86_64-linux";

  inherit
    (import ./packages.nix {
      inherit system;

      # Private tool inputs may use a different Nixpkgs revision.
      nixpkgs = packageNixpkgs;
      overlay = self.overlays.default;
    })
    base
    packageOutputs
    ;

  hci-effects = inputs.hercules-ci-effects.lib.withPkgs base;

  cache = {
    publicKey = "cache.bingshan.org-1:HqcG/vJ7jeSLU48jV4yg8Ot+rUPP2v0vIAAnDEqVSvk=";
    url = "https://cache.bingshan.org";
  };
in
{
  flake = {
    herculesCI =
      {
        branch ? null,
        primaryRepo ? { },
        ref ? null,
        rev ? null,
        ...
      }:
      let
        trustedMain =
          branch == "main"
          && ref == "refs/heads/main"
          && (primaryRepo.owner or null) == "brsvh"
          && (primaryRepo.name or null) == "infix";
      in
      {
        ciSystems = [
          system
        ];

        # Ref filtering schedules trusted contributions; it is not a sandbox.
        onPush = optionalAttrs trustedMain (
          {
            checkFlake = {
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
                      cache
                      hci-effects
                      name
                      outputs
                      rev
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
