# Project templates

Verified starting points for a new Rust or Python project. They exist to convert prose rules
into mechanism: anything a compiler, linter or CI job can enforce belongs here, not in
`rule://rust` or `rule://python`.

## How this gets used

**Starting a project.** The agent is writing `Cargo.toml` or `pyproject.toml`, so the globs
on `rule://rust` / `rule://python` put that rule in scope. The rule's scaffolding section
says: copy this template, rename, delete what you do not need. From that point the gate is
`cargo clippy -D warnings` and `ruff`/`mypy`/`pytest` — not the agent remembering a bullet.

**Working in an existing project.** The rulebook rule is read on demand for the judgment
calls that no tool can make: which error type, where the trait boundary goes, whether this
data is trusted, what the invariant actually is. The two TTSR rules
(`python-silent-failure`, `rust-runtime-hazard`) fire mid-write on the six patterns that
ship silently — missing timeout, unpaginated collection, secret reaching a log, unbounded
channel, blocking call in async, `unsafe`.

**The layering, in priority order.** Mechanism beats interrupt beats prose:

1. **Compiler or linter** — cannot be forgotten, costs zero tokens, fails the build. Put
   everything here that fits.
2. **TTSR interrupt** — for what no linter checks. Costs tokens only when it fires. Keep the
   set small; an interrupt that cries wolf gets ignored, exactly like an every-turn prompt.
3. **Rulebook prose** — judgment only. If a rule here could be a lint, it is in the wrong
   layer.

## What is verified, and how

Both templates were run, not just written.

**Rust** (cargo 1.96, clippy 0.1.96): `cargo check --all-targets`, `cargo clippy
--all-targets` and `cargo test` clean on a fresh copy. The gate was then proven to bite —
adding a bare `unwrap()` fails clippy with exit 101 (`-D clippy::unwrap-used`), and adding an
`unsafe` block fails on `-F unsafe-code`.

**Python** (uv 0.12.1, ruff 0.16.0, mypy strict, Python 3.14.7): `uv sync`, `ruff check`,
`ruff format --check`, `mypy src tests`, `pytest` all pass. The lint selection was proven to
reject a probe file containing a bare `except`, a hardcoded secret, `subprocess.run` without
`check`, `pickle.loads`, and a partial executable path — `E722`, `S105`, `PLW1510`, `S301`,
`S607` all fired.

Two real defects surfaced during that verification and are fixed in the template:

- `structlog`'s default `PrintLoggerFactory` writes to **stdout**, which mixes diagnostics
  into the tool's output and breaks `... | jq`. The template configures
  `PrintLoggerFactory(file=sys.stderr)` and the smoke test asserts on `result.stdout` to
  keep it honest.
- **`ruff`'s `S113` fires on `requests` only, not on `httpx`.** Since we standardised on
  httpx, the explicit-timeout rule has no linter behind it — the TTSR interrupt is its only
  enforcement. Do not assume a lint covers it.

## Maintenance

The template and its rule are a pair. Changing one without the other is how the rule starts
lying — which is exactly the failure the `S113` note above records. When a decision changes:
edit the template, re-run its gate, then update the rule to match.

There is deliberately no drift-checker for existing projects. Nearly everything here is
greenfield, so the template plus its CI job is the whole gate; a second mechanism to keep in
sync would cost more than it catches.

## Naming

Rust uses `CHANGEME`, Python uses `changeme`. Both appear in more than one file
(`Cargo.toml` and `tests/it/smoke.rs`; `pyproject.toml`, the package directory, and the test
imports), so rename with a sweep rather than by hand.
