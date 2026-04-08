{
  fetchgit,
  lib,
  posframe,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "1.0.0";

  src = fetchgit {
    url = "https://github.com/brsvh/flymake-posframe.git";
    rev = "0f68e9b0f74a768eafc135df383732a255a5193e";
    hash = "sha256-kQtYy1+NO5+IE73DOvXGxTfga6Cl0hMwxqytmTC7U60=";
  };

  meta = {
    description = "Display flymake message at point using a posframe";
    homepage = "https://github.com/Ladicle/flymake-posframe";
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
    posframe
  ];
}
