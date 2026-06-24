{
  acp,
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

  version = "0.2.0";

  src = fetchgit {
    url = "https://github.com/junyi-hou/agent-shell-tramp.git";
    rev = "ebdeb204973beb116017a977bee52cdced78e447";
    hash = "sha256-G1Q+hvwZ3iBax0f3/7tM1/7geYayEH6QzkQcz32+J0w=";
  };

  meta = {
    description = "TRAMP support for agent-shell";
    homepage = "https://github.com/junyi-hou/agent-shell-tramp";
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

  pname = "agent-shell-tramp";

  packageRequires = [
    acp
    agent-shell
  ];
}
