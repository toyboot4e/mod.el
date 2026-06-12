# mod.el development tasks.  `just ci` runs everything.

emacs := "emacs"
stage := ".stage"

default: ci

ci: compile lint test

# Staged byte-compilation with warnings as errors.
[private]
alias c := compile
compile:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf "{{ stage }}" && mkdir -p "{{ stage }}"
    cp lisp/defmod.el "{{ stage }}/"
    "{{ emacs }}" -Q --batch -L "{{ stage }}" \
        --eval '(setq byte-compile-error-on-warn t)' \
        -f batch-byte-compile "{{ stage }}/defmod.el"
    echo "compiled: defmod"

# Run the ERT suite in batch.
[private]
alias t := test
test:
    "{{ emacs }}" -Q --batch -L lisp -L test \
        -l defmod-test \
        -f ert-run-tests-batch-and-exit

# package-lint and checkdoc, BOTH failing (stricter than aim-mode).
[private]
alias l := lint
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    "{{ emacs }}" -Q --batch -l package-lint \
        --eval '(setq package-lint-main-file "lisp/defmod.el")' \
        -f package-lint-batch-and-exit lisp/*.el
    # Load the package first: checkdoc accepts message text starting with
    # a DEFINED symbol, which is how the "defmod NAME: ..." error format
    # passes the capitalization check.
    out=$("{{ emacs }}" -Q --batch -L lisp -l defmod \
        --eval '(dolist (f (directory-files "lisp" t "\\.el$")) (checkdoc-file f))' 2>&1)
    if [ -n "$out" ]; then
        echo "$out"
        echo "checkdoc: FAIL"
        exit 1
    fi
    echo "checkdoc: clean"

clean:
    rm -rf "{{ stage }}" lisp/*.elc test/*.elc
