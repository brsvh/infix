{
  eat,
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
    url = "https://codeberg.org/bingshan/emacs-eat-dwim.git";
    rev = "fd539aa8aee06f557e42cea048340234cca47a8a";
    hash = "sha256-9B5xLsCm4kl7P/vLkyY8NYbyo6IzwdZodk/FV1RYAVY=";
  };

  meta = {
    description = "Let Emacs-Eat Do What I Mean";
    homepage = "https://codeberg.org/bingshan/emacs-eat-dwim";
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

  pname = "eat-dwim";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    eat
  ];
}
