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
    rev = "75740f175c1f8df01e489d71169e46fd2b3fb8f0";
    hash = "sha256-BJbKNKqLTAGZq3O/Ovq9wFBgueYgX5q7tvbiZdwb4zU=";
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
