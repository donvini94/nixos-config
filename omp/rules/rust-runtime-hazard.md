---
name: rust-runtime-hazard
description: Rust patterns that only fail under load or in production — unbounded channel, blocking call in async, unsafe in a crate that should forbid it
condition:
  - "unbounded_channel\\s*\\(|mpsc::unbounded\\s*\\("
  - "std::thread::sleep|reqwest::blocking|std::fs::(read|write|copy|File::)"
  - "\\bunsafe\\s*\\{|\\bunsafe\\s+(fn|impl|trait)\\b"
scope:
  - "tool:edit(**/*.rs)"
  - "tool:write(**/*.rs)"
---
Stop and check which of these you just wrote. None of them fail in local testing.

**Unbounded channel.** Unbounded memory growth with no backpressure — the producer never
learns that the consumer is behind, and the process dies under load with an OOM that never
reproduces in development. Use a bounded channel and decide, explicitly, what happens when
it is full.

**A blocking call.** If this file has async in it, `std::thread::sleep`, `reqwest::blocking`
and synchronous `std::fs` starve the runtime: the multi-threaded scheduler has one thread
per core, which is few enough to exhaust in production and many enough to hide the problem
locally. Sync I/O goes to `spawn_blocking`, CPU work to `rayon` bridged with a `oneshot`, a
never-ending loop to a dedicated `std::thread` — and note that a loop parked on
`spawn_blocking` removes that thread from the pool permanently. In a synchronous CLI these
calls are fine; continue.

**`unsafe`.** These crates carry `#![forbid(unsafe_code)]`, so writing `unsafe` means either
the attribute has to go — with the reason recorded in the commit — or the design needs to
change. If it stays: one operation per `unsafe` block, a `// SAFETY:` comment naming the
invariant that discharges the obligation, a `# Safety` doc section on any `unsafe fn`
stating what the caller must uphold, and `cargo miri test` added to CI. Writing the
justification is itself the bug-finding step.
