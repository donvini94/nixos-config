{ ... }:
{
  # ~/.claude is a Syncthing folder shared Mac <-> dracula. .stignore is per-device
  # and never itself synced, so each machine needs its own copy. Claude never writes
  # to .stignore, so a read-only nix-store symlink is fine here (unlike settings.json
  # or memory/, which must stay writable and are deliberately NOT nix-managed).
  home.file.".claude/.stignore".text = ''
    // ===========================================================================
    // Syncthing ignore rules for ~/.claude  (folder id: "claude")
    // WHITELIST model: only paths included below sync; trailing `*` ignores the rest.
    // First match wins, top-to-bottom.  `!` = include, `*` = catch-all ignore.
    // Add `!/new-dir` ABOVE the final `*` to start syncing something new.
    // settings.json is deliberately NOT synced (machine-specific paths + high churn).
    // ===========================================================================

    // accumulated knowledge — the main reason to sync
    !/memory

    // authored global config / instructions
    !/CLAUDE.md
    !/RTK.md
    !/AGENTS.md
    !/the-security-guide.md
    !/rules

    // custom capabilities
    !/agents
    !/commands
    !/skills

    // ignore everything else (projects/, plugins/, *.log, history.jsonl, caches,
    // .credentials.json, settings.json, session-*, tasks, file-history, conflicts)
    *
  '';
}
