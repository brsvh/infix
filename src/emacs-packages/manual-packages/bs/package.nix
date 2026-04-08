{
  fetchgit,
  lib,
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
    rev = "4dd51e7f845e79f66da8388eb749a0e691817f9e";
    hash = "sha256-woNLydnmciEyzzxl75cr+NAnt6P/yaylHnYsmR8CMTc=";
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

  propagatedUserEnvPkgs = [ ];
}
