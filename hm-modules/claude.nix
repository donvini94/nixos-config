# Claude Code harness — retired. OMP is the active harness; see omp.nix.
#
# Only two things remain here:
#   1. ~/.claude/CLAUDE.md — a thin pointer that @-imports nixos-config/omp/AGENTS.md,
#      so a stray Claude Code session gets the same instructions instead of a stale fork.
#   2. ~/.claude/.stignore — ~/.claude/memory/ is still the cross-machine memory store
#      for every harness, and this whitelist is what makes only that directory sync.
#
# Nothing else in ~/.claude reaches OMP any more. OMP treats `claude` as a
# first-class discovery source at priority 80 and would otherwise read that
# tree's settings, MCP servers and hooks into every session, so
# packages/omp-harness.nix lists `claude` in `disabledProviders`. The pointer
# above therefore serves Claude Code only, which is the whole point of it.
#
# NOT managed here (deliberately, machine-specific + high-churn writable state):
#   settings.json, .credentials.json, plugins/, projects/, memory/, session-*,
#   history, caches.
#
# ~/.claude is a symlink to ~/Claude, a Syncthing folder.
{ config, ... }:

let
  repo = "${config.home.homeDirectory}/nixos-config/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  # --- thin pointer into the canonical OMP context (writable symlink into the repo) ---
  home.file.".claude/CLAUDE.md".source = link "${repo}/CLAUDE.md";

  # --- Syncthing ignore rules for ~/.claude (folder id: "claude") ---
  # .stignore is per-device and never itself synced; a read-only nix-store
  # symlink is fine (Claude never writes it).
  home.file.".claude/.stignore".text = ''
    // ===========================================================================
    // Syncthing ignore rules for ~/.claude  (folder id: "claude")
    // WHITELIST model: only paths included below sync; trailing `*` ignores the rest.
    // First match wins, top-to-bottom.  `!` = include, `*` = catch-all ignore.
    //
    // MEMORY-ONLY: only accumulated memory syncs. The authored CLAUDE.md pointer is
    // owned declaratively here in nixos-config and symlinked in, so it must NOT sync
    // (Syncthing would fight the symlink).
    // ===========================================================================

    // accumulated knowledge — the only thing that syncs
    !/memory

    // ignore everything else
    *
  '';
}
