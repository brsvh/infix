{
  agent-shell,
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
    url = "https://github.com/cmacrae/agent-shell-sidebar.git";
    rev = "10fee0b1463cdf210b0908c23e940a44c8d4a8e2";
    hash = "sha256-Yp+iDtOdDTtcsLn/VxRx6Mh4VOYGAZUXL7XcLHFkACk=";
  };

  meta = {
    description = "Sidebar interface for agent-shell";
    homepage = "https://github.com/cmacrae/agent-shell-sidebar";
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

  pname = "agent-shell-sidebar";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    agent-shell
  ];
}
