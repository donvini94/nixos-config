# Agents — my own

Self-authored Claude Code subagents live here, versioned in `nixos-config`.
Symlinked to `~/.claude/agents` via `hm-modules/claude.nix` — writable, no
rebuild needed to add or edit one.

## Add an agent

Create `<name>.md` with YAML frontmatter:

```markdown
---
name: my-agent
description: When this agent should be used (be specific — this drives auto-delegation).
tools: Read, Grep, Glob        # optional; omit to inherit all tools
---

System prompt for the agent goes here.
```

Start from scratch and add agents only when a real, recurring task justifies
one. Prefer a few sharp agents over a broad grab-bag.
