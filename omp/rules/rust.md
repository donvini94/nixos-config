---
name: rust
description: Rust standards for CLI tools, services, and internal libraries — error taxonomy, expect-over-unwrap, async discipline, clippy posture, test topology, new-crate scaffolding
globs:
  - "**/*.rs"
  - "**/Cargo.toml"
---
# Rust

Sourced from `omp/research/RustCraft.md` — Gjengset, dtolnay, matklad, Ryhl, Nethercote,
the Rust API Guidelines and the std-dev-guide. Where those disagree, the choice made here
is noted as a choice.

## Scope

Three shapes: binaries and CLIs, long-running services, and internal libraries consumed by
other code I own. **Nothing here is published to crates.io.** So the downstream-caller
ceremony is deliberately absent — no MSRV policy, no `cargo-semver-checks`, no sealed
traits, no `#[non_exhaustive]`, no mandatory doctests. If a crate is ever published, that
decision changes and this rule stops covering it.

## Errors

- Internal library: its own error type via `thiserror`. Binary or top layer:
  `anyhow::Result` with `.context(...)` at each step. The audience decides, not the crate
  type — a library whose errors are never matched on may legitimately use `anyhow`
  internally.
- Keep a library's error opaque: a public struct wrapping a private representation
  (`#[error(transparent)] pub struct Error(#[from] Repr)`). Never a public enum embedding
  dependency error types — that makes their major bump your major bump, and freezes the
  layout so boxing a fat variant later is breaking.
- `.context(...)` says what you were doing, not what failed. "reading config from
  `$path`", not "io error". The underlying error already knows it was an io error.

## Panics

- **`expect("reason")`, never bare `unwrap()`.** The string states the invariant that makes
  the call unreachable: `.expect("config validated at startup")`. A panic message that
  names its invariant is documentation that executes.
- In a spawned task a panic kills that task and nothing else, silently. So in service code
  propagate with `?` and decide at the task boundary; an `expect` there needs an invariant
  you could defend in review.
- Tests and `main()` are free.

## Async — services and daemons

- **Never spend more than ~10–100µs between `.await` points.** Sync I/O goes to
  `spawn_blocking`; CPU-bound work to `rayon` bridged with a `oneshot`; a never-ending
  loop to a dedicated `std::thread`. A blocking loop parked on `spawn_blocking` takes a
  thread out of the pool permanently, and the multi-threaded runtime has one per core —
  few enough to exhaust in production, many enough to hide the bug locally.
- **Bounded channels only.** Unbounded means unbounded memory and no backpressure.
- Long-lived owned state is an actor: a `Handle` holding an `mpsc::Sender` plus a task
  owning the state, spawned from the handle's constructor rather than from a `&mut self`
  method. Never merge the two — that gives every handle clone access to the task's fields.

## Types

- No bare `bool`, integer, or `String` standing for a domain concept. Newtype or a small
  enum. `Widget::new(true, false)` cannot be reviewed at the call site.
- No trait until there is a second implementor. Decide generic-versus-`dyn` at the trait
  definition; retrofitting object safety onto a trait with generic methods is a rewrite.
- Private fields plus accessors on anything carrying an invariant.
- Never bound a data structure on `Clone`, `PartialEq`, `PartialOrd`, `Debug`, `Display`,
  `Default`, `Serialize`, or `Deserialize`. `derive` supplies them, and a bound written by
  hand propagates to every user forever.

## Crate-root lints, day one

```rust
#![forbid(unsafe_code)]  // drop only when unsafe is genuinely needed, and say why in the commit
#![warn(missing_debug_implementations, unreachable_pub, rust_2018_idioms)]
#![deny(unused_must_use)]
```

`missing_docs` on an internal library only when the crate will outlive my memory of it.
`#[must_use]` only where discarding the value is almost certainly a bug — not reflexively;
nuisance warnings train `let _ =`, which then hides a real dropped `Result`.

## Clippy

Two levels, deliberately different:

- **While writing:** `pedantic`. The friction lands on the agent, not on me, and it is
  where the teaching is.
- **As the gate:** `correctness`, `suspicious`, `complexity`, `perf`, `style`, plus
  `dbg_macro`, `todo`, `print_stdout`, `print_stderr` denied — matklad's rust-analyzer set,
  which catches debugging residue before it ships.
- **In service and library crates additionally:** `clippy::unwrap_used` denied. That is the
  mechanical half of the `expect`-over-`unwrap` rule above; keep it allowed in `tests/` and
  in `main.rs`, where a panic is an acceptable exit.

When `pedantic` is wrong, `allow` that one lint at the narrowest scope with the reason in
the comment. Never blanket-allow a group. Known-wrong candidates with receipts:
`must_use_candidate` (clippy's own docs: "expect many false positives"),
`missing_errors_doc`, `missing_panics_doc`, `module_name_repetitions`,
`uninlined_format_args`, `wildcard_imports`, `similar_names`, `type_complexity`.
Never enable `nursery` or `restriction` wholesale — nobody credible does.

## Tests

- **One integration binary**: `tests/it/main.rs` with submodules, not many files under
  `tests/`. Cargo relinks the library once per file there and runs test binaries
  sequentially. Measured on cargo itself: 3× faster compile, 5× smaller artifacts.
- Unit tests as `#[cfg(test)] mod tests;` in a separate `tests.rs`, so editing tests does
  not recompile the library.
- `[lib] doctest = false` on internal crates. Each doctest links its own binary, and there
  are no external users copying examples.
- Property tests where there is a genuine round trip or ordering invariant. Commit
  `proptest-regressions/`, and promote every shrunk counterexample to a named `#[test]` —
  otherwise the fix is unprotected once the seed moves on.
- Miri in CI if any `unsafe` exists at all. Loom as well if the crate implements a
  concurrency primitive.

## Performance

Profile before optimising; optimised code costs complexity, so only hot code earns it.
Algorithm and data structure before micro-optimisation. `criterion` or `divan`, never
ad-hoc `Instant::now()` — wall time reports memory-layout noise as a win.
`#[inline(always)]` needs a microbenchmark attached to justify it.

## Comments

Comment the traps only: the places where an obvious future edit breaks something.
A lifetime or ownership choice that looks arbitrary but isn't, an async boundary, the
reason a construct was chosen over the obvious one. Not what the code does — the types
carry that. Silence everywhere else.

## Scaffolding a new crate

- A `[lints]` table in `Cargo.toml` carrying the gate set, workspace-inherited if there is
  a workspace.
- Multi-crate: flat `crates/*` under a virtual manifest, directory name identical to crate
  name, `version = "0.0.0"` for anything unpublished. No hierarchy — there are no perfect
  hierarchies, and Cargo's namespace is flat anyway.
- Repo automation in an `xtask` crate, not shell scripts.
- CI: `cargo fmt --check`, clippy at the gate set, `cargo test`. Add
  `cargo hack --feature-powerset check` only once the crate actually has features.
