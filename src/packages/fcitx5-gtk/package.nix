{
  callPackage,
  path,
  withGTK2 ? false,
  ...
}:
(callPackage
  (path + /pkgs/by-name/fc/fcitx5-gtk/package.nix)
  {
    inherit
      withGTK2
      ;
  }
).overrideAttrs
  (
    _: prevAttrs: {
      patches = (prevAttrs.patches or [ ]) ++ [
        ./theme-global-section.patch
      ];
    }
  )
