#!/usr/bin/env -S emacs --quick --script
;;; elisp-format.el --- Format Emacs Lisp files

;;; Commentary:

;; Format Emacs Lisp and Lisp data files passed as command-line arguments.

;;; Code:

(require 'cl-lib)
(require 'editorconfig)
(require 'editorconfig-tools nil t)
(require 'macroexp)

(setq auto-save-default nil
      backup-inhibited t
      before-save-hook nil
      create-lockfiles nil
      enable-local-eval nil
      enable-local-variables :safe
      make-backup-files nil
      save-silently t
      vc-follow-symlinks t)

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
          (concat "elisp-format: " message-format "\n")
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

;; Visiting source does not apply its `declare' forms.  Read safe
;; indentation declarations without evaluating the source.
(defun elisp-format--definition-indent-spec (form)
  (when (and (memq (car-safe form)
                   '(cl-defmacro cl-defsubst cl-defun
                      defmacro defsubst defun))
             (symbolp (nth 1 form)))
    (let ((declarations
           (car (macroexp-parse-body (nthcdr 3 form))))
          indent-spec)
      (dolist (declaration declarations)
        (when (eq (car-safe declaration) 'declare)
          (let ((indent (assq 'indent (cdr declaration))))
            (when (and (consp (cdr indent))
                       (null (cddr indent))
                       (or (integerp (cadr indent))
                           (eq (cadr indent) 'defun)))
              (setq indent-spec (cadr indent))))))
      (when indent-spec
        (cons (nth 1 form) indent-spec)))))

(defun elisp-format--collect-indent-specs ()
  (when (derived-mode-p 'emacs-lisp-mode)
    (save-excursion
      (goto-char (point-min))
      (let ((read-circle nil)
            (read-symbol-shorthands nil)
            indent-specs)
        (condition-case nil
            (while t
              (let* ((form (read (current-buffer)))
                     (indent-spec
                      (ignore-errors
                        (elisp-format--definition-indent-spec
                         form))))
                (when indent-spec
                  (setq indent-specs
                        (cons
                         indent-spec
                         (assq-delete-all
                          (car indent-spec)
                          indent-specs))))))
          (end-of-file nil)
          (error nil))
        indent-specs))))

(defun elisp-format--install-indent-specs ()
  (let (saved-properties)
    (dolist (indent-spec (elisp-format--collect-indent-specs))
      (let ((symbol (car indent-spec)))
        (push
         (list
          symbol
          (plist-member
           (symbol-plist symbol)
           'lisp-indent-function)
          (get symbol 'lisp-indent-function))
         saved-properties)
        (put
         symbol
         'lisp-indent-function
         (cdr indent-spec))))
    saved-properties))

(defun elisp-format--restore-indent-properties (saved-properties)
  (dolist (saved-property saved-properties)
    (let ((symbol (nth 0 saved-property)))
      (if (nth 1 saved-property)
          (put
           symbol
           'lisp-indent-function
           (nth 2 saved-property))
        (cl-remprop symbol 'lisp-indent-function)))))

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
                (let ((saved-properties
                       (elisp-format--install-indent-specs)))
                  (unwind-protect
                      (cl-letf
                          (((symbol-function 'make-progress-reporter)
                            (lambda (&rest _) nil))
                           ((symbol-function 'progress-reporter-update)
                            (lambda (&rest _) nil))
                           ((symbol-function 'progress-reporter-done)
                            (lambda (&rest _) nil)))
                        (indent-region (point-min) (point-max)))
                    (elisp-format--restore-indent-properties
                     saved-properties)))
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

;;; elisp-format.el ends here
