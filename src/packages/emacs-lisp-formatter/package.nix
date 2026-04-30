{
  emacs-nox,
  emacsPackagesFor,
  writeShellScriptBin,
  writeText,
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

  script = writeText "emacs-lisp-formatter.el" ''
    (setq auto-save-default nil
          backup-inhibited t
          before-save-hook nil
          create-lockfiles nil
          enable-local-eval nil
          enable-local-variables :safe
          make-backup-files nil
          save-silently t
          vc-follow-symlinks t)

    (require 'cl-lib)
    (require 'editorconfig)
    (require 'editorconfig-tools nil t)

    (unless (assq 'lisp-data-mode editorconfig-indentation-alist)
      (push
       '(lisp-data-mode . editorconfig--get-indentation-lisp-mode)
       editorconfig-indentation-alist))

    (when (boundp 'editorconfig-override-dir-local-variables)
      (setq editorconfig-override-dir-local-variables nil))
    (when (boundp 'editorconfig-override-file-local-variables)
      (setq editorconfig-override-file-local-variables nil))

    (defun elisp-format--die (message-format &rest args)
      (princ
       (apply #'format
        (concat "emacs-lisp-formatter: " message-format "\n")
        args)
       'external-debugging-output)
      (kill-emacs 1))

    (defun elisp-format--report-file (file-name)
      (message "format %s" file-name))

    (defun elisp-format--check-mode (file-name)
      (unless (derived-mode-p 'emacs-lisp-mode 'lisp-data-mode)
        (elisp-format--die
         "%s is not a supported Lisp file (major mode: %S)"
         file-name
         major-mode)))

    (defun elisp-format--input-files ()
      (let ((file-args (if (member "--" argv)
                           (cdr (member "--" argv))
                         argv)))
        (unless file-args
          (elisp-format--die "expected at least one file argument"))
        file-args))

    (defun elisp-format--insert-final-newline ()
      (when (and require-final-newline
                 (> (point-max) (point-min))
                 (not find-file-literally)
                 (null buffer-read-only)
                 (/= (char-after (1- (point-max))) ?\n)
                 (not (and (eq selective-display t)
                           (= (char-after (1- (point-max))) ?\r))))
        (save-excursion
          (goto-char (point-max))
          (insert ?\n))))

    (defun elisp-format--apply-editorconfig ()
      (when buffer-file-name
        (if (fboundp 'editorconfig-apply)
            (editorconfig-apply)
          (let ((properties
                 (editorconfig-call-get-properties-function
            buffer-file-name)))
            (condition-case err
                (run-hook-with-args
                 'editorconfig-hack-properties-functions
                 properties)
              (error
               (display-warning
                '(editorconfig editorconfig-hack-properties-functions)
                (format
                 "Error while running editorconfig-hack-properties-functions, abort running hook: %S"
                 err)
                :warning)))
            (setq editorconfig-properties-hash properties)
            (editorconfig-set-local-variables properties)
            (editorconfig-set-coding-system-revert
             (gethash 'end_of_line properties)
             (gethash 'charset properties))
            (condition-case err
                (run-hook-with-args
                 'editorconfig-after-apply-functions
                 properties)
              (error
               (display-warning
                '(editorconfig editorconfig-after-apply-functions)
                (format
                 "Error while running editorconfig-after-apply-functions, abort running hook: %S"
                 err)
                :warning)))))))

    (defun elisp-format--save-buffer ()
      (elisp-format--insert-final-newline)
      (with-demoted-errors "Before-save hook error: %S"
        (run-hooks 'before-save-hook))
      (when (buffer-modified-p)
        (let ((before-save-hook nil)
              (inhibit-message t)
              (message-log-max nil))
          (basic-save-buffer))))

    (defun elisp-format--format-file (file)
      (let ((buffer nil)
            (file-name (expand-file-name file)))
        (unless (file-regular-p file-name)
          (elisp-format--die "%s is not a regular file" file-name))
        (condition-case err
            (unwind-protect
                (progn
                  (elisp-format--report-file file-name)
                  (let ((inhibit-message t)
                        (message-log-max nil))
                    (setq buffer (find-file-noselect file-name)))
                  (with-current-buffer buffer
                    (elisp-format--check-mode file-name)
                    (elisp-format--apply-editorconfig)
                    (cl-letf (((symbol-function 'make-progress-reporter)
                               (lambda (&rest _) nil))
                              ((symbol-function 'progress-reporter-update)
                               (lambda (&rest _) nil))
                              ((symbol-function 'progress-reporter-done)
                               (lambda (&rest _) nil)))
                      (indent-region (point-min) (point-max)))
                    (elisp-format--save-buffer)))
              (when (buffer-live-p buffer)
                (kill-buffer buffer)))
          (error
           (elisp-format--die
            "failed to format %s: %s"
            file-name
            (error-message-string err))))))

    (mapc #'elisp-format--format-file
          (elisp-format--input-files))
  '';
in
writeShellScriptBin "emacs-lisp-formatter" ''
  exec ${emacs}/bin/emacs --quick --script ${script} -- "$@"
''
