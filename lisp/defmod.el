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

(provide 'defmod)
;;; defmod.el ends here
