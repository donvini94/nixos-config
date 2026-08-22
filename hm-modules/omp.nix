# OMP harness — authored, owned, and versioned in this repo.
#
# Design (mirrors doom.nix and the retired claude.nix): the authored context lives in
# nixos-config/omp/ and is symlinked into ~/.omp/agent via mkOutOfStoreSymlink, so both
# files stay WRITABLE and editable in place (no rebuild per edit) while being git-tracked.
#
# AGENTS.md is the single user-scope context file for every harness. OMP's native provider
# has the highest discovery priority, so this file shadows ~/.claude/CLAUDE.md,
# ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md and friends — exactly one user context file ever
# survives discovery.
#
# RULES.md is loaded as an always-apply sticky rule, re-attached near the current turn, so
# it keeps its hold after a long conversation has pushed the opening context out of view.
# Keep it short; long background belongs in AGENTS.md, where it costs budget only once.
#
# NOT managed here (machine-specific + high-churn writable state):
#   config.yml, models.yml (see ai-clients.nix), agent.db, history.db, sessions/, logs/.
{ config, ... }:

let
  repo = "${config.home.homeDirectory}/nixos-config/omp";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file.".omp/agent/AGENTS.md".source = link "${repo}/AGENTS.md";
  home.file.".omp/agent/RULES.md".source = link "${repo}/RULES.md";
}
