{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  endpoint = "http://127.0.0.1:8080/v1";
  provider = "dracula-local";
  defaultModel = "qwen3.6-27b-local";
  modelDefinitions = {
    "qwen3.6-27b-local" = {
      name = "Qwen3.6 27B Q4_K_M (Dracula local)";
      context = 32768;
      output = 8192;
    };
    "qwen3.6-35b-a3b" = {
      name = "Qwen3.6 35B-A3B UD-Q3_K_M (Dracula local)";
      context = 32768;
      output = 8192;
    };
  };
  modelSelector = model: "${provider}/${model}";
  defaultModelSelector = modelSelector defaultModel;
  enabledModels = map modelSelector (builtins.attrNames modelDefinitions);
  omp = pkgs.callPackage ../packages/omp.nix { };
  yaml = pkgs.formats.yaml { };
in
{
  config = lib.mkIf (osConfig.networking.hostName == "dracula") {
    home.packages = [
      omp
      pkgs.opencode
    ];

    # Keep every OMP role on the local allow-listed model. This also prevents
    # lightweight/background tasks from discovering a remote fallback.
    home.file.".omp/agent/config.yml".source = yaml.generate "omp-config.yml" {
      modelRoles = {
        default = defaultModelSelector;
        smol = defaultModelSelector;
        slow = defaultModelSelector;
        plan = defaultModelSelector;
        commit = defaultModelSelector;
        tiny = defaultModelSelector;
        task = defaultModelSelector;
        advisor = defaultModelSelector;
      };
      cycleOrder = [ "default" ];
      inherit enabledModels;
      disabledProviders = [ "llama.cpp" ];
      advisor.enabled = false;
      tools.approvalMode = "always-ask";
      startup.checkUpdate = false;
      marketplace.autoUpdate = "off";
    };

    home.file.".omp/agent/models.yml".source = yaml.generate "omp-models.yml" {
      providers.${provider} = {
        baseUrl = endpoint;
        api = "openai-completions";
        auth = "none";
        disableStrictTools = true;
        headers.X-AI-Caller = "omp";
        models = lib.mapAttrsToList (id: model: {
          inherit id;
          inherit (model) name;
          reasoning = false;
          input = [ "text" ];
          cost = {
            input = 0;
            output = 0;
            cacheRead = 0;
            cacheWrite = 0;
          };
          contextWindow = model.context;
          maxTokens = model.output;
          compat = {
            supportsStore = false;
            supportsDeveloperRole = false;
            supportsReasoningEffort = false;
            maxTokensField = "max_tokens";
          };
        }) modelDefinitions;
      };
    };

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = defaultModelSelector;
      small_model = defaultModelSelector;
      enabled_providers = [ provider ];
      share = "disabled";
      autoupdate = false;
      permission = {
        "*" = "ask";
        read = "allow";
        glob = "allow";
        grep = "allow";
        lsp = "allow";
        question = "allow";
        skill = "allow";
        webfetch = "allow";
        websearch = "allow";
      };
      provider.${provider} = {
        npm = "@ai-sdk/openai-compatible";
        name = "Dracula local llama.cpp";
        options = {
          baseURL = endpoint;
          headers.X-AI-Caller = "opencode";
        };
        models = lib.mapAttrs (_id: model: {
          inherit (model) name;
          limit = {
            inherit (model) context output;
          };
        }) modelDefinitions;
      };
    };
  };
}
