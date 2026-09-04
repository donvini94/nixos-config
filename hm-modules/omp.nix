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
# when a pattern is written into a matching file).
#
# agents/*.md are task agents: a separate session in a subprocess with its own context, so
# they can judge work from OUTSIDE the dispatching session. See omp/agents-design.org for
# why these three and not others.
#
# Both directories are symlinked FILE BY FILE, not as a directory: OMP enumerates
# <agent-dir>/rules/*.md with a glob, and a glob does not traverse a symlinked directory —
# a directory link makes every rule silently invisible. Agents are loaded with readdir and
# would tolerate a directory link, but one pattern in this module beats two.
#
# USER SCOPE IS DELIBERATE for the aisec-* rules. They previously lived in
# ~/org/.omp/rules/, and project rule directories are read from the process working
# directory ONLY — no ancestor walk — while .omp/AGENTS.md *does* walk up. Launching omp
# from ~/org/roam/main therefore loaded the org context but silently dropped all four
# guardrails, verified with `omp ttsr` (34 rules from ~/org, 30 from ~/org/roam/main).
# Their scope globs are already path-gated, so user scope costs nothing elsewhere.
#
# mcp.json is DERIVED, not authored, so it is a read-only store file rather than an
# out-of-store link: the server command is a nix store path. The Atlassian server that
# used to arrive via ~/.claude was retired with Claude Code; `disabledProviders` in
# packages/omp-harness.nix now stops that source being read at all, so anything still
# wanted has to be declared here.
#
# NOT managed here (machine-specific + high-churn writable state):
#   config.yml, models.yml (see ai-clients.nix), agent.db, history.db, sessions/, logs/.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  repo = "${config.home.homeDirectory}/nixos-config/omp";
  link = config.lib.file.mkOutOfStoreSymlink;

  ruleNames = [
    "rust"
    "python"
    "rust-runtime-hazard"
    "python-silent-failure"
    "isc-rule"
    "isc-rule-divergence"
    "aisec-generated-region"
    "aisec-prose"
    "aisec-ratification"
    "aisec-zero-vs-dash"
  ];

  agentNames = [
    "slop"
    "intent-check"
    "evidence-check"
  ];

  linkEach =
    subdir: names:
    lib.listToAttrs (
      map (name: {
        name = ".omp/agent/${subdir}/${name}.md";
        value.source = link "${repo}/${subdir}/${name}.md";
      }) names
    );

  mcpConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
    mcpServers.nixos = {
      type = "stdio";
      command = lib.getExe pkgs.mcp-nixos;
      args = [ ];
    };
  };
in
{
  home.file = {
    ".omp/agent/AGENTS.md".source = link "${repo}/AGENTS.md";
    ".omp/agent/RULES.md".source = link "${repo}/RULES.md";
    ".omp/agent/mcp.json".text = builtins.toJSON mcpConfig;
  }
  // linkEach "rules" ruleNames
  // linkEach "agents" agentNames;
}
