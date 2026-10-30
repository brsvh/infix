{
  fetchgit,
  lib,
  melpaBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.9.0";

  src = fetchgit {
    url = "https://github.com/yibie/textui.git";
    rev = "f3bf19109a1e5304ffcadd61809e975b47350e7c";
    hash = "sha256-wykekboJStk5Nv8tpYpgzgQTT+4W9hQlOndZbI6SLR0=";
  };

  meta = {
    description = "Declarative text interfaces for Emacs";
    homepage = "https://github.com/yibie/textui";
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

  pname = "textui";

  packageRequires = [ ];
}
