;;; defmod-test.el --- ERT suite for defmod  -*- lexical-binding: t; -*-

;;; Commentary:

;; Expansion tests are the primary kind: `should'-`equal' the
;; `macroexpand-1' of a `defmod' form against the literal expected
;; expansion.  Every strict-grammar error path gets a `should-error'
;; test.  Behavioral tests stub `package-installed-p' and `provide' fake
;; features in-process; they never touch the network.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'defmod)

;;;; Fixture

(defvar defmod-test--log nil
  "Events recorded by behavioral tests, most recent first.")

(defmacro defmod-test--with-fake-packages (feats &rest body)
  "Run BODY with the package system stubbed for the symbols FEATS.
`package-installed-p' answers t so Ensure never installs, and
`require' simply `provide's its feature, simulating a successful
load (which also fires `with-eval-after-load' bodies).  Fake
features and their `after-load-alist' entries are cleaned up
afterwards, and `defmod-test--log' starts empty."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'package-installed-p) (lambda (&rest _) t))
             ((symbol-function 'require)
              (lambda (feature &rest _) (provide feature) feature)))
     (setq defmod-test--log nil)
     (unwind-protect
         (progn ,@body)
       (dolist (feat ',feats)
         (setq features (delq feat features))
         (setq after-load-alist (assq-delete-all feat after-load-alist))))))

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

;;;; Strict-grammar error tests

(ert-deftest defmod-test-error-unknown-keyword ()
  "An unknown keyword is an expansion-time error naming the Block."
  (let ((err (should-error (macroexpand-1 '(defmod foo :bind ("a" . b))))))
    (should (string-match-p "defmod foo: unknown keyword :bind"
                            (cadr err)))))

(ert-deftest defmod-test-error-duplicate-keyword ()
  "A repeated keyword is an expansion-time error."
  (let ((err (should-error (macroexpand-1 '(defmod foo
                                             :config (a)
                                             :config (b))))))
    (should (string-match-p "defmod foo: duplicate keyword :config"
                            (cadr err)))))

(ert-deftest defmod-test-error-stageless-form ()
  "A form outside any Stage is an expansion-time error.
This covers both forms before the first keyword and forms after
non-Stage keywords like :defer."
  (let ((err (should-error (macroexpand-1 '(defmod foo (setq x 1))))))
    (should (string-match-p "defmod foo: form belongs to no stage"
                            (cadr err))))
  (should-error (macroexpand-1 '(defmod foo :defer (setq x 1)))))

(ert-deftest defmod-test-error-defer-after-conflict ()
  "The Load Modes :defer and :after are mutually exclusive."
  (let ((err (should-error (macroexpand-1 '(defmod foo
                                             :defer
                                             :after (bar)
                                             :config (a))))))
    (should (string-match-p "defmod foo: :after conflicts with :defer"
                            (cadr err))))
  (should-error (macroexpand-1 '(defmod foo :after (bar) :defer :config (a)))))

(ert-deftest defmod-test-error-after-needs-feature-list ()
  "The first form after :after is always a list of feature symbols."
  (let ((err (should-error (macroexpand-1 '(defmod foo :after :config (a))))))
    (should (string-match-p "defmod foo: :after needs a list of features"
                            (cadr err))))
  (should-error (macroexpand-1 '(defmod foo :after bar :config (a))))
  (should-error (macroexpand-1 '(defmod foo :after (bar "baz") :config (a))))
  (should-error (macroexpand-1 '(defmod foo :after))))

(ert-deftest defmod-test-error-vc-needs-spec ()
  "The first form after :vc is always a package-vc spec list."
  (let ((err (should-error (macroexpand-1 '(defmod foo :vc :config (a))))))
    (should (string-match-p "defmod foo: :vc needs a spec list" (cadr err))))
  (should-error (macroexpand-1 '(defmod foo :vc "https://example.com"))))

(ert-deftest defmod-test-error-name-must-be-symbol ()
  "The Block NAME is a plain symbol: a feature/package name."
  (should-error (macroexpand-1 '(defmod "foo" :config (a))))
  (should-error (macroexpand-1 '(defmod (foo) :config (a))))
  (should-error (macroexpand-1 '(defmod :foo :config (a))))
  (should-error (macroexpand-1 '(defmod nil :config (a)))))

;;;; Behavioral tests

(ert-deftest defmod-test-behavior-defer-waits-for-load ()
  "A :defer Block's :config runs when the package loads, not before."
  (defmod-test--with-fake-packages (defmod-fake-foo)
    (eval (macroexpand-1 '(defmod defmod-fake-foo
                            :defer
                            :config (push 'configured defmod-test--log)))
          t)
    (should-not defmod-test--log)
    (provide 'defmod-fake-foo)
    (should (equal defmod-test--log '(configured)))))

(ert-deftest defmod-test-behavior-instant-runs-in-order ()
  "An instant Block runs :init, loads, then runs :config, immediately."
  (defmod-test--with-fake-packages (defmod-fake-bar)
    (eval (macroexpand-1 '(defmod defmod-fake-bar
                            :init (push 'init defmod-test--log)
                            :config (push 'config defmod-test--log)))
          t)
    (should (equal (reverse defmod-test--log) '(init config)))
    (should (featurep 'defmod-fake-bar))))

(ert-deftest defmod-test-behavior-after-waits-for-all-features ()
  "An :after Block loads and configures only when ALL features are in."
  (defmod-test--with-fake-packages (defmod-fake-a defmod-fake-b
                                                  defmod-fake-qux)
    (eval (macroexpand-1 '(defmod defmod-fake-qux
                            :after (defmod-fake-a defmod-fake-b)
                            :config (push 'glued defmod-test--log)))
          t)
    (provide 'defmod-fake-a)
    (should-not defmod-test--log)        ; one feature is not enough
    (should-not (featurep 'defmod-fake-qux))
    (provide 'defmod-fake-b)
    (should (equal defmod-test--log '(glued)))
    (should (featurep 'defmod-fake-qux)))) ; the package loaded itself

(provide 'defmod-test)
;;; defmod-test.el ends here
