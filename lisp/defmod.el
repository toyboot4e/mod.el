;;; defmod.el --- A package-configuration macro that only schedules  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 toyboot4e

;; Author: toyboot4e <toyboot4e@gmail.com>
;; Maintainer: toyboot4e <toyboot4e@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1"))
;; Keywords: lisp
;; URL: https://github.com/toyboot4e/defmod.el
;; SPDX-License-Identifier: CC0-1.0

;;; Commentary:

;; `defmod' configures one package per Block: keywords say *when*, never
;; *what*.  Stages (:init, :config) hold plain Elisp; Load Modes (:defer,
;; :after, or instant by default) decide when the package loads; :vc
;; overrides the install source.  See CONTEXT.md for the glossary and
;; docs/adr/ for the architecture decisions.

;;; Code:

(defun defmod--check-mode (name current new)
  "Return NEW, the Load Mode that Block NAME is entering.
Signal an error if CURRENT already names a Load Mode: `defer',
`autoload' and `after' are mutually exclusive."
  (unless (eq current 'instant)
    (error "defmod %s: :%s conflicts with :%s" name new current))
  new)

(defun defmod--symbol-list (name keyword noun value)
  "Return VALUE, requiring a non-empty list of plain (non-keyword) symbols.
NAME, KEYWORD and NOUN compose the error for Block NAME's KEYWORD."
  (unless (and (proper-list-p value) value
               (seq-every-p #'symbolp value)
               (not (seq-some #'keywordp value)))
    (error "defmod %s: %s needs a list of %s, got %S" name keyword noun value))
  value)

(defun defmod--parse (name body)
  "Parse BODY of the Block NAME with one forward pass.
Return a plist with the Slots :mode, :features, :autoloads, :vc,
:init and :config, plus :if when an :if condition is present.
Signal an error on any strict-grammar violation."
  (let ((mode 'instant) (features nil) (autoloads nil) (vc nil)
        (init nil) (config nil) (stage nil) (seen nil)
        (condition nil) (if-p nil))
    (while body
      (let ((head (pop body)))
        (cond
         ((keywordp head)
          (unless (memq head '(:init :config :defer :autoload :after :vc :if))
            (error "defmod %s: unknown keyword %s" name head))
          (when (memq head seen)
            (error "defmod %s: duplicate keyword %s" name head))
          (push head seen)
          (cond
           ((eq head :init) (setq stage 'init))
           ((eq head :config) (setq stage 'config))
           ((eq head :defer)
            (setq mode (defmod--check-mode name mode 'defer) stage nil))
           ((eq head :autoload)
            (setq mode (defmod--check-mode name mode 'autoload) stage nil)
            (setq autoloads (defmod--symbol-list name head "commands" (pop body))))
           ((eq head :after)
            (setq mode (defmod--check-mode name mode 'after) stage nil)
            (setq features (defmod--symbol-list name head "features" (pop body))))
           ((eq head :vc)
            (let ((value (car body)))
              (unless (and (proper-list-p value) value)
                (error "defmod %s: :vc needs a spec list, got %S" name value)))
            (setq vc (pop body) stage nil))
           ((eq head :if)
            (setq condition (pop body) if-p t stage nil))))
         ((eq stage 'init) (push head init))
         ((eq stage 'config) (push head config))
         (t (error "defmod %s: form belongs to no stage: %S" name head)))))
    (append
     (list :mode mode :features features :autoloads autoloads :vc vc
           :init (nreverse init) :config (nreverse config))
     (and if-p (list :if condition)))))

(defun defmod--ensure-form (name vc)
  "Return the Ensure form installing NAME when it is missing.
The source is the package archives, or a version-control checkout
when the package-vc spec VC is non-nil."
  (if vc
      `(unless (package-installed-p ',name)
         (package-vc-install '(,name ,@vc)))
    `(unless (package-installed-p ',name)
       (unless (assq ',name package-archive-contents)
         (package-refresh-contents))
       (package-install ',name))))

;;;###autoload
(defmacro defmod (name &rest body)
  "Configure the package NAME; Stages in BODY say when, never what.

NAME is the package and feature symbol.  BODY is a flat keyword
plist holding plain Elisp; the keywords are:

  :init FORMS...     run at startup, before the package can load
  :config FORMS...   run once the package has loaded
  :defer             load only when something autoloads the package
  :autoload (CMDS)   like :defer, but autoload CMDS so they trigger it
  :after (FEATS...)  load as soon as all FEATS have loaded
  :vc (SPEC...)      install from version control (package-vc spec)
  :if COND           gate the whole Block on COND; skip it when COND is nil

\:defer, :autoload and :after are mutually exclusive Load Modes;
with none, the package is `require'd at startup and :config runs
immediately.  The package is installed first whenever it is missing.
With :if, the entire expansion -- Ensure included -- is wrapped so
the Block does nothing unless COND evaluates non-nil."
  (declare (indent defun))
  (unless (and name (symbolp name) (not (keywordp name)))
    (error "defmod: NAME must be a symbol, got %S" name))
  (let* ((slots (defmod--parse name body))
         (mode (plist-get slots :mode))
         (config (plist-get slots :config))
         (form
          `(progn
             ,(defmod--ensure-form name (plist-get slots :vc))
             ,@(mapcar (lambda (cmd) `(autoload ',cmd ,(symbol-name name) nil t))
                       (plist-get slots :autoloads))
             ,@(plist-get slots :init)
             ,@(cond
                ((memq mode '(defer autoload))
                 `((with-eval-after-load ',name ,@config)))
                ((eq mode 'after)
                 (let ((forms `((require ',name) ,@config)))
                   (dolist (feature (reverse (plist-get slots :features)))
                     (setq forms `((with-eval-after-load ',feature ,@forms))))
                   forms))
                (t `((require ',name) ,@config))))))
    ;; :if gates the whole Block; an absent :if leaves the bare progn.
    (if (plist-member slots :if)
        `(when ,(plist-get slots :if) ,form)
      form)))

(provide 'defmod)
;;; defmod.el ends here
