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
    disableStrictTools = true;
    # llama.nix names these fields for the serving side; clients consume the OpenAI-shaped
    # names that services.remoteOpenAI.models already exposes.
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
  modelSelector = profile: model: "${profile.provider}/${model}";
  # Only dracula serves a local model, so only dracula gets `omp-local` / `omp-chat`.
  localModel =
    if isDracula then modelSelector localProfile osConfig.services.localLlama.defaultModel else null;
  # Custom-provider selectors only; the harness package adds the scopes for
  # OMP's bundled subscription-authenticated providers.
  profileModels = lib.concatMap (
    profile: map (modelSelector profile) (builtins.attrNames profile.models)
  ) profiles;
  ompProviders = lib.listToAttrs (
    map (profile: {
      name = profile.provider;
      value = {
        baseUrl = profile.endpoint;
        api = "openai-completions";
        auth = "none";
        disableStrictTools = profile.disableStrictTools;
        headers.X-AI-Caller = "omp";
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
            # Froggeric's v22.5 template reads thinking from the request body, not from
            # `reasoning_effort`: without `thinkingFormat = "qwen"` every level below the
            # template's own default still generated at that default, and `--thinking off`
            # produced a full reasoning block. `requiresEffort = false` is what lets `off`
            # send `enable_thinking: false` instead of being clamped to the lowest effort.
            # The ladder stops at `high` because this template maps OMP's `high` onto its
            # internal xhigh; `xhigh`/`max` would only be slower, not deeper.
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
  # `smol` backs session titles and prewalk, so both hosts point it at the Requesty
  # ingress's cheap default rather than dracula's local model: the role must not break
  # whenever TabbyAPI is down.
  smolModel = modelSelector requestyProfile requestyProfile.defaultModel;
  omp = pkgs.callPackage ../packages/omp-harness.nix {
    extraEnabledModels = profileModels;
    modelRoles.smol = smolModel;
    inherit localModel;
    cycleOrder = [
      "smol"
      "default"
      "slow"
    ];
  };
in
{
  config = lib.mkIf active {
    home.packages = [ omp ];

    home.file = {
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" {
        providers = ompProviders;
      };
    }
    # A named profile sees only its own user-level config — never ~/.omp/agent — so the
    # local profile needs its own copy of the provider it is allowed to reach (the local
    # one alone) and its own AGENTS.md. The AGENTS.md is a link to the default profile's
    # file, which is itself an out-of-store link into this repository: one authored file,
    # editable without a rebuild, visible to both profiles.
    // lib.optionalAttrs isDracula {
      ".omp/profiles/local/agent/models.yml".source = yaml.generate "omp-local-models.yml" {
        providers.${localProfile.provider} = ompProviders.${localProfile.provider};
      };
      ".omp/profiles/local/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.omp/agent/AGENTS.md";
    };
  };
}
