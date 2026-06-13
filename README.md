# defmod.el

`defmod` — an Emacs package-configuration macro that **only schedules**:
keywords say *when*, never *what*. What happens is always plain Elisp you
write yourself; the expansion is exactly the code you would write by hand.

```elisp
(defmod vertico
  :init   (setopt vertico-cycle t)   ; startup, before vertico loads
  :config (vertico-mode 1))          ; once vertico has loaded

(defmod foo
  :defer                             ; load only when a trigger fires
  :init (keymap-global-set "C-c f" #'foo-cmd)  ; the trigger
  :config (foo-setup))

(defmod consult-projectile
  :vc (:url "https://example.com/consult-projectile")
  :after (consult projectile)        ; load once both are in
  :config (consult-projectile-mode 1))
```

## Grammar

```
(defmod NAME
  [:if COND]                 ; skip the whole Block unless COND is non-nil
  [:vc (SPEC...)]            ; install from VC (package-vc spec) instead of archives
  [:defer | :autoload (CMDS...) | :after (FEATS...)]
  [:init FORMS...]           ; run at startup
  [:config FORMS...])        ; run once NAME has loaded
```

- **Instant (default):** `require` at startup, `:config` right after.
- **`:defer`:** nothing loads at startup; loading rides on the package's own
  autoloads, triggered by whatever you registered in `:init` (a keybinding,
  a hook, an `auto-mode-alist` entry). `:config` waits in
  `with-eval-after-load`.
- **`:autoload (CMDS...)`:** like `:defer`, but for packages that *don't*
  autoload their own entry commands — defmod emits `(autoload 'cmd "NAME" …)`
  for each, so your `:init` triggers can load the package.
- **`:after (FEATS...)`:** the package is `require`d the moment all FEATS
  have loaded.
- **`:if COND`:** gates the whole Block — Ensure, load and Stages — on `COND`;
  when `COND` is nil the Block expands to a no-op, installing and loading
  nothing. Composes with any Load Mode.
- Every Block installs its package first when missing (package.el, or
  package-vc with `:vc`).
- The grammar is strict: unknown keywords, duplicate keywords, forms outside
  a stage, and `:defer` + `:after` together are expansion-time errors.

There are no operation keywords (`:bind`, `:hook`, `:custom`, ...) — that is
plain Elisp, written in a stage. Conditional loading is the one bit of control
flow defmod schedules: `:if` (see `docs/adr/0005`). See `CONTEXT.md` for the
project glossary and `docs/adr/` for why.

## Expansion

`defmod` only schedules, so the expansion is exactly the code you would write
by hand — no runtime, no hidden state. Each Load Mode below shows a Block and
the form it expands to (these match the golden tests in
`test/defmod-test.el`).

**Instant (default)** — install if missing, `require` at startup, then `:config`:

```elisp
(defmod foo
  :config (foo-setup))
;; ⇒
(progn
  (unless (package-installed-p 'foo)
    (unless (assq 'foo package-archive-contents)
      (package-refresh-contents))
    (package-install 'foo))
  (require 'foo)
  (foo-setup))
```

**`:defer`** — `:init` runs at startup to register triggers; `:config` waits
in `with-eval-after-load`, and nothing `require`s `foo` directly:

```elisp
(defmod foo
  :defer
  :init (keymap-global-set "C-c f" #'foo-cmd)
  :config (foo-setup))
;; ⇒
(progn
  (unless (package-installed-p 'foo)
    (unless (assq 'foo package-archive-contents)
      (package-refresh-contents))
    (package-install 'foo))
  (keymap-global-set "C-c f" #'foo-cmd)
  (with-eval-after-load 'foo
    (foo-setup)))
```

**`:autoload (CMDS...)`** — like `:defer`, plus an `autoload` stub per command
(the file is the package name) so a trigger can load the package:

```elisp
(defmod foo
  :autoload (foo-cmd foo-other)
  :init (keymap-global-set "C-c f" #'foo-cmd)
  :config (foo-setup))
;; ⇒
(progn
  (unless (package-installed-p 'foo)
    (unless (assq 'foo package-archive-contents)
      (package-refresh-contents))
    (package-install 'foo))
  (autoload 'foo-cmd "foo" nil t)
  (autoload 'foo-other "foo" nil t)
  (keymap-global-set "C-c f" #'foo-cmd)
  (with-eval-after-load 'foo
    (foo-setup)))
```

**`:after (FEATS...)`** — the `require` and `:config` nest inside one
`with-eval-after-load` per feature, firing only when the last feature loads:

```elisp
(defmod foo
  :after (bar baz)
  :config (foo-glue))
;; ⇒
(progn
  (unless (package-installed-p 'foo)
    (unless (assq 'foo package-archive-contents)
      (package-refresh-contents))
    (package-install 'foo))
  (with-eval-after-load 'bar
    (with-eval-after-load 'baz
      (require 'foo)
      (foo-glue))))
```

**`:vc (SPEC...)`** — swaps only the install step for `package-vc-install`,
passing the spec verbatim; the rest of the Load Mode is unchanged:

```elisp
(defmod foo
  :vc (:url "https://example.com/foo")
  :config (foo-setup))
;; ⇒
(progn
  (unless (package-installed-p 'foo)
    (package-vc-install
     '(foo :url "https://example.com/foo")))
  (require 'foo)
  (foo-setup))
```

**`:if COND`** — wraps the entire expansion in `when`, so a nil `COND` skips
install and load alike (composes with every Load Mode and `:vc`):

```elisp
(defmod foo
  :if (executable-find "foo")
  :config (foo-setup))
;; ⇒
(when (executable-find "foo")
  (progn
    (unless (package-installed-p 'foo)
      (unless (assq 'foo package-archive-contents)
        (package-refresh-contents))
      (package-install 'foo))
    (require 'foo)
    (foo-setup)))
```

## Bootstrapping

`defmod` is not on ELPA, so it cannot install itself the way it installs the
packages you configure. Bootstrap it once from version control with the
built-in `package-vc` (Emacs 30+), then `require` it before any Block:

```elisp
;; early in init.el, after (package-initialize)
(unless (package-installed-p 'defmod)
  (package-vc-install "https://github.com/toyboot4e/defmod.el"))
(require 'defmod)

;; from here on, Blocks work — and each one installs its own package
(defmod vertico
  :config (vertico-mode 1))
```

If you already use `use-package`, its `:vc` keyword does the same in one form
(note `defmod` itself still needs the `require` before you write any Block):

```elisp
(use-package defmod
  :vc (:url "https://github.com/toyboot4e/defmod.el")
  :demand t)
```

Once `defmod` is loaded, packages you configure with a `:vc` Block are
installed from version control too — no `use-package` needed for those:

```elisp
(defmod consult-projectile
  :vc (:url "https://github.com/OlMon/consult-projectile")
  :after (consult projectile)
  :config (consult-projectile-mode 1))
```

## Development

`nix develop`, then `just ci` (byte-compile with warnings as errors,
package-lint + checkdoc, ERT suite). License: CC0-1.0.
