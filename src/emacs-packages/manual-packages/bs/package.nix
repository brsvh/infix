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
    rev = "970566fd96b65c2523810699c786523933e6f0ae";
    hash = "sha256-7BP3uToM+l1w3vFCamhplpX02L11PIiT8MEUvTVWdVw=";
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
