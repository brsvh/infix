{
  eat,
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

  version = "0.1.0";

  src = fetchgit {
    url = "https://codeberg.org/bingshan/emacs-eat-dwim.git";
    rev = "030082b92bac3af199f2d8e469942d76b770a59f";
    hash = "sha256-2bmCysnUaAXnbzmQfuiZAZDn57CbPvL8aknvrpJhRD4=";
  };

  meta = {
    description = "Let Emacs-Eat Do What I Mean";
    homepage = "https://codeberg.org/bingshan/emacs-eat-dwim";
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

  pname = "eat-dwim";

  packageRequires = [
    eat
  ];
}
