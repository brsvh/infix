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
    rev = "9c6e456afa269ff9934b29621c189bffd8ad9ef4";
    hash = "sha256-/4ntEpJylSlapIpsuttmRygajh64tfRFxpwkcn2wWnU=";
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
