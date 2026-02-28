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
    concatStringsSep
    filter
    init
    isString
    length
    mapAttrs'
    nameValuePair
    split
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

      list = filter isString (split "\\." basename);
    in
    if length list > 1 then
      concatStringsSep "." (init list)
    else
      basename;
}
