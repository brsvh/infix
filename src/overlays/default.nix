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
