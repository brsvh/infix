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
    rev = "4a40488c3ecbb77ac93f1228d362465e5bc4e769";
    hash = "sha256-6j3yia7StaPYibhZmgEJvpQhIQkoOBxfN+QfCneHl2Y=";
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
