{
  fetchgit,
  lib,
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
    rev = "ba166e425be306ac120c554cddd2877e54e92059";
    hash = "sha256-xebavtKJy60gRZCKP4Y6t9YFGKhI7EBTJdyICz7GHnE=";
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
    tabspaces
  ];
}
