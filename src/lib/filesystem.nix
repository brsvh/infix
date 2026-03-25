{
  lib,
  ...
}:
let
  inherit (builtins)
    baseNameOf
    toString
    ;

  inherit (lib)
    assertMsg
    elemAt
    mapAttrs'
    match
    nameValuePair
    substring
    ;
in
rec {
  inherit (builtins)
    readDir
    ;

  dirToAttrs =
    dir:
    let
      entries = readDir dir;

      _ = assertMsg (!(entries ? "__path")) ''
        dirToAttrs: ${toString dir} contains an entry named __path, which would
        collide with the metadata field.
      '';

      constructor =
        name: type:
        nameValuePair name (
          if type == "directory" then
            dirToAttrs (dir + "/${name}")
          else
            dir + "/${name}"
        );
    in
    (mapAttrs' constructor entries)
    // {
      __path = dir;
    };

  hasDirectory =
    parent: child:
    let
      entries = readDir parent;
    in
    entries ? ${child}
    && entries.${child} == "directory";

  hasFile =
    parent: child:
    let
      entries = readDir parent;
    in
    entries ? ${child}
    && entries.${child} == "regular";

  stemOf =
    filename:
    let
      basename = baseNameOf filename;

      m = match "^(.+)\\.([^.]+)$" basename;
    in
    if m == null || substring 0 1 basename == "." then
      basename
    else
      elemAt m 0;
}
