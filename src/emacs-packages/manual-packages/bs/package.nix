{
  ebdb,
  fetchgit,
  lib,
  mu4e,
  org-vcard,
  tabspaces,
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
    url = "https://codeberg.org/bingshan/emacs-bs.git";
    rev = "970566fd96b65c2523810699c786523933e6f0ae";
    hash = "sha256-7BP3uToM+l1w3vFCamhplpX02L11PIiT8MEUvTVWdVw=";
  };

  meta = {
    description = "Personal GNU Emacs Lisp extensions";
    homepage = "https://codeberg.org/bingshan/emacs-bs";
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

  pname = "bs";

  postPatch = ''
    cat > bs.el <<'EOF'
    ;;; bs.el --- Personal GNU Emacs Lisp extensions -*- lexical-binding: t; -*-

    ;; Package-Requires: ((emacs "30.1") (ebdb "0.8.22") (mu4e "1.12.13") (org-vcard "0.3.1") (tabspaces "1.7"))
    ;; Version: ${version}

    ;;; Commentary:
    ;; Personal GNU Emacs Lisp extensions.

    ;;; Code:

    (provide 'bs)

    ;;; bs.el ends here
    EOF
  '';

  packageRequires = [
    ebdb
    mu4e
    org-vcard
    tabspaces
  ];
}
