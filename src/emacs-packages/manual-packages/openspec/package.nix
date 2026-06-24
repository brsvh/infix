{
  fetchgit,
  lib,
  transient,
  melpaBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "1.0.0";

  src = fetchgit {
    url = "https://github.com/Zacalot/openspec.el";
    rev = "40c67b7be4077677e8fabfcf21ef3059858d5e2f";
    hash = "sha256-W88trH4cnmepu8WeYEW2jJNDMtlg43UbeeBI7Aw8DIg=";
  };

  meta = {
    description = "Interface for OpenSpec";
    homepage = "https://github.com/Zacalot/openspec.el";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ brsvh ];
  };
in
melpaBuild {
  inherit
    meta
    src
    version
    ;

  pname = "openspec";

  packageRequires = [
    transient
  ];
}
