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

  version = "unstable-2026-02-13";

  src = fetchgit {
    url = "https://github.com/jethrokuan/agent-shell-manager.git";
    rev = "53b73f13ed1ac9d2de128465a8504a7265490ea7";
    hash = "sha256-JPB/OnOhYbM0LMirSYQhpB6hW8SAg0Ri6buU8tMP7rA=";
  };

  meta = {
    description = "Buffer manager for agent-shell";
    homepage = "https://github.com/jethrokuan/agent-shell-manager";
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

  pname = "agent-shell-manager";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    agent-shell
  ];
}
