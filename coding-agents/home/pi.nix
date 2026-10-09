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
  repo = config.home.aiStack.checkout;
  link = config.lib.file.mkOutOfStoreSymlink;
  hasLocalModel = osConfig.services.localLlama.enable or false;
  requesty = osConfig.services.requesty or null;
  requestyKeyFile = requesty.apiKeyFile or null;

  # npm installs the pinned binary into the writable ~/.local prefix.
  piVersion = "1.1.0";

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
    providers = lib.optionalAttrs hasLocalModel {
      dracula-local = localProvider;
    };
  };

  piSettings = {
    # Portable fields are declared here; Pi's device identity stays state-owned.
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
      "npm:pi-claude-bridge@0.9.2"
      "git:github.com/DietrichGebert/ponytail@9cc65d03aa2da1db7121b912d03596409ee340b8"
      "npm:@gotgenes/pi-subagents@23.2.0"
      "npm:pi-openai-long-context@0.7.0"
      "npm:pi-web-search@1.7.0"
      "git:github.com/donvini94/omp-learn@465fecc0b65e7a45112f00895c0be1e367eb3e44"
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
      PI_DECLARED_SUBAGENTS = pkgs.writeText "pi-subagents.json" (
        builtins.toJSON { promptInheritance.claude-bridge = "portable"; }
      );
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
  imports = [
    ./agent-content.nix
    ./checkout.nix
  ];
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

    home.activation.piAgentBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -z "''${DRY_RUN:-}" ]; then
        ${lib.getExe bootstrap}
      fi
    '';

  };
}
