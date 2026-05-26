{
  ebdb,
  fetchgit,
  lib,
  mu4e,
  org-vcard,
  tabspaces,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.1.0";

  src = fetchgit {
    url = "https://codeberg.org/bingshan/emacs-bs.git";
    rev = "fa123502fa8480a71f3b4cf4992dfbaa32aa4fb1";
    hash = "sha256-Y7DxYHj+Adv+uDugVbMWR1W8MKbU27eSQ5Vki+RElM8=";
  };

  meta = {
    description = "Personal GNU Emacs Lisp extensions";
    homepage = "https://codeberg.org/bingshan/emacs-bs";
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

  pname = "bs";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    ebdb
    mu4e
    org-vcard
    tabspaces
  ];
}
