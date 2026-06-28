{
  fetchgit,
  lib,
  melpaBuild,
  transient,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.2";

  src = fetchgit {
    url = "https://github.com/dgillis/emacs-codex-ide.git";
    rev = "eeb1dba3b8249b254b97caf7c0f1df100419e9f1";
    hash = "sha256-dzOT82/9c2Wm9qJrNv3POYoqoC9Pi2VgWTHzA9Tn/YI=";
  };

  meta = {
    description = "Codex IDE integration for Emacs";
    homepage = "https://github.com/dgillis/emacs-codex-ide";
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

  pname = "codex-ide";

  files = ''(:defaults ("bin" "bin/*"))'';

  packageRequires = [
    transient
  ];
}
