{
  fetchgit,
  lib,
  nerd-icons,
  posframe,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.0";

  src = fetchgit {
    url = "https://github.com/konrad1977/knockknock.git";
    rev = "0920b9b390d4b4cc0818574e115d87eb245a41b5";
    hash = "sha256-hTkXfXMIEL4GtZV177/6uFybdmH+zxwsDnaXSXvG4hs=";
  };

  meta = {
    description = "Unobtrusive notifications with icons and SVG support";
    homepage = "https://github.com/konrad1977/knockknock";
    license = licenses.mit;
    maintainers = with maintainers; [ brsvh ];
  };
in
trivialBuild rec {
  inherit
    meta
    src
    version
    ;

  pname = "knockknock";

  buildInputs = propagatedUserEnvPkgs;

  propagatedBuildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    nerd-icons
    posframe
  ];
}
