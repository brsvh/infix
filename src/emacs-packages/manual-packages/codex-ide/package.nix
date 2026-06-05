{
  fetchgit,
  lib,
  transient,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.1";

  src = fetchgit {
    url = "https://github.com/dgillis/emacs-codex-ide.git";
    rev = "7b36dfc1bf563111ac1d25c23f80db57b5dafba2";
    hash = "sha256-aiJfnyYo/XA75cGYeXK5Bmml1Ta10+SKjZfe55lWWWQ=";
  };

  meta = {
    description = "Codex IDE integration for Emacs";
    homepage = "https://github.com/dgillis/emacs-codex-ide";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
in
trivialBuild rec {
  inherit
    meta
    src
    version
    ;

  pname = "codex-ide";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    transient
  ];
}
