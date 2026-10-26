{
  callPackage,
  path,
  ...
}:
(callPackage (
  path + /pkgs/by-name/nc/ncps/package.nix
) { }).overrideAttrs
  (
    _: prevAttrs: {
      patches = (prevAttrs.patches or [ ]) ++ [
        # SQLite ignores foreign_keys=OFF inside Goose transactions.
        ./sqlite-metadata-migrations.patch
      ];
    }
  )
