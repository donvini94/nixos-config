# Skills — my own

Self-authored Claude Code skills live here, versioned in `nixos-config`.
This directory is symlinked to `~/.claude/skills` via `hm-modules/claude.nix`
(`mkOutOfStoreSymlink`), so it is **writable** — edit skills live, no rebuild
needed; commit changes to git.

## Add a skill

```
cd ~/.claude/skills            # -> nixos-config/claude/skills
claude plugin init <name>      # scaffolds <name>/SKILL.md
# or hand-author <name>/SKILL.md
```

A skill is a directory with a `SKILL.md` (YAML frontmatter: `name`,
`description`; body = instructions). Keep them small and single-purpose.

Third-party plugins are NOT vendored here — install those via
`claude plugin install <plugin>@<marketplace>`. This directory is for
harness pieces I author and own.
