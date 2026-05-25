{
  consult,
  ebdb,
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
    url = "https://codeberg.org/bingshan/emacs-consult-contacts.git";
    rev = "bf5677b97b5d1d0a6da0fbe0aeaa5f7a36e8252c";
    hash = "sha256-98EjtEN1JFGb9DB1ejKDyb8orJ4+yw04g6xj7yIIpeE=";
  };

  meta = {
    description = "Consult UI for EBDB contacts";
    homepage = "https://codeberg.org/bingshan/emacs-consult-contacts";
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

  pname = "consult-contacts";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    consult
    ebdb
  ];
}
