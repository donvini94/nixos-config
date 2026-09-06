# OMP discovers `claude` as a provider at priority 80 and would read this tree's
# settings, MCP servers and hooks into every session; `claude` is listed in
# `disabledProviders` in omp/config-common.nix to stop that.
{ config, ... }:

let
  repo = "${config.home.homeDirectory}/nixos-config/claude";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file.".claude/CLAUDE.md".source = link "${repo}/CLAUDE.md";

  # ~/.claude is a symlink to ~/Claude, the Syncthing folder id "claude". .stignore is
  # per-device and never itself synced, so a read-only nix-store symlink is fine here.
  home.file.".claude/.stignore".text = ''
    // Whitelist: only paths listed below sync, first match wins, trailing `*` drops
    // the rest. The CLAUDE.md pointer must not sync — Syncthing would fight the symlink.

    !/memory

    *
  '';
}
