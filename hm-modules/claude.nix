# Claude Code harness — authored, owned, and versioned in this repo.
#
# Design (mirrors doom.nix): the authored config lives in nixos-config/claude/
# and is symlinked into ~/.claude via mkOutOfStoreSymlink, so every piece stays
# WRITABLE and editable in place (no rebuild per edit) while being git-tracked.
#
# NOT managed here (deliberately, machine-specific + high-churn writable state):
#   settings.json, .credentials.json, plugins/, projects/, memory/, session-*,
#   history, caches. Plugins are installed per-machine via `claude plugin install`.
#
# ~/.claude is a symlink to ~/Claude, a Syncthing folder. Only memory/ syncs
# (see .stignore below); everything authored is owned here instead of synced.
{ config, ... }:

let
  repo = "${config.home.homeDirectory}/nixos-config/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  # --- authored harness (writable symlinks into the repo working tree) ---
  home.file.".claude/CLAUDE.md".source = link "${repo}/CLAUDE.md";
  home.file.".claude/RTK.md".source = link "${repo}/RTK.md";
  home.file.".claude/rules".source = link "${repo}/rules";
  home.file.".claude/skills".source = link "${repo}/skills";
  home.file.".claude/agents".source = link "${repo}/agents";
  home.file.".claude/hooks/rtk-rewrite.sh".source = link "${repo}/hooks/rtk-rewrite.sh";

  # --- Syncthing ignore rules for ~/.claude (folder id: "claude") ---
  # .stignore is per-device and never itself synced; a read-only nix-store
  # symlink is fine (Claude never writes it).
  home.file.".claude/.stignore".text = ''
    // ===========================================================================
    // Syncthing ignore rules for ~/.claude  (folder id: "claude")
    // WHITELIST model: only paths included below sync; trailing `*` ignores the rest.
    // First match wins, top-to-bottom.  `!` = include, `*` = catch-all ignore.
    //
    // MEMORY-ONLY: only accumulated memory syncs. Everything else (CLAUDE.md,
    // RTK.md, rules/, agents/, skills/) is owned declaratively here in nixos-config
    // and symlinked in, so it must NOT sync (Syncthing would fight the symlinks).
    // ===========================================================================

    // accumulated knowledge — the only thing that syncs
    !/memory

    // ignore everything else
    *
  '';
}
