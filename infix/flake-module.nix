{
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrsRecursive
    hasSuffix
    isAttrs
    last
    nameValuePair
    pipe
    toCamelCase
    ;

  infix-lib = import ./lib {
    inherit
      lib
      ;
  };

  inherit (infix-lib)
    dirToAttrs
    mapAttrsRecursive'
    stemOf
    ;

  infix = pipe (dirToAttrs ./.) [
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
{
  flake = {
    inherit (infix)
      flakeModules
      ;

    lib = infix-lib;
  };

  systems = [ ];
}
