{
  compat,
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

  version = "0.5.2";

  src = fetchgit {
    url = "https://github.com/jdtsmith/org-modern-indent.git";
    rev = "ebf9a8e571db523dc6e4cd9ed80d0e0626983ae4";
    hash = "sha256-+q7KmbU8A+uR61BSa528vYbdFSj2WGsFWYW/5q7J9Kw=";
  };

  meta = {
    description = "modern block styling with org-indent";
    homepage = "https://github.com/jdtsmith/org-modern-indent";
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

  pname = "org-modern-indent";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    compat
  ];
}
