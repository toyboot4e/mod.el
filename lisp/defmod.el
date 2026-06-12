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
Return a plist with the Slots :mode, :init and :config."
  (let ((mode 'instant) (features nil) (vc nil)
        (init nil) (config nil) (stage nil))
    (while body
      (let ((head (pop body)))
        (cond
         ((eq head :init) (setq stage 'init))
         ((eq head :config) (setq stage 'config))
         ((eq head :defer) (setq mode 'defer stage nil))
         ((eq head :after)
          (setq features (pop body) mode 'after stage nil))
         ((eq head :vc)
          (setq vc (pop body) stage nil))
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
BODY is a flat keyword plist holding plain Elisp in Stages.  The
package is installed when missing and, by default, `require'd at
startup with the :config Stage run immediately after."
  (declare (indent defun))
  (let ((slots (defmod--parse name body)))
    `(progn
       ,(defmod--ensure-form name (plist-get slots :vc))
       ,@(plist-get slots :init)
       ,@(let ((config (plist-get slots :config)))
           (cond
            ((eq (plist-get slots :mode) 'defer)
             `((with-eval-after-load ',name ,@config)))
            ((eq (plist-get slots :mode) 'after)
             (let ((forms `((require ',name) ,@config)))
               (dolist (feature (reverse (plist-get slots :features)))
                 (setq forms `((with-eval-after-load ',feature ,@forms))))
               forms))
            (t `((require ',name) ,@config)))))))

(provide 'defmod)
;;; defmod.el ends here
