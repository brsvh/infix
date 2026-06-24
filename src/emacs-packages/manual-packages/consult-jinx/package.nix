{
  consult,
  fetchgit,
  jinx,
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
    url = "https://codeberg.org/bingshan/emacs-consult-jinx.git";
    rev = "ffc59feceeb5fff14b6c84d3d24078f8333a0096";
    hash = "sha256-aDbL3CYLG3sGJzL7x+M5iDeFa6D1ByjMR9XViybsR7Q=";
  };

  meta = {
    description = "Consult interface for Jinx";
    homepage = "https://codeberg.org/bingshan/emacs-consult-jinx";
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

  pname = "consult-jinx";

  packageRequires = [
    consult
    jinx
  ];
}
