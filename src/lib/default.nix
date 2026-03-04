{
  lib,
  ...
}:
let
  inherit (lib)
    makeExtensible
    ;

  infix-lib = makeExtensible (
    final:
    let
      call =
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
        hasDirectory
        hasFile
        readDir
        stemOf
        ;

      attrsets = call ./attrsets.nix;
      filesystem = call ./filesystem.nix;
    }
  );
in
infix-lib
