final: prev:
let
  packages =
    prev.lib.packagesFromDirectoryRecursive
      {
        inherit (final)
          callPackage
          ;

        inherit (prev)
          newScope
          ;

        directory = ../packages;
      };
in
packages
// {
  ncps = prev.ncps.overrideAttrs (prevAttrs: {
    # SQLite LRU must make progress even when the oldest NAR is larger
    # than the excess capacity. Keep the upstream selection otherwise.
    patches = (prevAttrs.patches or [ ]) ++ [
      ../packages/ncps/lru-capacity.patch
    ];
  });

  nextcloud33Packages =
    prev.nextcloud33Packages.overrideScope
      (
        _nextcloudFinal: nextcloudPrev: {
          apps = nextcloudPrev.apps.extend (
            _appsFinal: _appsPrev: {
              drawio = packages.nextcloud-app-drawio;
            }
          );
        }
      );
}
