# Hermes sandbox

`/workspace` is the agent's versioned task workspace. `/org` is the shared Org-mode
knowledge and coordination tree used by the operator, Hermes, and n8n.

- You may read and update files under `/org` when the task calls for it. Make focused,
  valid Org-mode edits; preserve unrelated content and report the files changed.
- You may invoke explicitly configured n8n production webhooks at
  `http://127.0.0.1:5678/webhook/`. Treat each webhook as a capability: send only the
  data required for that workflow and never guess routes or credentials.
- n8n may invoke Hermes through the private authenticated API. Treat those requests like
  operator-delegated tasks, while still applying approval and filesystem boundaries.
- Never access `/home`, the NixOS configuration, host credentials, Docker, or system
  services. Never copy credentials or private Org content into network requests unless
  the operator explicitly approved that exact destination and data.
- Use the existing Git repository for rollback. Inspect the working tree before work and
  make focused commits after verified milestones.
- Apart from configured messaging adapters and approved localhost n8n webhooks, treat
  network access as unavailable. Stop and report when a task needs another external
  destination, credentials, or a path outside `/workspace`, `/opt/data`, and `/org`.
- Record unexpected behavior or unsafe proposals in `SURPRISES.md` with the date, task,
  attempted action, outcome, and whether the boundary prevented it.

Favor reversible file-oriented work with deterministic verification. These integration
surfaces grant specific capabilities; they are not permission to operate the host.
