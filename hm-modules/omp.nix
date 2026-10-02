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
    # Scope research rules through their globs, not the working directory.
    "aisec-generated-region"
    "aisec-session"
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
    mcpServers = {
      nixos = {
        type = "stdio";
        command = lib.getExe pkgs.mcp-nixos;
        args = [ ];
      };
      # OMP owns the interactive OAuth login and token storage.
      linear = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
    };
  };
in
{
  home.packages = [ lathe ];

  home.file = {
    ".omp/agent/AGENTS.md".source = link "${repo}/AGENTS.md";
    ".omp/agent/RULES.md".source = link "${repo}/RULES.md";
    ".omp/agent/mcp.json".text = builtins.toJSON mcpConfig;
    # A host without the ~/code/omp-mentor checkout gets a dangling link and an OMP
    # startup warning.
    ".omp/agent/skills/mentor".source = link "${mentorRepo}/skills/mentor";
    ".omp/agent/commands/mentor.md".source = link "${mentorRepo}/commands/mentor.md";
  }
  // linkEach "rules" ruleNames
  // linkEach "agents" agentNames;

  # OMP owns plugin state; bootstrap missing plugins without failing offline activation.
  home.activation.ompLearningPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="$HOME/.bun/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
    if [ -z "''${DRY_RUN:-}" ] && command -v omp >/dev/null 2>&1; then
      if ! omp plugin list 2>/dev/null | grep -q 'omp-learn-org@omp-learn'; then
        omp plugin marketplace add donvini94/omp-learn >/dev/null 2>&1 || true
        omp plugin install omp-learn-org@omp-learn \
          || echo "ompLearningPlugin: installing omp-learn-org failed (offline?)" >&2
      fi
    fi
  '';
}
