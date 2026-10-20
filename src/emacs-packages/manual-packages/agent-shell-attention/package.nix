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

  version = "0.0.3";

  src = fetchgit {
    url = "https://github.com/ultronozm/agent-shell-attention.el.git";
    rev = "aaf599121445ead597a14da62bad580c8897ee6c";
    hash = "sha256-sXHjZ8791aBstTDODJU/2G//7ulEGyyFQwAQp7cNYiw=";
  };

  meta = {
    description = "Mode-line attention tracker for agent-shell";
    homepage = "https://github.com/ultronozm/agent-shell-attention.el";
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

  pname = "agent-shell-attention";

  packageRequires = [
    agent-shell
  ];
}
