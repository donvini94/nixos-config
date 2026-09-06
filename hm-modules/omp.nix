{
  config,
  lib,
  pkgs,
  ...
}:

let
  repo = "${config.home.homeDirectory}/nixos-config/omp";
  # Out-of-store links keep the authored files writable and editable without a rebuild.
  link = config.lib.file.mkOutOfStoreSymlink;

  ruleNames = [
    "rust"
    "python"
    "rust-runtime-hazard"
    "python-silent-failure"
    "isc-rule"
    "isc-rule-divergence"
    # The aisec-* rules are user-scope on purpose: project rule directories are read
    # from the process working directory only, with no ancestor walk, so a project-scoped
    # copy is dropped whenever omp starts in a subdirectory. Their globs are path-gated.
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

  mentorRepo = "${config.home.homeDirectory}/code/omp-mentor";

  lathe = pkgs.callPackage ../packages/lathe.nix { };

  # The skill loader readdirs the skills root and follows symlinked directory entries,
  # so a skill is linked as one directory.
  latheSkills = lib.listToAttrs (
    map (name: {
      name = ".omp/agent/skills/${name}";
      value.source = "${lathe}/share/lathe/skills/${name}";
    }) lathe.skillNames
  );

  # Rules and commands are linked file by file, never as a directory: OMP enumerates
  # <agent-dir>/rules/*.md and commands/*.md with a glob, and a glob does not traverse
  # a symlinked directory — a directory link makes every entry silently invisible.
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
  home.packages = [ lathe ];

  home.file = {
    # Highest-priority user context file; shadows ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md
    # and every other harness's user-scope file.
    ".omp/agent/AGENTS.md".source = link "${repo}/AGENTS.md";
    # Loaded as an always-apply sticky rule re-attached near the current turn; keep it short.
    ".omp/agent/RULES.md".source = link "${repo}/RULES.md";
    # Derived, not authored: the server command is a nix store path, so this is a
    # read-only store file rather than an out-of-store link.
    ".omp/agent/mcp.json".text = builtins.toJSON mcpConfig;
    # A host without the ~/code/omp-mentor checkout gets a dangling link and an OMP
    # startup warning.
    ".omp/agent/skills/mentor".source = link "${mentorRepo}/skills/mentor";
    ".omp/agent/commands/mentor.md".source = link "${mentorRepo}/commands/mentor.md";
  }
  // linkEach "rules" ruleNames
  // linkEach "agents" agentNames
  // latheSkills;
}
