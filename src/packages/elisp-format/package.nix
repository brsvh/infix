{
  emacs-nox,
  emacsPackagesFor,
  writeShellScriptBin,
  ...
}:
let
  emacs =
    (emacsPackagesFor emacs-nox).withPackages
      (
        ps: with ps; [
          editorconfig
        ]
      );
in
writeShellScriptBin "elisp-format" ''
  exec ${emacs}/bin/emacs \
    --quick \
    --script ${./elisp-format.el} \
    -- \
    "$@"
''
