# Shared OMP context bridge for Pi

The authoritative shared guidance remains in `~/nixos-config/omp/`. Read it; do not copy
or rewrite it here.

## Every task

1. Read `~/nixos-config/omp/AGENTS.md` and `~/nixos-config/omp/RULES.md` before acting.
2. The OMP URI forms map to real Pi-readable paths:
   - `rule://NAME` → `~/nixos-config/omp/rules/NAME.md`
   - `skill://NAME` → first inspect `~/.agents/skills/NAME/SKILL.md`; shared managed skills
     are in `~/.omp/agent/managed-skills/NAME/SKILL.md`, and linked OMP-only skills are in
     `~/.omp/agent/skills/NAME/SKILL.md`.
   - `agent://ID` is OMP-specific. Pi subagents return through HazAT's `subagent` tools and
     their Pi session files; do not pretend those are OMP agent URIs.
   - `xd://…` is OMP-specific. Use Pi's built-in tools or the configured MCP tools instead.
3. Pi's native MCP names are `mcp__<server>__<tool>`. The existing unauthenticated Exa
   service is `mcp__exa__web_search_exa`; use it for web research. `mcp__nixos__…` and
   `mcp__linear__…` provide Nix and Linear. Log into Linear through Pi's own OAuth flow.

## Topic and path rules

The rule files under `~/nixos-config/omp/rules/` remain canonical and are loaded on demand:

- Rust source or `Cargo.toml`: `rust.md`; runtime/async hazard: `rust-runtime-hazard.md`.
- Python or `pyproject.toml`: `python.md`; silent failure/error handling: `python-silent-failure.md`.
- SailPoint ISC rule paths: `isc-rule.md`, then `isc-rule-divergence.md` when applicable.
- AISec or AI-security research: `aisec-session.md`, then the named supporting rule(s) it
  directs you to. Do not apply AISec prose rules to unrelated Markdown or Org work.

Before work in a project, look for that project's `.omp/AGENTS.md` and `.omp/rules/` from the
working directory upward. Read only the project context and rules relevant to the current task
or affected paths. Do not import project context into global Pi instructions, another project,
or Pi memory.

## Skills and learning

Pi auto-discovers `~/.agents/skills/`, which is the shared editable source for the personal
Rust, Python, ISC, AISec, Lathe and related skills. The Pi settings add the OMP-managed
`calendar-to-org-agenda` and `meeting-minutes` skills plus `zotero-cli`. The mentor skill is
also linked exactly at `~/.pi/agent/skills/mentor/SKILL.md`; invoke it only through the
opt-in mentor prompt/command protocol.

The `~/code/omp-mentor`, `~/code/omp-prompt-snippets`, and `~/code/omp-learn` Pi packages are
local paths. Their source repositories are authoritative and editable; do not copy their
skills, prompts, or extensions into Pi's agent directory. Pi agents `researcher`,
`mermaid-maker`, and `svg-maker` are live links into `~/code/omp-learn/agents/` so the HazAT
subagent package can use the same resource grants and learning boundaries.

## Pi-owned memory

Pi's private curated memory is `~/.pi/agent/memory/curated-global.md`, described by
`~/.pi/agent/memory/manifest.md`. It is not injected automatically: read it only when a task
needs a durable personal preference or learning context. Pi may write concise, dated notes
only under `~/.pi/agent/memory/notes/`. Never read, import, mutate, or synchronize OMP/Codex
memory databases, project banks, sessions, or transcripts.

## Pi-specific boundaries

- Pi provider and MCP credentials belong only in `~/.pi/agent/auth.json` and
  `~/.pi/agent/mcp-auth.json`; sign in independently from OMP and never copy refresh tokens.
- The Requesty/local endpoints use `X-AI-Caller: pi`. They deliberately carry no client
  credential in Pi configuration.
- The HazAT subagent extension is explicitly run through Zellij by the Pi shell function.
- The external editor is `emacsclient -c -a emacs`, which uses the existing Emacs server or
  starts Emacs when no server is available.
