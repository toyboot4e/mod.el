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

(ert-deftest defmod-test-defer-expansion ()
  "A :defer Block never requires; :config waits in eval-after-load.
Loading rides on Triggers installed in :init."
  (should (equal (macroexpand-1 '(defmod foo
                                   :defer
                                   :init (keymap-global-set "C-c f" #'foo-cmd)
                                   :config (foo-setup)))
                 '(progn
                    (unless (package-installed-p 'foo)
                      (unless (assq 'foo package-archive-contents)
                        (package-refresh-contents))
                      (package-install 'foo))
                    (keymap-global-set "C-c f" #'foo-cmd)
                    (with-eval-after-load 'foo
                      (foo-setup))))))

(ert-deftest defmod-test-after-expansion ()
  "An :after Block requires the moment the named features have loaded."
  (should (equal (macroexpand-1 '(defmod foo
                                   :after (bar baz)
                                   :config (foo-glue)))
                 '(progn
                    (unless (package-installed-p 'foo)
                      (unless (assq 'foo package-archive-contents)
                        (package-refresh-contents))
                      (package-install 'foo))
                    (with-eval-after-load 'bar
                      (with-eval-after-load 'baz
                        (require 'foo)
                        (foo-glue)))))))

(ert-deftest defmod-test-vc-expansion ()
  "A :vc Block ensures via package-vc-install with the spec verbatim."
  (should (equal (macroexpand-1 '(defmod foo
                                   :vc (:url "https://example.com/foo")
                                   :config (foo-setup)))
                 '(progn
                    (unless (package-installed-p 'foo)
                      (package-vc-install
                       '(foo :url "https://example.com/foo")))
                    (require 'foo)
                    (foo-setup)))))

(ert-deftest defmod-test-init-runs-before-require ()
  "The :init Stage runs at startup, before the package loads."
  (should (equal (macroexpand-1 '(defmod foo
                                   :init (setopt foo-flag t) (other)
                                   :config (foo-setup)))
                 '(progn
                    (unless (package-installed-p 'foo)
                      (unless (assq 'foo package-archive-contents)
                        (package-refresh-contents))
                      (package-install 'foo))
                    (setopt foo-flag t)
                    (other)
                    (require 'foo)
                    (foo-setup)))))

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
