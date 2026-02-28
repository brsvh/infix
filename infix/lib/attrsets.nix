{
  lib,
  ...
}:
let
  inherit (lib)
    isAttrs
    mapAttrs'
    nameValuePair
    ;
in
rec {
  mapAttrsRecursive' =
    f: mapAttrsRecursiveCond' (_: true) f;

  mapAttrsRecursiveCond' =
    cond: f: attrs:
    let
      recurse =
        path:
        mapAttrs' (
          name: value:
          let
            pair = f (path ++ [ name ]) value;

            name' = pair.name;

            value' = pair.value;
          in
          if isAttrs value' && cond value' then
            nameValuePair name' (
              recurse (path ++ [ name' ]) value'
            )
          else
            nameValuePair name' value'
        );
    in
    recurse [ ] attrs;
}
