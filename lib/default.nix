{
  lib,
  ...
}:
let
  inherit (lib)
    makeExtensible
    ;
in
makeExtensible (
  final:
  let
    import' =
      file:
      import file {
        inherit
          lib
          ;

        infix-lib = final;
      };
  in
  {
    inherit (final.attrsets)
      mapAttrsRecursive'
      mapAttrsRecursiveCond'
      ;

    inherit (final.filesystem)
      dirToAttrs
      dirsToAttrs
      hasDirectory
      hasFile
      readDir
      stemOf
      ;

    inherit (final.flake)
      evalFlakeModule
      mkFlake
      ;

    attrsets = import' ./attrsets.nix;
    filesystem = import' ./filesystem.nix;
    flake = import' ./flake.nix;
  }
)
