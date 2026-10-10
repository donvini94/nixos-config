{
  config,
  lib,
  pkgs,
  ...
}:

let
  repo = "${config.home.aiStack.checkout}/omp";
  # Out-of-store links keep the authored files writable and editable without a rebuild.
  link = config.lib.file.mkOutOfStoreSymlink;

  ruleNames = [
    "rust"
    "python"
    "rust-runtime-hazard"
    "python-silent-failure"
    "isc-rule"
    "isc-rule-divergence"
    "aisec-prose"
  ];

  agentNames = [
    "slop"
    "intent-check"
    "evidence-check"
  ];

  mentorRepo = "${config.home.homeDirectory}/.local/share/agent-content/mentor";
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  managed = (pkgs.formats.yaml { }).generate "omp-managed-config.yml" (
    import ../omp/config-common.nix
  );
  macClient = pkgs.writeShellScriptBin "omp" ''
    export PI_CONFIG_FILES=${managed}
    exec "$HOME/.bun/bin/omp" "$@"
  '';

  lathe = pkgs.callPackage ../packages/lathe.nix { };
  nativeRuntime = pkgs.callPackage ../packages/omp.nix { };

  # Rules and commands are linked file by file, never as a directory: OMP enumerates
  # <agent-dir>/rules/*.md and commands/*.md with a glob, and a glob does not traverse
  # a symlinked directory — a directory link makes every entry silently invisible.
  linkEach =
    subdir: names: sourceDir:
    lib.listToAttrs (
      map (name: {
        name = ".omp/agent/${subdir}/${name}.md";
        value.source = link "${sourceDir}/${name}.md";
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
  imports = [
    ./agent-content.nix
    ./checkout.nix
    ./omp-clients.nix
  ];
  options.programs.ompClient.enable = lib.mkEnableOption "OMP client";

  config = lib.mkIf config.programs.ompClient.enable {
    home.agentContent.enable = true;
    home.packages = [ lathe ] ++ lib.optional isDarwin macClient;
    programs.fish.functions.omp = lib.mkIf isDarwin {
      body = "command ${macClient}/bin/omp $argv";
    };

    home.file = {
      ".omp/agent/AGENTS.md".source = link "${config.home.aiStack.checkout}/guidance/AGENTS.md";
      ".omp/agent/RULES.md".source = link "${config.home.aiStack.checkout}/guidance/RULES.md";
      ".omp/agent/mcp.json".text = builtins.toJSON mcpConfig;
      ".omp/agent/skills/mentor".source = link "${mentorRepo}/skills/mentor";
      ".omp/agent/commands/mentor.md".source = link "${mentorRepo}/commands/mentor.md";
      ".omp/agent/extensions/prompt-snippets".source =
        link "${config.home.homeDirectory}/.local/share/agent-content/prompt-snippets";
    }
    // linkEach "rules" ruleNames "${config.home.aiStack.checkout}/guidance/rules"
    // linkEach "agents" agentNames "${repo}/agents"
    // lib.listToAttrs (
      map
        (name: {
          name = ".omp/agent/managed-skills/${name}";
          value.source = link "${config.home.aiStack.checkout}/skills/managed/${name}";
        })
        [
          "calendar-to-org-agenda"
          "meeting-minutes"
        ]
    );

    # Refresh the native stable release; no activation can reinstall an old Nix-pinned binary.
    # The updater verifies the new release through PATH, where bun installs it (~/.bun/bin).
    home.activation.ompNativeUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="$HOME/.bun/bin:$PATH"
      if [ -z "''${DRY_RUN:-}" ]; then
        ${lib.getExe nativeRuntime} update --stable \
          || echo "ompNativeUpdate: updating OMP failed (offline?)" >&2
      fi
    '';

    # OMP owns plugin state; bootstrap missing plugins without failing offline activation.
    home.activation.ompLearningPlugin = lib.hm.dag.entryAfter [ "writeBoundary" "ompNativeUpdate" ] ''
      export PATH="$HOME/.bun/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH"
      if [ -z "''${DRY_RUN:-}" ] && command -v omp >/dev/null 2>&1; then
        if ! omp plugin list 2>/dev/null | grep -q 'omp-learn-org@omp-learn'; then
          omp plugin marketplace add donvini94/omp-learn >/dev/null 2>&1 || true
          omp plugin install omp-learn-org@omp-learn \
            || echo "ompLearningPlugin: installing omp-learn-org failed (offline?)" >&2
        fi
      fi
    '';
  };
}
