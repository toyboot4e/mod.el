# defmod.el

A DSL for writing Emacs package configuration that keeps startup fast through deferral, with internals simple enough for one person to fully understand.

## Language

**Fast**:
Short startup time of an *uncompiled* init file. Achieved primarily by deferring package loading, secondarily by cheap macro expansion (expansion runs on every startup since nothing is byte-compiled).
_Avoid_: fast byte-compiled output, fast macroexpansion in isolation

**Block**:
One `(defmod NAME ...)` form: the complete configuration of one package. Its body is a flat keyword plist, use-package style. (The macro is `defmod`, never `mod` — `mod` is the built-in modulo function.)
_Avoid_: declaration, stanza

**Keyword**:
A label inside a Block. Keywords only ever name Stages (`:init`, `:config`), Load Modes (`:defer`, `:after`), the install source (`:vc`), or the load condition (`:if`, see ADR-0005). defmod has no operation keywords — no `:bind`, no `:setq`, no `:hook`. What happens is always plain Elisp; Keywords only say *when* (and *whether*, and *from where*).

**Stage**:
A Keyword introducing a run of plain Elisp forms distinguished only by *when* they run. There are exactly two: `:init` (at startup, before the package can load) and `:config` (once the package has loaded). Users call `setopt`/`add-hook`/`define-key`/anything directly inside a Stage.

**Load Mode**:
When the package loads. Exactly one per Block, or none: Instant (the default — `require` at startup), Deferred (`:defer` — loads only when a Trigger fires), Autoload (`:autoload (CMDS)` — Deferred, and defmod additionally emits autoload stubs so the named commands are themselves the Triggers), or After (`:after FEATURES` — loads once the named features have all loaded). The three non-Instant modes are mutually exclusive.

**Instant Load**:
The default Load Mode: the package is `require`d at startup and `:config` runs immediately after.

**Deferral**:
The opt-in Load Modes (`:defer`, `:after`): the Block does not load the package at startup; `:config` waits inside `eval-after-load`.

**Trigger**:
An eagerly-installed registration — a keybinding, hook, or `auto-mode-alist` entry — written as plain Lisp in `:init`, which causes a Deferred package to load on first use. The load fires through an autoload: usually one the package ships, or one defmod emits when the command is listed in `:autoload`.

**Ensure**:
Every Block installs its package at startup if it is missing. The default source is the package archives (package.el); `:vc` switches the source to a version-control checkout (package-vc).

**Skeleton**:
The single fixed code shape every Block expands into. Slots in the Skeleton are filled by Handlers; no Handler ever wraps or sees another Handler's output.

**Slot**:
A named position in the Skeleton (e.g. ensure, init forms, load form, config forms) that Handlers contribute forms to.

**Handler**:
The function for one Keyword that turns the keyword's value into forms for a Slot.
_Avoid_: normalizer (there is no separate normalize pass)

## Example dialogue

> **Dev:** I want consult to set up its previews, but only once it's actually in use.
>
> **Expert:** Then the Block stays in the default-instant Load Mode only if you accept consult loading at startup. You don't — so mark it `:defer`. Now nothing loads until a Trigger fires: put your `define-key` for `consult-buffer` in `:init`; the keybinding rides on consult's own autoload. Your preview setup goes in `:config`, which waits in `eval-after-load`.
>
> **Dev:** And `consult-projectile`? It only matters once both consult and projectile are in.
>
> **Expert:** That Block is neither instant nor Trigger-driven — it's `:after (consult projectile)`: it loads the moment the last of those features arrives. `:defer` and `:after` are exclusive; a Block has exactly one Load Mode.
>
> **Dev:** Where do I write `(setopt consult-narrow-key "<")`?
>
> **Expert:** That's plain Elisp, so it goes in a Stage — `:init` if consult must see it at load time, `:config` if it can apply after. There is no `:custom` keyword; Keywords only say *when*, never *what*.
