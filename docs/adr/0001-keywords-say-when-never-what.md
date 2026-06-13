# Keywords say when, never what

`defmod` has no operation keywords — no `:bind`, `:setq`, `:custom`, `:hook`. Keywords only name Stages (`:init`, `:config`), Load Modes (`:defer`, `:after`), and the install source (`:vc`); everything that *happens* is plain Elisp the user writes inside a Stage (`setopt`, `add-hook`, `define-key`, ...). We rejected the leaf/use-package model (declarative operation keywords) and the setup.el model (operation keywords as local macros with name deduction) because operation keywords are where keyword inventories explode — leaf has 40+, four of them just for setting variables — and each one adds parser surface while abbreviating Elisp that is already short.

## Consequences

- defmod generates no autoload stubs (it cannot see inside user Lisp). Lazy loading rides on package.el-provided autoloads (`;;;###autoload` cookies); the rare uncookied function needs a manual `(autoload ...)` in `:init`.
- ~~There is no `:when` keyword: conditional blocks are plain Lisp around the form, `(when X (defmod foo ...))`.~~ Superseded by ADR-0005: a scheduling-only `:if COND` keyword gates the whole Block. (Operation keywords are still rejected; `:if` says *whether*, not *what*.)
- Verified in this design session: plain `setq`/`setopt` before load is honored by `defcustom` (the default initializer applies the option's `:set` function to the pre-set value), so no `:custom` keyword is needed for correctness.
