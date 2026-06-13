# Ideas / backlog

Loose design ideas not yet promoted to an ADR. Recording, not deciding.

## ~~`:if COND` — conditional load keyword~~ — DONE (ADR-0005)

Implemented: `:if COND` gates the whole Block. See `docs/adr/0005`.

## `:ensure nil` — configure without installing

defmod's Ensure is mandatory: every Block tries to `package-install` its name.
leaf/use-package both ship `:ensure nil` so a Block can configure a **built-in**
(`prolog-mode`, `proced`, `javascript-mode`) or a **sub-feature of an
already-installed package** (`lsp-ui-imenu`) without installing anything. defmod
has no such opt-out, so those packages currently can't be defmod Blocks at all —
they fall back to plain Elisp. Worth deciding whether an install-source value
like `:vc none` / `:builtin` belongs in the grammar, or whether plain Elisp is
the intended answer for built-ins.
