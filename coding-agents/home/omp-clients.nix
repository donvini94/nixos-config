{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  hasLocalModel = osConfig.services.localLlama.enable or false;
  # Only hosts that import coding-agents/nixos/requesty.nix have a remote profile.
  requesty = osConfig.services.requesty or null;
  requestyKeyFile = requesty.apiKeyFile or null;
  isRemote = requestyKeyFile != null;
  active = config.programs.ompClient.enable && (hasLocalModel || isRemote);
  isAlucard = (osConfig.networking.hostName or null) == "alucard";
  # Alucard imports the Mac snapshot into a dedicated bank; its live legacy bank remains
  # untouched for the already-running OMP process.
  mnemopiDbPath =
    if isAlucard then
      "${config.home.homeDirectory}/.omp/agent/memories/mac-import-20261009/mnemopi.db"
    else
      null;
  localProfile = {
    endpoint = "http://127.0.0.1:8080/v1";
    provider = "dracula-local";
    disableStrictTools = true;
    # Local serving metadata is declared; remote metadata is discovered.
    models = lib.mapAttrs (_id: model: {
      name = model.displayName;
      context = model.contextSize;
      inherit (model) output reasoning cost;
    }) osConfig.services.localLlama.models;
  };
  requestyProfile = {
    inherit (requesty) endpoint defaultModel;
    provider = "requesty";
    disableStrictTools = false;
    models = { }; # Discovered at runtime from the organization-approved catalog.
  };
  profiles =
    if hasLocalModel then
      [
        localProfile
        requestyProfile
      ]
    else
      [ requestyProfile ];
  modelSelector = profile: model: "${profile.provider}/${model}";
  # Only dracula serves a local model, so only dracula gets `omp-local` / `omp-chat`.
  localModel =
    if hasLocalModel then modelSelector localProfile osConfig.services.localLlama.defaultModel else null;
  # Custom-provider selectors only; the harness package adds the scopes for
  # OMP's bundled subscription-authenticated providers.
  profileModels = lib.concatMap (
    profile:
    if profile.provider == requestyProfile.provider then
      [ "${profile.provider}/*" ]
    else
      map (modelSelector profile) (builtins.attrNames profile.models)
  ) profiles;
  ompProviders = lib.listToAttrs (
    map (profile: {
      name = profile.provider;
      value = {
        baseUrl = profile.endpoint;
        api = "openai-completions";
        disableStrictTools = profile.disableStrictTools;
      }
      // (
        if profile.provider == requestyProfile.provider then
          {
            auth = "apiKey";
            apiKey = "!cat ${requestyKeyFile}";
            discovery.type = "openai-models-list";
          }
        else
          { auth = "none"; }
      )
      // {
        models = lib.mapAttrsToList (
          id: model:
          {
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
            }
            # Swift's embedded template reads `enable_thinking` and `reasoning_effort`
            # directly from the request body. `thinkingFormat = "qwen"` sends those fields;
            # `requiresEffort = false` keeps `--thinking off` as `enable_thinking: false`
            # instead of clamping it to the lowest reasoning level.
            // lib.optionalAttrs (profile.provider == localProfile.provider) {
              thinkingFormat = "qwen";
              qwenTemplateReasoningEffort = true;
            };
          }
          // lib.optionalAttrs (profile.provider == localProfile.provider && model.reasoning) {
            thinking = {
              mode = "effort";
              efforts = [
                "minimal"
                "low"
                "medium"
                "high"
              ];
              defaultLevel = "low";
              requiresEffort = false;
            };
          }
        ) profile.models;
      };
    }) profiles
  );
  yaml = pkgs.formats.yaml { };
  # Dracula's title/prewalk model must not depend on llama.cpp being up.
  # Alucard keeps the model roles copied into its native settings.
  smolModel = modelSelector requestyProfile requestyProfile.defaultModel;
  omp = pkgs.callPackage ../packages/omp-harness.nix {
    extraEnabledModels = profileModels;
    modelRoles = lib.optionalAttrs (!isAlucard) { smol = smolModel; };
    inherit localModel mnemopiDbPath;
    cycleOrder = if isAlucard then [ "smol" "slow" ] else [
      "smol"
      "default"
      "slow"
    ];
  };
in
{
  config = lib.mkIf active {
    home.packages = [ omp ];

    # A named profile sees only its own user-level config — never ~/.omp/agent — so the
    # local profile needs its own copy of the provider it is allowed to reach (the local
    # one alone) and its own AGENTS.md. The AGENTS.md is a link to the default profile's
    # file, which is itself an out-of-store link into this repository: one authored file,
    # editable without a rebuild, visible to both profiles.
    home.file = {
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" {
        providers = ompProviders;
      };
    }
    // lib.optionalAttrs hasLocalModel {
      ".omp/profiles/local/agent/models.yml".source = yaml.generate "omp-local-models.yml" {
        providers.${localProfile.provider} = ompProviders.${localProfile.provider};
      };
      ".omp/profiles/local/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.omp/agent/AGENTS.md";
    };
  };
}
