{
  consult,
  embark,
  embark-consult,
  fetchgit,
  lib,
  mu4e,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "1.0";

  src = fetchgit {
    url = "https://github.com/armindarvish/consult-mu.git";
    rev = "8b54bbf86c2f112e3520eeeefb70d509b4590385";
    hash = "sha256-nxutBOEO6qiPjSo7y3t1KWYb0n0AMKGl943N+uGTTjQ=";
  };

  meta = {
    description = "Consult Mu4e asynchronously in GNU Emacs";
    homepage = "https://github.com/armindarvish/consult-mu";
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

  pname = "consult-mu";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    consult
    embark
    embark-consult
    mu4e
  ];
}
