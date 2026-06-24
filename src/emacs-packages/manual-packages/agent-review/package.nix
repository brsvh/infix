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

  version = "0.1.0";

  src = fetchgit {
    url = "https://github.com/nineluj/agent-review.git";
    rev = "df684c4558f0fd83bd81a58503235ab62fd37af5";
    hash = "sha256-zADIjNEknbyLskt3St4YW2skQS8aNAB9M1MVA3PiV+s=";
  };

  meta = {
    description = "AI-powered code review for git changes";
    homepage = "https://github.com/nineluj/agent-review";
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

  pname = "agent-review";

  packageRequires = [
    acp
    agent-shell
  ];
}
