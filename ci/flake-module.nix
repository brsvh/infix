{
  inputs,
  lib,
  packageNixpkgs,
  self,
  ...
}:
let
  inherit (lib)
    elemAt
    filterAttrs
    genAttrs
    hasAttr
    isDerivation
    mapAttrs
    match
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

  cache = {
    publicKey = "cache.bingshan.org-1:HqcG/vJ7jeSLU48jV4yg8Ot+rUPP2v0vIAAnDEqVSvk=";
    url = "https://cache.bingshan.org";
  };

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

  # The planner needs identities, not build dependencies on every package.
  packageMetadata = mapAttrs (_: package: {
    drvPath = builtins.unsafeDiscardStringContext package.drvPath;

    outputs = map (
      output:
      builtins.unsafeDiscardStringContext (
        toString package.${output}
      )
    ) package.outputs;
  }) packages;
in
{
  flake = {
    herculesCI =
      {
        branch ? null,
        primaryRepo ? { },
        ref ? null,
        rev ? null,
        tag ? null,
        ...
      }:
      let
        trustedRepository =
          (primaryRepo.owner or null) == "brsvh"
          && (primaryRepo.name or null) == "infix";

        request =
          if tag == null then
            null
          else
            match "ci/package/([a-z0-9-]+)/([0-9a-f]{40})/([0-9a-f-]{36})" tag;

        name = elemAt request 0;
      in
      {
        ciSystems = [
          system
        ];

        # Ref filtering schedules trusted contributions; it is not a sandbox.
        onPush = optionalAttrs trustedRepository (
          if
            request != null
            && ref == "refs/tags/${tag}"
            && elemAt request 1 == rev
            && hasAttr name packages
          then
            {
              "buildPackage/${name}" = {
                outputs = {
                  packages = packageOutputs.${name};
                };
              };

              "publishPackage/${name}" = {
                outputs = {
                  effects = {
                    publish = import ./publish.nix {
                      inherit
                        cache
                        hci-effects
                        name
                        rev
                        tag
                        ;

                      drvPath = packageMetadata.${name}.drvPath;
                      outputs = packageOutputs.${name};
                      pkgs = base;
                    };
                  };
                };
              };
            }
          else
            optionalAttrs
              (
                branch == "main"
                && ref == "refs/heads/main"
                && tag == null
              )
              {
                default = {
                  outputs = {
                    checks = self.checks.${system};
                  };
                };

                plan = {
                  outputs = {
                    effects = {
                      plan = import ./plan.nix {
                        inherit
                          cache
                          hci-effects
                          rev
                          ;

                        packages = packageMetadata;
                        pkgs = base;
                      };
                    };
                  };
                };
              }
        );
      };
  };
}
