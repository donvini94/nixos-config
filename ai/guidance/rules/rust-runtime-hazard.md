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
Review the matched code in context; a regex match is a reminder, not proof of a defect.

- **Unbounded queue:** what bounds memory growth, and what happens when the consumer falls
  behind? Prefer explicit capacity and backpressure.
- **Blocking operation:** does it run on an async executor thread? If so, move sustained
  blocking work to appropriate bounded workers. Synchronous CLI code may use blocking APIs.
- **Unsafe:** is it necessary, permitted by the project and backed by documented safety
  invariants and suitable tests? Do not remove a safety gate just to make code compile.

The full requirements live in `rust.md`. Check the actual execution context before changing
working code.
