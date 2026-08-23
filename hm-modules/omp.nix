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
# rules/*.md are per-language guardrails. Two kinds: rulebook rules (globs + description,
# read on demand via rule://<name>) and TTSR rules (condition + scope, fired mid-stream
# when a pattern is written into a matching file). Symlinked FILE BY FILE, not as a
# directory: OMP enumerates <agent-dir>/rules/*.md with a glob, and a glob does not
# traverse a symlinked directory — a directory link makes every rule silently invisible.
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

  home.file.".omp/agent/rules/rust.md".source = link "${repo}/rules/rust.md";
  home.file.".omp/agent/rules/python.md".source = link "${repo}/rules/python.md";
  home.file.".omp/agent/rules/rust-runtime-hazard.md".source =
    link "${repo}/rules/rust-runtime-hazard.md";
  home.file.".omp/agent/rules/python-silent-failure.md".source =
    link "${repo}/rules/python-silent-failure.md";
  home.file.".omp/agent/rules/isc-rule.md".source = link "${repo}/rules/isc-rule.md";
  home.file.".omp/agent/rules/isc-rule-divergence.md".source =
    link "${repo}/rules/isc-rule-divergence.md";
}
