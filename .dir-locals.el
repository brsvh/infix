;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((nil
  .
  ((sentence-end-double-space . t)))

 (lisp-data-mode
  .
  ((eval
    .
    (progn
      (setq-local apheleia-formatter 'lisp-indent)))))

 (nix-mode
  .
  ((apheleia-formatters . ((nixfmt "nixfmt" "--width" "50")))))

 (nix-ts-mode
  .
  ((apheleia-formatters . ((nixfmt "nixfmt" "--width" "50"))))))
