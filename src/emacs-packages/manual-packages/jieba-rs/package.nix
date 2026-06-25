{
  fetchgit,
  lib,
  melpaBuild,
  rustPlatform,
  stdenv,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  sharedLibraryExt =
    stdenv.hostPlatform.extensions.sharedLibrary;

  version = "0.1.0";

  src = fetchgit {
    url = "https://github.com/brsvh/emacs-jieba-rs";
    rev = "8fc69235cde11f097f98c1750741a51472b5a1aa";
    hash = "sha256-tvL4AfngU/FMdZ9TtgzOLq5w/mUWjX2X6u4eLnIZ5fc=";
  };

  module = rustPlatform.buildRustPackage {
    inherit
      src
      version
      ;

    pname = "emacs-jieba-rs-module";

    cargoBuildFlags = [
      "--lib"
    ];

    cargoHash = "sha256-R8Ow+SX+eCTT9cpqrpaUsI5GMQN7e/KW2EzY3rNqKEA=";
  };

  meta = {
    description = "Jieba Chinese word segmentation for GNU Emacs";
    homepage = "https://github.com/brsvh/emacs-jieba-rs";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
in
melpaBuild {
  inherit
    meta
    version
    ;

  pname = "jieba-rs";
  src = "${src}/lisp";

  preBuild = ''
    install -m 755 ${module}/lib/libjieba_rs_module${sharedLibraryExt} jieba-rs-module${sharedLibraryExt}
  '';

  files = ''(:defaults "jieba-rs-module${sharedLibraryExt}")'';

  packageRequires = [ ];

  passthru = {
    inherit
      module
      ;
  };
}
