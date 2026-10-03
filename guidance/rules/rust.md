---
name: rust
description: Rust defaults and guardrails for explicit invariants, useful errors and bounded concurrent work
globs:
  - "**/*.rs"
  - "**/Cargo.toml"
---
# Rust

Apply these defaults to new work; respect existing project constraints.

## Design and errors

- Use the project's formatter and Clippy gates. Keep lint configuration in the manifest;
  justify narrow exceptions rather than disabling whole groups to silence a warning.
- Use types to prevent realistic unit, state or argument-order mistakes. Introduce newtypes,
  enums and traits when they improve the contract; do not wrap every primitive reflexively.
- Keep fields private where an invariant depends on controlled construction or mutation.
  Design public compatibility guarantees only where callers actually need them.
- Give callers structured errors when they must distinguish failures. At application
  boundaries, attach context about the operation while preserving the underlying cause.
  `thiserror` and `anyhow` are useful defaults, not mandatory dependencies for every crate.
- Handle expected failures with `Result`. Reserve panics for genuine invariants, with an
  explanatory `expect` message. Tests may use `unwrap`; external input is not an invariant.
- Keep credentials out of logs and error context. Redact secret-bearing debug representations.
  Use structured diagnostics when the service needs correlation or machine consumption.

## Async and concurrency

- Keep blocking I/O and sustained CPU work off async executor threads. Use bounded worker
  pools or dedicated threads appropriate to the workload; do not spawn unlimited work.
- Bound queues and concurrency. Decide what happens at capacity: backpressure, rejection
  or deliberate dropping. An actor is an option for owned state, not a required architecture.
- Define cancellation, shutdown and task-failure handling. Observe task results where failure
  matters; detached tasks must not silently hide lost work.
- Review locks held across awaits, shared-state invariants and ordering requirements.
  Compiler acceptance does not establish freedom from deadlocks or race conditions.

## Safety and verification

- Prefer safe APIs. Any necessary unsafe code needs documented safety invariants and caller
  obligations, kept to a small reviewable boundary. Use Miri for supported unsafe tests and
  concurrency-testing tools when implementing synchronization primitives.
- Test observable behavior and important failure paths. Choose test layout for the project;
  do not mandate one integration binary or disable useful doctests by default.
- Preserve regression cases, including minimized failures from property tests.
- Profile before adding performance complexity. Prefer algorithm and data-structure changes;
  justify low-level optimizations with measurements relevant to the workload.
