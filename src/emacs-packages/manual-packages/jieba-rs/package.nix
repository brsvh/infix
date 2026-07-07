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
    rev = "63ae6a7a25f7060ac7c31fa7b184e90d4f460517";
    hash = "sha256-S9lCAJXuySslnPROCGTQSQmGiLihZFysouC9h57zIQg=";
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

    cargoHash = "sha256-s+xDbsO6G5rDv21NvHS7yMWMcxsX7/NZivepXTQcKRg=";
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
