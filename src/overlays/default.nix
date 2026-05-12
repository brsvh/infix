final: prev:
prev.lib.packagesFromDirectoryRecursive {
  inherit (final)
    callPackage
    ;

  inherit (prev)
    newScope
    ;

  directory = ../packages;
}
