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
    rev = "14560d42440c17d9b59fc18d304687641ddf06e5";
    hash = "sha256-J4TBVkhlaso+TQvFLBwnWqGu5q2eCW8978mYuD1BbqM=";
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
