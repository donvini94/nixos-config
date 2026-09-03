{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  hostname = osConfig.networking.hostName;
  isDracula = hostname == "dracula";
  isRemote = osConfig.services.remoteOpenAI.enable;
  active = isDracula || isRemote;
  localProfile = {
    endpoint = "http://127.0.0.1:8080/v1";
    provider = "dracula-local";
    providerName = "Dracula local llama.cpp";
    inherit (osConfig.services.localLlama) defaultModel;
    disableStrictTools = true;
    # llama.nix names these fields for the serving side; clients consume the
    # OpenAI-shaped names that services.remoteOpenAI.models already exposes.
    models = lib.mapAttrs (_id: model: {
      name = model.displayName;
      context = model.contextSize;
      inherit (model) output reasoning cost;
    }) osConfig.services.localLlama.models;
  };
  requestyProfile = {
    endpoint =
      if isDracula then "http://alucard.tailf117a1.ts.net:28080/v1" else "http://127.0.0.1:8080/v1";
    provider = "alucard-requesty";
    providerName = "Alucard Requesty ingress";
    defaultModel = osConfig.services.remoteOpenAI.defaultModel;
    disableStrictTools = false;
    models = osConfig.services.remoteOpenAI.models;
  };
  profiles =
    if isDracula then
      [
        localProfile
        requestyProfile
      ]
    else
      [ requestyProfile ];
  defaultProfile = if isDracula then localProfile else requestyProfile;
  modelSelector = profile: model: "${profile.provider}/${model}";
  defaultModelSelector = modelSelector defaultProfile defaultProfile.defaultModel;
  # Custom-provider selectors only; the harness package adds the scopes for
  # OMP's bundled subscription-authenticated providers.
  profileModels = lib.concatMap (
    profile: map (modelSelector profile) (builtins.attrNames profile.models)
  ) profiles;
  authenticatedOpenCodeProviders = [
    "anthropic"
    "openai"
  ];
  ompProviders = lib.listToAttrs (
    map (profile: {
      name = profile.provider;
      value = {
        baseUrl = profile.endpoint;
        api = "openai-completions";
        auth = "none";
        disableStrictTools = profile.disableStrictTools;
        headers.X-AI-Caller = "omp";
        models = lib.mapAttrsToList (id: model: {
          inherit id;
          inherit (model) name reasoning;
          input = [ "text" ];
          cost = model.cost // {
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
        }) profile.models;
      };
    }) profiles
  );
  opencodeProviders = lib.listToAttrs (
    map (profile: {
      name = profile.provider;
      value = {
        npm = "@ai-sdk/openai-compatible";
        name = profile.providerName;
        options = {
          baseURL = profile.endpoint;
          headers.X-AI-Caller = "opencode";
        };
        models = lib.mapAttrs (_id: model: {
          inherit (model) name;
          reasoning = model.reasoning;
          limit = {
            inherit (model) context output;
          };
        }) profile.models;
      };
    }) profiles
  );
  yaml = pkgs.formats.yaml { };
  omp = pkgs.callPackage ../packages/omp-harness.nix {
    extraEnabledModels = profileModels;
  };
  opencode = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      selected_model=${lib.escapeShellArg defaultModelSelector}
      expect_model=false

      for argument in "$@"; do
        if [[ "$expect_model" == true ]]; then
          selected_model="$argument"
          expect_model=false
          continue
        fi

        case "$argument" in
          -m|--model)
            expect_model=true
            ;;
          --model=*)
            selected_model="''${argument#--model=}"
            ;;
        esac
      done

      existing_config="''${OPENCODE_CONFIG_CONTENT-}"
      if [[ -z "$existing_config" ]]; then
        existing_config='{}'
      fi
      merged_config="$(${lib.getExe pkgs.jq} -cn \
        --argjson existing "$existing_config" \
        --arg model "$selected_model" \
        '$existing * {
          small_model: $model,
          agent: {
            title: { disable: true },
            summary: { model: $model },
            compaction: { model: $model }
          }
        }')"
      export OPENCODE_CONFIG_CONTENT="$merged_config"

      exec ${lib.getExe pkgs.opencode} "$@"
    '';
  };
in
{
  config = lib.mkIf active {
    home.packages = [
      omp
      opencode
    ];

    home.file.".omp/agent/models.yml".source = yaml.generate "omp-models.yml" {
      providers = ompProviders;
    };

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = defaultModelSelector;
      small_model = defaultModelSelector;
      enabled_providers =
        map (profile: profile.provider) profiles ++ authenticatedOpenCodeProviders;
      share = "disabled";
      autoupdate = false;
      experimental.openTelemetry = true;
      plugin = [ "@langfuse/opencode-observability-plugin@latest" ];
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
      provider = opencodeProviders;
    };

    xdg.configFile."opencode/opencode-langfuse.json".source =
      config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-langfuse.json";
  };
}
