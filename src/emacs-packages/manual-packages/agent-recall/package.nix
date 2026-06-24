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

  version = "0.5.0";

  src = fetchgit {
    url = "https://github.com/Marx-A00/agent-recall.git";
    rev = "89436ed83a7a77a424627479ff486ca97a009f4a";
    hash = "sha256-OUoCyggAfcVgHUoeM7yMdqdjdl+yDfGSll9fUE/LZxs=";
  };

  meta = {
    description = "Search and browse agent-shell conversation transcripts";
    homepage = "https://github.com/Marx-A00/agent-recall";
    license = licenses.mit;
    maintainers = with maintainers; [ brsvh ];
  };
in
melpaBuild {
  inherit
    meta
    src
    version
    ;

  pname = "agent-recall";

  packageRequires = [
    agent-shell
  ];
}
