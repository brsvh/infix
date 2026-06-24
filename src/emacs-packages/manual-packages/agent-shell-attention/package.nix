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

  version = "0.0.2";

  src = fetchgit {
    url = "https://github.com/ultronozm/agent-shell-attention.el.git";
    rev = "18e580806775b41a9c899e79c6765f4d937913e7";
    hash = "sha256-Y/jb9e0YxyEwQ0LFYwAu/PMqBnZXlOf5JiQJNISz4+0=";
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
