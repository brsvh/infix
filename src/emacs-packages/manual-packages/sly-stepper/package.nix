{
  fetchgit,
  lib,
  melpaBuild,
  sly,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.1";

  src = fetchgit {
    url = "https://github.com/joaotavora/sly-stepper.git";
    rev = "da84e3bba8466c2290c2dc7c27d7f4c48c27b39e";
    hash = "sha256-gMbmG42gxaQrgDUVySbGGpayxDM3pKAgDvYpd9KZ4B4=";
  };

  meta = {
    description = "A portable Common Lisp stepper interface";
    homepage = "https://github.com/joaotavora/sly-stepper";
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

  pname = "sly-stepper";

  packageRequires = [
    sly
  ];

  preBuild =
    let
      slyPath = "${sly}/share/emacs/site-lisp/elpa/${sly.pname}-${sly.version}";
    in
    ''
      export EMACSLOADPATH="$EMACSLOADPATH:${slyPath}:${slyPath}/lib:${slyPath}/contrib"
    '';
}
