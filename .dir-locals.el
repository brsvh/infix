;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((nil
  .
  ((sentence-end-double-space . t)

   ;; Treat project-specific terminology as first-class vocabulary so
   ;; spell checking focuses on genuine mistakes rather than
   ;; repeatedly flagging domain terms.
   (jinx-dir-local-words . "
NixOS attrsets autoloads config configFile dev devShell devShells
devshell devshells dirToAttrs direnv disko diskoConfigurations
diskoFile emacs enableDisko enableFacter enableHomeManager env facter
facterReportFile filesystem github gitignore infix json lefthook lf
linux macrostep melpa microsoft mkdir mktemp nixago nixfmt nixos
nixosConfigurations nixosModules nixpkgs numtide pipefail preInstall
preUnpack postInstall postUnpack rebase rtf runHook shellHook src
tempdir toml treefmt truetype ttc ttf untracked usr utf utils wim
xargs yaml yml")))

 (nix-mode
  .
  ;; Enforce a narrow, consistent formatting style for Nix code in
  ;; this project, keeping expressions compact and visually uniform.
  ((apheleia-formatters . ((nixfmt "nixfmt" "--width" "50")))))

 (nix-ts-mode
  .
  ;; Apply the same formatting constraints to Tree-sitter-based Nix
  ;; buffers, ensuring consistency regardless of the active major
  ;; mode.
  ((apheleia-formatters . ((nixfmt "nixfmt" "--width" "50"))))))
