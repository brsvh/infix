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
    rev = "43691b27308ec7a7456d5f9ce1154431b2e00fea";
    hash = "sha256-BRZXpSu1utcsSLfMnZFlpOrV+KFGvrp2wMqkTJXSmqc=";
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
