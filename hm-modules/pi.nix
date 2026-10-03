{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  agentDir = "${home}/.pi/agent";
  repo = "${home}/nixos-config";
  link = config.lib.file.mkOutOfStoreSymlink;
  requesty = import ../lib/requesty.nix;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  isDracula = !isDarwin && (osConfig.networking.hostName or "") == "dracula";
  requestyKeyFile = if isDarwin then null else osConfig.services.requesty.apiKeyFile or null;

  # npm installs the pinned binary into the writable ~/.local prefix.
  piVersion = "1.0.0";

  upstreamRevision = "f82da563ab05d66729492d64c7ed4e96db3663f3";
  upstream =
    path: hash:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/amosblomqvist/pi-config/${upstreamRevision}/${path}";
      inherit hash;
    };
  amosAskUserQuestion = upstream "extensions/ask-user-question.ts" "sha256-Yrw+3fkZtAtguaVdKyYu6513thVYrGmlidvE3r92hkU=";
  amosWebFetchIndex = upstream "extensions/web-fetch/index.ts" "sha256-XkbGHMRtYJjG2Fb5FzJxHadl6Xd1nOxKYAZNl/5aiLE=";
  amosWebFetchPackage = upstream "extensions/web-fetch/package.json" "sha256-4lYfuZ56pzSpuDexodOa4ZiADnreQ/fhNab+0INNhC4=";
  amosWebFetchLock = upstream "extensions/web-fetch/package-lock.json" "sha256-3/ofJOqI8pLzHQjEgMoaMA4sw1WFljpGVUQ/hPyI7qo=";

  localProvider = {
    name = "Dracula local llama.cpp";
    baseUrl = "http://127.0.0.1:8080/v1";
    api = "openai-completions";
    authHeader = false;
    apiKey = "unused";
    models = lib.mapAttrsToList (id: model: {
      inherit id;
      name = model.displayName;
      reasoning = model.reasoning;
      input = [ "text" ];
      contextWindow = model.contextSize;
      maxTokens = model.output;
      cost = model.cost // {
        cacheRead = 0;
        cacheWrite = 0;
      };
      compat = {
        supportsStore = false;
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        maxTokensField = "max_tokens";
      };
    }) osConfig.services.localLlama.models;
  };
  piModels = {
    providers = lib.optionalAttrs isDracula {
      dracula-local = localProvider;
    };
  };

  piSettings = {
    # Initial defaults; existing settings and native package selections take precedence.
    defaultProjectTrust = "ask";
    defaultProvider = "claude-bridge";
    defaultModel = "claude-sonnet-5-5";
    defaultTools = [
      "read"
      "bash"
      "edit"
      "write"
    ];
    externalEditor = "emacsclient -c -a emacs";
    packages = [
      "${home}/.local/share/agent-content/mentor"
      "${home}/.local/share/agent-content/prompt-snippets"
      "${home}/.local/share/agent-content/learning"
      "git:github.com/HazAT/pi-interactive-subagents@c100577ebf7393a11d098ad9810ec6c269dcfc30"
      "npm:pi-claude-bridge"
      "git:github.com/requestyai/pi-requesty@c28e2f8208eb467d248a7dc33bfb5cb04f310575"
    ];
    extensions = [
      "${agentDir}/upstream/amos-ask-user-question.ts"
      "${agentDir}/upstream/amos-web-fetch"
    ];
    # Keep Pi-owned and package skills, without the shared harness policy skills.
    # Pi discovers ~/.agents/skills automatically; exclude that tree explicitly.
    skills = [ "!${home}/.agents/skills/**" ];
  };
  bootstrap = pkgs.writeShellApplication {
    name = "bootstrap-pi";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.nodejs
    ];
    runtimeEnv = {
      PI_AGENT_DIR = agentDir;
      PI_DEFAULT_SETTINGS = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);
      PI_DECLARED_MODELS = pkgs.writeText "pi-models.json" (builtins.toJSON piModels);
      PI_WEB_INDEX = amosWebFetchIndex;
      PI_WEB_PACKAGE = amosWebFetchPackage;
      PI_WEB_LOCK = amosWebFetchLock;
      PI_VERSION = piVersion;
    }
    // lib.optionalAttrs (requestyKeyFile != null) {
      PI_REQUESTY_KEY_FILE = requestyKeyFile;
      PI_REQUESTY_URL = requesty.endpoint;
    };
    text = builtins.readFile ../scripts/bootstrap-pi.sh;
  };
in
{
  imports = [ ./agent-content.nix ];
  options.programs.piClient.enable = lib.mkEnableOption "Pi coding client";

  config = lib.mkIf config.programs.piClient.enable {
    home.agentContent.enable = true;
    home.file = {
      # AGENTS.md and MEMORY.md are agent-owned writable files, not Nix resources.
      ".pi/agent/skills/mentor".source = link "${home}/.local/share/agent-content/mentor/skills/mentor";
      ".pi/agent/skills/meeting-minutes".source = link "${repo}/pi/skills/meeting-minutes";
      ".pi/agent/agents/researcher.md".source =
        link "${home}/.local/share/agent-content/learning/pi/agents/researcher.md";
      ".pi/agent/agents/mermaid-maker.md".source =
        link "${home}/.local/share/agent-content/learning/agents/mermaid-maker.md";
      ".pi/agent/agents/svg-maker.md".source =
        link "${home}/.local/share/agent-content/learning/agents/svg-maker.md";
      ".pi/agent/upstream/amos-ask-user-question.ts".source = amosAskUserQuestion;
    };

    # Scope HazAT's multiplexer choice to Pi invocations.
    programs.fish.functions.pi = {
      body = ''
        set -lx PI_SUBAGENT_MUX zellij
        command pi $argv
      '';
    };

    home.activation.piAgentBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${lib.getExe bootstrap}
      fi
    '';

  };
}
