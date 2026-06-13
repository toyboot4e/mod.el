# defmod.el development tasks.  `just ci` runs everything.

emacs := "emacs"
stage := ".stage"

set script-interpreter := ['bash', '-euo', 'pipefail']

default: ci

# runs all the checks for CI
ci: compile lint test

[private]
alias c := compile

# staged byte-compilation with warnings as errors.
[script]
compile:
    rm -rf "{{ stage }}" && mkdir -p "{{ stage }}"
    cp lisp/defmod.el "{{ stage }}/"
    "{{ emacs }}" -Q --batch -L "{{ stage }}" \
        --eval '(setq byte-compile-error-on-warn t)' \
        -f batch-byte-compile "{{ stage }}/defmod.el"
    echo "compiled: defmod"

[private]
alias t := test

# runs the ERT suite in batch.
test:
    "{{ emacs }}" -Q --batch -L lisp -L test \
        -l defmod-test \
        -f ert-run-tests-batch-and-exit

[private]
alias l := lint

# applies package-lint and checkdoc.
[script]
lint:
    # package-lint, with ONE category false-positive suppressed: defmod
    # EMITS user configuration, so `with-eval-after-load' in the generated
    # code is that macro's sanctioned use, not a library misusing load
    # order.  package-lint's check is a plain text regexp that cannot tell
    # the difference.  Every other warning stays fatal.
    "{{ emacs }}" -Q --batch -l package-lint \
        --eval '(setq package-lint-main-file "lisp/defmod.el")' \
        --eval '(progn
                  (package-initialize)
                  (let ((text-quoting-style (quote grave)) (any nil))
                    (dolist (file (directory-files "lisp" t "\\.el$"))
                      (with-temp-buffer
                        (insert-file-contents file t)
                        (emacs-lisp-mode)
                        (dolist (r (package-lint-buffer))
                          (unless (string-match-p "eval-after-load" (nth 3 r))
                            (setq any t)
                            (message "%s:%d:%d: %s: %s"
                                     file (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r))))))
                    (kill-emacs (if any 1 0))))'
    # checkdoc via its diagnostic BUFFER, not the *warn* path `checkdoc-file'
    # uses: that routes findings through `warn' to stderr, where emacs's own
    # locale/autoload chatter would be scraped as false findings.  Collecting
    # into a buffer and scanning for "file:line:" lines isolates checkdoc's
    # real diagnostics; the elisp sets the exit code itself.  `-l defmod' so
    # checkdoc accepts the "defmod NAME: ..." error format (message text
    # starting with a defined symbol passes the capitalization check).
    "{{ emacs }}" -Q --batch -L lisp -l defmod \
        --eval '(require (quote checkdoc))' \
        --eval '(let ((checkdoc-diagnostic-buffer "*checkdoc*"))
                  (dolist (f (directory-files "lisp" t "\\.el$"))
                    (with-current-buffer (find-file-noselect f)
                      (checkdoc-current-buffer t)))
                  (with-current-buffer (get-buffer-create "*checkdoc*")
                    (goto-char (point-min))
                    (let ((found nil))
                      (while (re-search-forward "^.*\\.el:[0-9]+:.*$" nil t)
                        (setq found t) (princ (match-string 0)) (princ "\n"))
                      (kill-emacs (if found 1 0)))))'
    echo "lint: clean"

# cleans up `.elc` files
clean:
    rm -rf "{{ stage }}" lisp/*.elc test/*.elc
