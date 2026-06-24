{
  fetchgit,
  ghostel,
  lib,
  melpaBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.1.0";

  src = fetchgit {
    url = "https://codeberg.org/bingshan/emacs-ghostel-dwim";
    rev = "fc003c4165ec36aa48002f2d2483b0478d2aa591";
    hash = "sha256-O8C6SEETdxEBVJ+2cIfMzAG/VAwDQx1pGOqv6KpJgQE=";
  };

  meta = {
    description = "Context-aware session management commands for Ghostel";
    homepage = "https://codeberg.org/bingshan/emacs-ghostel-dwim";
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

  pname = "ghostel-dwim";

  preBuild = ''
    cp src/*.el .
  '';

  packageRequires = [
    ghostel
  ];
}
