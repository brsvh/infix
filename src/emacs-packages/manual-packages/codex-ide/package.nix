{
  applyPatches,
  fetchgit,
  lib,
  melpaBuild,
  transient,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.2";

  src = applyPatches {
    src = fetchgit {
      url = "https://github.com/dgillis/emacs-codex-ide.git";
      rev = "5eba84dd58ad8609e8f7e8c4159d4aac90b4f303";
      hash = "sha256-4Ze/gJv7ogFV0GNJOWGdCI31PluLR4himepCrhT1AVM=";
    };

    patches = [
      ./fix-transient-command-autoloads.patch
    ];
  };

  meta = {
    description = "Codex IDE integration for Emacs";
    homepage = "https://github.com/dgillis/emacs-codex-ide";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
in
melpaBuild {
  inherit
    meta
    src
    version
    ;

  pname = "codex-ide";

  files = ''(:defaults ("bin" "bin/*"))'';

  packageRequires = [
    transient
  ];
}
