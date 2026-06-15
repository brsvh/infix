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
    rev = "5ada64bb796ba983bee26af0c545b2fae801808d";
    hash = "sha256-/ixhL4gCkM3Aqv/mW2TS2yg7OIXaRui7RuiRbwLaR/g=";
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
