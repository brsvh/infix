{
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

  src = fetchgit {
    url = "https://github.com/dgillis/emacs-codex-ide.git";
    rev = "1418bd7b5f4e44706f4ab622b9b9e76f475ed4ae";
    hash = "sha256-Mve+Jy6jdojRK+c5v7rqr9PIkP1RT7/TkLG3foRdae8=";
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

  packageRequires = [
    transient
  ];
}
