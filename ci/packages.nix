{
  nixpkgs,
  overlay,
  system,
}:
let
  inherit (nixpkgs.lib)
    filterAttrs
    genAttrs
    isDerivation
    mapAttrs
    ;

  base = import nixpkgs {
    inherit system;

    config = {
      allowUnfree = false;
    };
  };

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
  inherit
    base
    packageOutputs
    ;

  manifest = mapAttrs (name: package: {
    inherit (package) drvPath;

    outputs = mapAttrs (
      _: toString
    ) packageOutputs.${name};
  }) packages;
}
