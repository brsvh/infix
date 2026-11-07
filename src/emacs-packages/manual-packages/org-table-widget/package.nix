{
  fetchgit,
  lib,
  melpaBuild,
  org,
  textui,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.1";

  src = fetchgit {
    url = "https://github.com/yibie/org-table-widget.git";
    rev = "20d9dd5b8d1a8e796aa1ee807f6df3b136b0c82c";
    hash = "sha256-5edz+Hpik8jpTqcIEg2jvclsS56/BmoCdqZfx313QbA=";
  };

  meta = {
    description = "Responsive pixel-aligned Org tables";
    homepage = "https://github.com/yibie/org-table-widget";
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

  pname = "org-table-widget";

  packageRequires = [
    org
    textui
  ];
}
