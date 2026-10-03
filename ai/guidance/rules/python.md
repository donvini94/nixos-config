---
name: python
description: Python defaults and guardrails for reproducible tools, typed boundaries and visible failures
globs:
  - "**/*.py"
  - "**/pyproject.toml"
---
# Python

Apply these defaults to new work; respect existing project constraints.

## Tools and data

- Use `uv` for environments, dependencies and execution, `ruff` for linting and formatting,
  and `ty` for type checking. Keep tool versions in project configuration, not instructions.
- Declare dependencies and commit the appropriate lockfile. Build and deploy with a locked
  environment. For standalone scripts, use inline dependency metadata when needed; do not
  depend on incidental packages in the ambient interpreter.
- Annotate function boundaries and record fields. Let the checker infer obvious locals.
  Keep typing escapes narrow and justified; do not hide errors with blanket ignores.
- Use named types for fixed-shape records. Stdlib dataclasses are sufficient for ordinary
  internal data; use a validation library when untrusted inputs need parsing or validation.
  Separate wire and domain types when their requirements actually differ.
- Use the simplest suitable CLI and logging facilities. Add a framework only when its
  capabilities justify the dependency. CLI results go to stdout; diagnostics go to stderr.

## I/O and failure handling

- Set appropriate network timeouts, on the client or call. Distinguish per-operation
  timeouts from a deadline for the whole job when total runtime must be bounded.
- When an operation requires a complete collection, consume all pages using the API's
  documented continuation mechanism. Do not turn a failed page into an empty result.
- Retry only when duplicate execution is safe or the API provides an idempotency mechanism.
  Bound attempts, use backoff and respect server throttling instructions.
- Catch exceptions narrowly. Use broad handling only at a deliberate boundary that reports
  failure. Preserve causes when translating exceptions; do not swallow cancellation or exit.
- Pass subprocess arguments as a list and check exit status. Bound runtime where needed.
  Avoid shells for untrusted values; handle any unavoidable shell syntax explicitly.
- Do not deserialize untrusted data with `pickle` or other executable formats.
- Never dump credentials, request headers or potentially secret-bearing payloads into logs.
  Log safe identifiers and useful context instead.

## Tests

Test meaningful behavior and failure paths. For a maintained CLI, include a test that
invokes its real entry point and checks both output and exit status. Exercise pagination,
partial failures and retry safety when those are part of the tool's contract. Use property
tests where a genuine invariant benefits from them; avoid scaffolding for disposable analysis.
