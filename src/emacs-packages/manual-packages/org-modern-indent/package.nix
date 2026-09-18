{
  compat,
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

  version = "0.5.3";

  src = fetchgit {
    url = "https://github.com/jdtsmith/org-modern-indent.git";
    rev = "86bd83ee1ad95f123810eb3b116beb543db1960a";
    hash = "sha256-vQzYk5qejCBehpbxkMceOMsmeLyjnAstpezZw/ZR1jQ=";
  };

  meta = {
    description = "modern block styling with org-indent";
    homepage = "https://github.com/jdtsmith/org-modern-indent";
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

  pname = "org-modern-indent";

  packageRequires = [
    compat
  ];
}
