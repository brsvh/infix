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
    foldl'
    mapAttrs'
    match
    nameValuePair
    recursiveUpdate
    substring
    ;
in
rec {
  /**
    Return the directory entries for a path.

    This is a direct re-export of `builtins.readDir`.

    # Inputs

    `path`
    : Directory path to read

    # Type

    ```
    readDir :: Path -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.readDir` usage example

    ```nix
    readDir ./example
    => { "default.nix" = "regular"; nested = "directory"; }
    ```

    :::
  */
  readDir = builtins.readDir;

  /**
    Convert a directory tree to a nested attribute set.

    Directories become nested attribute sets. Other entries become paths.
    Every directory attribute set also contains a `__path` metadata field
    with the directory path it represents.

    # Inputs

    `dir`
    : Directory path to convert

    # Type

    ```
    dirToAttrs :: Path -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.dirToAttrs` usage example

    ```nix
    dirToAttrs ./example
    => {
      __path = ./example;
      "default.nix" = ./example/default.nix;
      nested = {
        __path = ./example/nested;
        "module.nix" = ./example/nested/module.nix;
      };
    }
    ```

    :::
  */
  dirToAttrs =
    dir:
    let
      entries = readDir dir;

      constructor =
        name: type:
        nameValuePair name (
          if type == "directory" then
            dirToAttrs (dir + "/${name}")
          else
            dir + "/${name}"
        );
    in
    assert assertMsg (!(entries ? "__path")) ''
      dirToAttrs: ${toString dir} contains an entry named __path, which
      would collide with the metadata field.
    '';
    (mapAttrs' constructor entries)
    // {
      __path = dir;
    };

  /**
    Convert multiple directory trees to one nested attribute set.

    Directories with the same relative path are recursively merged. Other
    entries become paths. If multiple directories contain the same non-directory
    relative path, the later directory in `dirs` wins.

    Unlike `dirToAttrs`, this function does not add `__path` metadata fields,
    because a merged directory attribute set may represent entries from more
    than one source directory.

    # Inputs

    `dirs`
    : Directory paths to convert and merge

    # Type

    ```
    dirsToAttrs :: [Path] -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.dirsToAttrs` usage example

    ```nix
    dirsToAttrs [
      ./foo
      ./bar
    ]
    => {
      a = {
        "b.nix" = ./foo/a/b.nix;
        "d.nix" = ./bar/a/d.nix;
      };
      "b.nix" = ./foo/b.nix;
      "c.nix" = ./bar/c.nix;
      "e.nix" = ./bar/e.nix;
    }
    ```

    :::
  */
  dirsToAttrs =
    dirs:
    let
      dirToMergedAttrs =
        dir:
        let
          entries = readDir dir;

          constructor =
            name: type:
            nameValuePair name (
              if type == "directory" then
                dirsToAttrs [
                  (dir + "/${name}")
                ]
              else
                dir + "/${name}"
            );
        in
        mapAttrs' constructor entries;
    in
    foldl' recursiveUpdate { } (
      map dirToMergedAttrs dirs
    );

  /**
    Whether a directory contains a child directory with the given name.

    # Inputs

    `parent`
    : Directory path to inspect

    `child`
    : Child entry name to look for

    # Type

    ```
    hasDirectory :: Path -> String -> Bool
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.hasDirectory` usage example

    ```nix
    hasDirectory ./. "lib"
    => true
    ```

    :::
  */
  hasDirectory =
    parent: child:
    let
      entries = readDir parent;
    in
    entries ? ${child}
    && entries.${child} == "directory";

  /**
    Whether a directory contains a regular file with the given name.

    # Inputs

    `parent`
    : Directory path to inspect

    `child`
    : Child entry name to look for

    # Type

    ```
    hasFile :: Path -> String -> Bool
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.hasFile` usage example

    ```nix
    hasFile ./lib "default.nix"
    => true
    ```

    :::
  */
  hasFile =
    parent: child:
    let
      entries = readDir parent;
    in
    entries ? ${child}
    && entries.${child} == "regular";

  /**
    Return the basename of a file path without its final extension.

    Dotfiles and basenames without an extension are returned unchanged.

    # Inputs

    `filename`
    : Path or string to inspect

    # Type

    ```
    stemOf :: (Path | String) -> String
    ```

    # Examples
    :::{.example}
    ## `infix-lib.filesystem.stemOf` usage example

    ```nix
    stemOf "default.nix"
    => "default"

    stemOf ".env"
    => ".env"
    ```

    :::
  */
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
