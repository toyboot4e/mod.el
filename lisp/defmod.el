;;; defmod.el --- A package-configuration macro that only schedules  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 toyboot4e

;; Author: toyboot4e <toyboot4e@gmail.com>
;; Maintainer: toyboot4e <toyboot4e@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1"))
;; Keywords: lisp
;; URL: https://github.com/toyboot4e/mod.el
;; SPDX-License-Identifier: CC0-1.0

;;; Commentary:

;; `defmod' configures one package per Block: keywords say *when*, never
;; *what*.  Stages (:init, :config) hold plain Elisp; Load Modes (:defer,
;; :after, or instant by default) decide when the package loads; :vc
;; overrides the install source.  See CONTEXT.md for the glossary and
;; docs/adr/ for the architecture decisions.

;;; Code:

(defun defmod--parse (name body)
  "Parse BODY of the Block NAME with one forward pass.
Return a plist with the Slots :mode, :features, :vc, :init and
:config.  Signal an error on any strict-grammar violation."
  (let ((mode 'instant) (features nil) (vc nil)
        (init nil) (config nil) (stage nil) (seen nil))
    (while body
      (let ((head (pop body)))
        (cond
         ((keywordp head)
          (unless (memq head '(:init :config :defer :after :vc))
            (error "defmod %s: unknown keyword %s" name head))
          (when (memq head seen)
            (error "defmod %s: duplicate keyword %s" name head))
          (push head seen)
          (cond
           ((eq head :init) (setq stage 'init))
           ((eq head :config) (setq stage 'config))
           ((eq head :defer)
            (unless (eq mode 'instant)
              (error "defmod %s: :defer conflicts with :%s" name mode))
            (setq mode 'defer stage nil))
           ((eq head :after)
            (unless (eq mode 'instant)
              (error "defmod %s: :after conflicts with :%s" name mode))
            (let ((value (car body)))
              (unless (and (proper-list-p value) value
                           (seq-every-p #'symbolp value)
                           (not (seq-some #'keywordp value)))
                (error "defmod %s: :after needs a list of features, got %S"
                       name value)))
            (setq features (pop body) mode 'after stage nil))
           ((eq head :vc)
            (let ((value (car body)))
              (unless (and (proper-list-p value) value)
                (error "defmod %s: :vc needs a spec list, got %S"
                       name value)))
            (setq vc (pop body) stage nil))))
         ((eq stage 'init) (push head init))
         ((eq stage 'config) (push head config))
         (t (error "defmod %s: form belongs to no stage: %S" name head)))))
    (list :mode mode :features features :vc vc
          :init (nreverse init) :config (nreverse config))))

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
  :after (FEATS...)  load as soon as all FEATS have loaded
  :vc (SPEC...)      install from version control (package-vc spec)

\:defer and :after are mutually exclusive; with neither, the
package is `require'd at startup and :config runs immediately.
The package is installed first whenever it is missing."
  (declare (indent defun))
  (unless (and name (symbolp name) (not (keywordp name)))
    (error "defmod: NAME must be a symbol, got %S" name))
  (let* ((slots (defmod--parse name body))
         (mode (plist-get slots :mode))
         (config (plist-get slots :config)))
    `(progn
       ,(defmod--ensure-form name (plist-get slots :vc))
       ,@(plist-get slots :init)
       ,@(cond
          ((eq mode 'defer)
           `((with-eval-after-load ',name ,@config)))
          ((eq mode 'after)
           (let ((forms `((require ',name) ,@config)))
             (dolist (feature (reverse (plist-get slots :features)))
               (setq forms `((with-eval-after-load ',feature ,@forms))))
             forms))
          (t `((require ',name) ,@config))))))

(provide 'defmod)
;;; defmod.el ends here
