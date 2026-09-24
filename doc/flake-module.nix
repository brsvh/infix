{
  lib,
  ...
}:
let
  inherit (lib.fileset)
    fileFilter
    toSource
    ;

  source = toSource {
    root = ./.;

    fileset = fileFilter (
      file: file.hasExt "texi"
    ) ./.;
  };
in
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
        manual = pkgs.stdenvNoCC.mkDerivation {
          name = "infix-manual";
          src = source;
          strictDeps = true;

          nativeBuildInputs = [
            pkgs.texinfo
          ];

          buildPhase = ''
            runHook preBuild
            makeinfo -I . --no-split \
              -o infix.info infix.texi
            makeinfo -I . --html --no-split \
              --css-ref=https://www.gnu.org/software/emacs/manual.css \
              -o infix.html infix.texi
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm644 infix.info "$out/share/info/infix.info"
            install -Dm644 infix.html "$out/share/doc/infix/infix.html"
            runHook postInstall
          '';

          meta = {
            description = "Infix manual in Info and HTML formats";
            license = lib.licenses.fdl13Plus;
          };
        };
      };
    };
}
