# Conditional load via `:if`

`defmod` has an `:if COND` keyword: it gates the whole Block — Ensure, load,
and both Stages — on `COND`, expanding to `(when COND (progn …))`. When `COND`
is nil the Block installs and loads nothing. It composes with every Load Mode
and with `:vc`.

This supersedes the consequence in ADR-0001 that said "there is no `:when`
keyword; conditional blocks are plain Lisp around the form." Dogfooding a large
real config (porting from leaf.el) showed `:if` is common — `(leaf slime :if
(file-exists-p …))`, version and executable guards — and the plain-Lisp
alternative `(when COND (defmod foo …))` pushes the condition *outside* the
Block, so a `grep` for the package name no longer reveals that it is
conditional, and it nests the whole form an extra level.

## Why this does not reopen ADR-0001

ADR-0001 rejects *operation* keywords (`:bind`, `:custom`, `:hook`) — keywords
that say *what happens*. `:if` says nothing about what happens; it is pure
*scheduling* ("whether this Block runs at all"), the same axis as the Load
Modes. "Keywords say when, never what" still holds: `:if` answers *whether*,
which is a degenerate *when*. It abbreviates no Elisp payload — the condition is
still the user's plain expression.

## Engine discipline (ADR-0003)

`:if` is one more Slot filled by the single forward parse pass, and one outer
`when` wrapper on the otherwise-unchanged assembly template. No new `eval`, no
recursion, no keyword sorting. Presence is tracked with `plist-member` so that
`:if nil` (wrap in `(when nil …)`) is distinct from an omitted `:if` (bare
`progn`).

## Consequences

- `:if` is the only control-flow keyword. `:unless`/`:when` are not added —
  write `:if (not …)`; multiple conditions are `:if (and …)`.
- A golden expansion test pins `(when COND (progn …))`; a second test pins that
  omitted `:if` leaves the bare `progn` and `:if nil` still wraps.
- leaf calls this keyword `:if` too; we match the name.
