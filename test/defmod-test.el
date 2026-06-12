;;; defmod-test.el --- ERT suite for defmod  -*- lexical-binding: t; -*-

;;; Commentary:

;; Expansion tests are the primary kind: `should'-`equal' the
;; `macroexpand-1' of a `defmod' form against the literal expected
;; expansion.  Every strict-grammar error path gets a `should-error'
;; test.  Behavioral tests stub `package-installed-p' and `provide' fake
;; features in-process; they never touch the network.

;;; Code:

(require 'ert)
(require 'defmod)

(ert-deftest defmod-test-feature-loads ()
  "The defmod feature is loadable."
  (should (featurep 'defmod)))

;;;; Golden expansion tests

(ert-deftest defmod-test-instant-expansion ()
  "An undecorated Block ensures, requires at startup, then runs :config."
  (should (equal (macroexpand-1 '(defmod foo :config (foo-setup)))
                 '(progn
                    (unless (package-installed-p 'foo)
                      (unless (assq 'foo package-archive-contents)
                        (package-refresh-contents))
                      (package-install 'foo))
                    (require 'foo)
                    (foo-setup)))))

(provide 'defmod-test)
;;; defmod-test.el ends here
