{
  agent-shell,
  fetchgit,
  knockknock,
  lib,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.0.1";

  src = fetchgit {
    url = "https://github.com/xenodium/agent-shell-knockknock.git";
    rev = "56732434067fe1874dcda62c491f7800bdc0a2f3";
    hash = "sha256-R7bvk2v9togbPiGKOXDAKCMStrL1bbRJoTdBtj0PdlU=";
  };

  meta = {
    description = "Knockknock notifications for agent-shell";
    homepage = "https://github.com/xenodium/agent-shell-knockknock";
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

  pname = "agent-shell-knockknock";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    agent-shell
    knockknock
  ];
}
