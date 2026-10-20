{
  agent-shell,
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

  version = "0-unstable-2026-10-02";

  src = fetchgit {
    url = "https://github.com/jethrokuan/agent-shell-manager.git";
    rev = "d3ee783751f0870e36d715c43381a80b1114ac72";
    hash = "sha256-D6/aHnRK4uKtmR3vcQk7s3s2XZ+/UlZiDyWOtPUZKno=";
  };

  meta = {
    description = "Buffer manager for agent-shell";
    homepage = "https://github.com/jethrokuan/agent-shell-manager";
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

  pname = "agent-shell-manager";

  packageRequires = [
    agent-shell
  ];
}
