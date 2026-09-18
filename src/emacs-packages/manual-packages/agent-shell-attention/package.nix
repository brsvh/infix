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
    rev = "ae2df16c1d481d0e182cc85fafa62c53431aab36";
    hash = "sha256-eukR9iviR5bpAfwB7Sq130TGMNR8OI+QtJSSXXnUiqc=";
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
