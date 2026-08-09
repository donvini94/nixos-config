# Hermes sandbox

This repository is the only task workspace available to the autonomous worker. Keep all
task inputs, generated artifacts, and reversible changes inside this repository.

- Never attempt to access `/home`, the NixOS configuration, host credentials, Docker, or
  system services.
- Use the existing Git repository for rollback. Inspect the working tree before work and
  make focused commits after verified milestones.
- Treat network access as unavailable. The local model endpoint is infrastructure, not a
  tool for shell commands.
- Stop and report when a task requires credentials, external communication, or a path
  outside this workspace.
- Record unexpected behavior or unsafe proposals in `SURPRISES.md` with the date, task,
  attempted action, outcome, and whether the boundary prevented it.

The initial experiment should favor reversible file-oriented work with deterministic
verification. This is a learning sandbox, not permission to operate the host.
