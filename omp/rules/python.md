---
name: python
description: Python standards for IAM work, API clients, automation and client software — uv, pydantic, strict typing, HTTP correctness, secret hygiene, the test floor
globs:
  - "**/*.py"
  - "**/pyproject.toml"
---
# Python

Sourced from `omp/research/PythonCraft.md` — Schlawack, Cannon, Willison, Ronacher,
Hettinger, plus the PEP, `ruff`, `uv`, stdlib and OWASP primaries. Deliberate overrides of
those sources are marked below.

## One assumption: greenfield, full control, modern stack

Every project is new and we control the environment — our own tooling, Bereit engagements,
and enterprise software we maintain long term. So there is exactly one way to do each thing
here. No legacy fallbacks, no "if the client only has pip" branch, no per-project profile to
classify. If a project genuinely cannot use this stack, that is an exception to raise
explicitly, not a branch to guess at.

The audience for readability is **me in two years**, not a stranger who has never seen
Python. Modern idiom is expected; cleverness still is not.

## Tooling — not negotiable

- **`uv` for everything.** Dependency resolution, virtualenvs, Python version pinning
  (`.python-version`), tool execution (`uvx`), lockfiles. Never `pip`, `pip-tools`,
  `poetry`, `conda`, or a hand-managed venv.
- A project is `pyproject.toml` + `uv lock`, with `UV_LOCKED=1` in CI and in any container
  build so a stale lock fails loudly instead of silently resolving something new.
- A single-file script is PEP 723 inline metadata — a `# /// script` header with
  `requires-python` and `dependencies`, `uv lock --script` beside it, and
  `#!/usr/bin/env -S uv run --script` to make it executable. Never rely on the ambient
  interpreter having the imports.
- `ruff` for lint and format. `mypy` for types. `pip-audit` for dependency vulnerabilities.
  Versions pinned so the verdict is identical on every machine.
- Lower bounds in the manifest, exact pins only in the lock. Block a *specific* known-broken
  release (`httpx!=0.28.0`), never a speculative major (`httpx<1`) — a speculative cap
  freezes out security releases and creates unresolvable conflicts in Python's flat package
  space.

## Data modelling — pydantic, with Schlawack's two constraints

pydantic is the single modelling library. API request and response shapes, config, records,
anything with a fixed set of fields. Not `dict`, not `tuple`, not `dataclasses.dataclass`,
not `attrs`. Config via `pydantic-settings`. One library, so there is never a per-file
"which one here" decision to get wrong.

Schlawack argues in `omp/research/PythonCraft.md` that pydantic is a validation and
coercion library, and that modelling domain objects with it means re-validating trusted data
and letting the wire shape apply design pressure to business logic. His objection is
correct, and it is answered by mechanism rather than by a second library:

- **Do not re-validate what you already validated.** `model_validate` at the boundary where
  data arrives untrusted; `model_construct` when reconstructing an object from a store you
  wrote yourself. Validation is a boundary operation, not a constructor.
- **Do not let a wire schema become the domain type.** When the API shape and the shape the
  logic wants actually diverge, define both and convert between them. The divergence is the
  signal that they are two types; a field you carry only to satisfy a remote API does not
  belong on the object your code reasons about.

Note on the source: Schlawack authors `attrs`, so this is a maintainer writing about a rival
library — tier 4 on the hierarchy in the `ai-security-research` skill. That is why the
argument was taken on its merits rather than on authority, and the merits hold in exactly
the two cases above. It also happens that most data here arrives from IdP and vendor APIs as
untrusted input, which is the case he says pydantic is *for*.

Parse at the edge and keep parsed types inward. A `dict` reaching business logic is a bug.

## Typing

`mypy --strict` is the target and the default. Escapes are per-module and written down:
`ignore_missing_imports` for an untyped vendor SDK, never a blanket `# type: ignore` and
never `--strict` switched off wholesale. Enable pydantic's mypy plugin so model fields are
checked rather than trusted.

Annotate every signature and model field. Do not annotate locals the checker already infers.

## HTTP

- `httpx` as the client. It enforces timeouts everywhere by default, which is the behaviour
  we want; `requests` does not and will hang for minutes.
- **Every call carries an explicit timeout anyway** — the default is a floor, not a
  decision. A `(connect, read)` tuple when the two differ. A timeout set once on the client
  covers its calls; say so rather than repeating it.
- Verified against ruff 0.16: **`S113` fires on `requests` only, not on `httpx`** — so on
  our stack this rule has no linter behind it. The `python-silent-failure` interrupt is the
  only enforcement, which is why it exists.
- Retries are opt-in, bounded, backed off, and restricted to idempotent methods. Never wrap
  a non-idempotent identity operation in a retry — you will double-create or double-delete a
  principal.
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
  no longer names the root cause.
- **Secrets never reach a log.** Before logging any object, know it cannot carry a token,
  session identifier, password, connection string, or key — log a stable identifier or a
  hash instead. `log.info("resp=%s", resp.json())` is how a bearer token lands in a log
  aggregator: retained, replicated, searchable by people who were never in scope for that
  credential. No linter catches this one.
- `structlog` for diagnostics: key–value events, JSON to stdout in production, pretty on a
  tty. `print()` only for a tool's actual output, where a human or `jq` consumes stdout.

## Subprocess

`subprocess.run([...], check=True, timeout=N)`. An argv list, never a formatted string with
`shell=True` — in IAM work the interpolated value is a username or a DN, which makes it
attacker-influenced. Without `check=True`, `run` returns normally on failure and the audit
trail lies. If a shell is genuinely required, `shlex.quote()` every interpolated value.

## Other shape decisions

- `click` for CLIs, never `argparse` — `argparse` cannot nest subcommands properly and
  guesses at argument-versus-option, which makes its behaviour unpredictable. *(`typer` is a
  reasonable alternative where its type-hint-driven interface fits; that one is my read, not
  a sourced position.)*
- Never unpickle anything that crossed a trust boundary — a writable cache file is remote
  code execution. JSON, or HMAC-sign the bytes and verify before loading.
- Justify each dependency. Importing one function and compiling a hundred should set off an
  alarm. But the stdlib does run out, and the well-maintained library wins when the problem
  is genuinely hard — say which side of the line this case falls on rather than pretending
  there is a rule.

## Tests

- **Floor: one end-to-end test that invokes the tool the way the user does**, asserting the
  exit code and one real behaviour, so `uv run pytest` in a clean clone proves it works.
  Below that floor, code gets rewritten instead of modified — including by me, later.
- Each test says in one line what it proves — the property being defended, not a restatement
  of the code. Otherwise a year later nobody can tell whether the behaviour or the test is
  wrong, and the test gets deleted.
- Property tests (`hypothesis`) where a real invariant exists: a round trip, or a filter
  that must never widen a permission set. Most automation has no invariant and example tests
  are the honest answer.
- No test scaffolding around exploratory analysis that will not be kept.

## Comments

Comment the traps only: where an obvious future edit breaks something. Not what the code
does — the types carry that.

## Scaffolding a new project

**Copy `omp/templates/python/`. Do not hand-roll the config.** It is verified end to end
against uv 0.12, ruff 0.16, mypy strict and Python 3.14: `uv sync`, `ruff check`,
`ruff format --check`, `mypy src tests` and `pytest` all pass on a fresh copy, and the lint
selection was confirmed to reject a bare `except`, a hardcoded secret, `subprocess.run`
without `check`, and `pickle.loads`. Rename `changeme`, delete what you do not need.

What it carries, so the rules above are enforced by tooling rather than by memory:
`pyproject.toml` with `[build-system]` (without it `uv run pytest` fails with
`ModuleNotFoundError`), a `dev` dependency group, `ruff` selecting `E,F,I,B,S,PL,UP,RUF`,
`mypy` strict with the pydantic plugin, `.python-version`, a CI job running the gate with
`UV_LOCKED=1`, and `src/changeme/client.py` demonstrating cursor-exhausting pagination, an
explicit timeout, and diagnostics on stderr so stdout stays pipeable.

Verified rule-to-lint mapping: `E722` bare-except, `PLW1510` subprocess-without-check,
`S301` pickle, `S105`–`S107` hardcoded secrets, `S607` partial executable path. `B904`
raise-without-from is selected but was not exercised by the probe.
