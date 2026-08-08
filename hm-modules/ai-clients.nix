{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  endpoint = "http://127.0.0.1:8080/v1";
  model = "qwen3.6-27b-local";
  provider = "dracula-local";
  modelSelector = "${provider}/${model}";
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
        default = modelSelector;
        smol = modelSelector;
        slow = modelSelector;
        plan = modelSelector;
        commit = modelSelector;
        tiny = modelSelector;
        task = modelSelector;
        advisor = modelSelector;
      };
      cycleOrder = [ "default" ];
      enabledModels = [ modelSelector ];
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
        models = [
          {
            id = model;
            name = "Qwen3.6 27B Q4_K_M (Dracula local)";
            reasoning = false;
            input = [ "text" ];
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            contextWindow = 32768;
            maxTokens = 8192;
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = false;
              maxTokensField = "max_tokens";
            };
          }
        ];
      };
    };

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = modelSelector;
      small_model = modelSelector;
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
        models.${model} = {
          name = "Qwen3.6 27B Q4_K_M (Dracula local)";
          limit = {
            context = 32768;
            output = 8192;
          };
        };
      };
    };
  };
}
