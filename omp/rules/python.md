---
name: python
description: Python standards for IAM work, API clients, automation and client handover — five delivery profiles, HTTP correctness, secret hygiene, tiered typing, the handover test floor
globs:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
---
# Python

Sourced from `omp/research/PythonCraft.md` — Schlawack, Cannon, Willison, Ronacher,
Hettinger, plus the PEP, `ruff`, `uv`, stdlib and OWASP primaries. This is IAM
engineering, API clients, scripting and automation — not a data-science brief.

## Decide the profile first

The reproducibility rules invert between profiles, so name the profile before writing code.

1. **Mine, ad hoc** — a single file I run. `uv` and current tooling assumed.
2. **Handover repo** — the client runs and maintains it. **Assume system Python and pip at
   best.** No `uv`, no build step, no tooling I cannot expect to survive my departure.
3. **Container service** — I or they deploy it. Full `uv` chain, lock verified in the build.
4. **Inside their platform** — their runtime, their Python version, their dependency
   policy. Compatibility and defensive coding apply; reproducibility rules mostly do not.
5. **Throwaway analysis** — not handed over. Exempt from everything below except the
   secret-hygiene and pagination rules, which are about damage, not craft.

## Reproducibility

- **Profile 1:** PEP 723 inline metadata — a `# /// script` header with `requires-python`
  and `dependencies`, `uv lock --script` beside it, and
  `#!/usr/bin/env -S uv run --script` to make it executable. Never rely on the ambient
  interpreter having the imports.
- **Profiles 2 and 4:** `requirements.txt` with hashes, stdlib-first, no build step. Every
  non-stdlib dependency has to answer "can their admin reinstall this in three years".
- **Profile 3:** `pyproject.toml` plus `uv lock`, with `UV_LOCKED=1` in the build so a
  stale lock fails the build rather than silently resolving something new.
- Lower bounds in the manifest, exact pins only in the lock. Block a *specific* known-broken
  release (`flask!=1.1.2`), never a speculative major (`flask<2`). The client cannot remove
  your pin, so a speculative cap freezes them out of security releases and creates
  unresolvable conflicts in Python's flat package space.

## HTTP

- **Every call carries an explicit timeout.** `requests` has none by default and will hang
  for minutes; a scheduled job then holds its slot until someone notices at audit time. Use
  a `(connect, read)` tuple when the two differ. A timeout set once on a `Session` or
  `httpx.Client` covers its calls — say so rather than repeating it.
- Retries are opt-in, bounded, backed off, and restricted to idempotent methods. `requests`
  does not retry by default; `urllib3.Retry` disables backoff by default and excludes
  `POST`/`PATCH` on purpose. Never wrap a non-idempotent identity operation in a retry —
  you will double-create or double-delete a principal.
- **Pagination is correctness, not polish.** Follow the server's own cursor (`Link:
  rel="next"`, `nextPageToken`, `@odata.nextLink`) to exhaustion. A collection endpoint
  returns page one *with no error* — GitHub returns 30 issues from a repo with 1600 open,
  and silently clamps an over-large `per_page`. A deprovisioning or entitlement-diff script
  that reads page one reports "no orphaned accounts" because it never looked.

## Errors and logging

- Never bare `except:` — it catches `KeyboardInterrupt` and `SystemExit`, so the operator
  cannot Ctrl-C the job, and it disguises real failures. `except Exception:` only at a
  deliberate top-level boundary.
- Always `raise NewError(...) from exc` when re-raising inside a handler (`from None` when
  hiding the cause is deliberate). Without `from`, `__cause__` is unset and the traceback
  the client sends you no longer names the root cause.
- **Secrets never reach a log.** Before logging any object, know that it cannot carry a
  token, session identifier, password, connection string, or key — log a stable identifier
  or a hash instead. `log.info("resp=%s", resp.json())` is how a bearer token lands in the
  client's log aggregator: retained, replicated, and searchable by people who were never in
  scope for that credential. No linter catches this one.
- `print()` for the tool's actual output, a named logger (`logging.getLogger(__name__)`)
  for diagnostics. Structured JSON to stdout only once a machine reads the logs — profile 3.

## Subprocess

`subprocess.run([...], check=True, timeout=N)`. An argv list, never a formatted string with
`shell=True` — in IAM work the interpolated value is a username or a DN, which makes it
attacker-influenced. Without `check=True`, `run` returns normally on failure and the audit
trail lies. If a shell is genuinely required, `shlex.quote()` every interpolated value.

## Data and shape

- A fixed, known set of keys is an object, not a dict. `@dataclass` from the stdlib for
  records — `customer[2]` and `d["frist_name"]` are bugs a class turns into an
  `AttributeError` at the mistake.
- `pydantic` only at a boundary where untrusted input is parsed, and it does not leak
  inward. Re-validating trusted data on every read, and letting the API shape apply design
  pressure to domain objects, are both costs with no return. On profiles 2 and 4 the
  zero-dependency answer wins outright.
- Never unpickle anything that crossed a trust boundary — a writable cache file is remote
  code execution. JSON, or HMAC-sign the bytes and verify before loading.
- `argparse` on profiles 2 and 4: zero install, any maintainer can read it. `click` when I
  own the environment and genuinely need subcommands or composition.

## Typing, tiered by profile

- **Profiles 1 and 5:** annotate function signatures and dataclass fields; run mypy with
  `check_untyped_defs` and `warn_unused_ignores`. Do not annotate locals the checker infers.
- **Profiles 2 and 3:** add `disallow_untyped_defs`, `warn_return_any`, `strict_equality`.
- **Never `--strict` on glue code calling untyped vendor SDKs.** It produces a wall of
  `import-untyped` and a habit of blanket `# type: ignore`, which is worse than no checking.
  Per-module `ignore_missing_imports` instead. mypy's own docs frame strict as a goal for a
  codebase, not a starting position.

## Tests

- **The floor for anything handed over: one end-to-end test that invokes the tool the way
  the user does**, asserting the exit code and one real behaviour, so `pytest` in a clean
  clone proves it works. The purpose is not coverage — it is that the client's maintainer
  can change the code and know they did not break it. Below that floor, handover code gets
  rewritten instead of modified.
- Each test says in one line what it proves — the property being defended, not a
  restatement of the code. Otherwise a year later nobody can tell whether the behaviour or
  the test is wrong, and the test gets deleted.
- Property tests only where a real invariant exists: a round trip, or a filter that must
  never widen a permission set. For most 200-line automation there is no invariant and
  example tests are the honest answer.

## Dependencies

Justify each one. Importing a single function and compiling a hundred should set off an
alarm, and the client inherits the treadmill — Dependabot noise, transitive CVEs, a build
that stops resolving. But the stdlib does run out: reach for the well-maintained library
when the problem is genuinely hard (`httpx`, `click`, `structlog` in their places above),
and say which side of the line this case falls on rather than pretending there is a rule.

## Comments

Comment the traps only: where an obvious future edit breaks something. Not what the code
does.

## Scaffolding a new project

- **Profile 1:** the PEP 723 header and nothing else.
- **Profiles 2 and 3:** `pyproject.toml` with a `[build-system]` section (without it
  `uv run pytest` fails with `ModuleNotFoundError` because the project is never installed),
  a `dev` dependency group holding `pytest`, and `ruff` plus mypy config in the same file.
  One CI job running ruff, the type checker, pytest and `pip-audit`, with tool versions
  pinned so the verdict is the same on every machine.
- `ruff` selections that carry the rules above mechanically: `S113` request-without-timeout,
  `E722` bare-except, `B904` raise-without-from, `PLW1510` subprocess-without-check, `S301`
  pickle, `S105`–`S107` hardcoded secrets. Enable at least `E,F,I,B,S,PL`.
