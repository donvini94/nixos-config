{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localLlama;
  stateDirectory = "/var/lib/llama";
  bindAddress = "127.0.0.1";
  backendPort = 18080;
  # First dynamic llama-server port; llama-swap assigns upwards from here.
  modelStartPort = 18100;
  yaml = pkgs.formats.yaml { };

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        repo = lib.mkOption {
          type = lib.types.str;
          description = "Hugging Face repository for ${name}.";
        };
        revision = lib.mkOption {
          type = lib.types.str;
          description = "Pinned Hugging Face revision for ${name}.";
        };
        file = lib.mkOption {
          type = lib.types.str;
          description = "GGUF filename for ${name}.";
        };
        sha256 = lib.mkOption {
          type = lib.types.strMatching "[0-9a-f]{64}";
          description = "GGUF SHA-256 for ${name}.";
        };
        displayName = lib.mkOption {
          type = lib.types.str;
          default = name;
        };
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        contextSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 65536;
          description = "Total llama-server context across every parallel slot.";
        };
        output = lib.mkOption {
          type = lib.types.ints.positive;
          default = 8192;
          description = "Maximum response tokens advertised to client configuration.";
        };
        reasoning = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether clients should treat ${name} as a reasoning model.";
        };
        cost = lib.mkOption {
          type = lib.types.submodule {
            options = {
              input = lib.mkOption { type = lib.types.number; };
              output = lib.mkOption { type = lib.types.number; };
            };
          };
          default = {
            input = 0;
            output = 0;
          };
          description = "USD per million input and output tokens; 0 for locally served models.";
        };
        parallelSlots = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
        };
        gpuLayers = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          default = null;
          description = "Layers to offload to GPU, or null for llama.cpp automatic selection.";
        };
      };
    }
  );

  modelPath = model: "${stateDirectory}/models/${model.file}";
  modelUrl = model: "https://huggingface.co/${model.repo}/resolve/${model.revision}/${model.file}";
  safeName = name: lib.replaceStrings [ "." "/" ] [ "-" "-" ] name;

  modelDownloads = lib.mapAttrs (
    name: model:
    pkgs.writeShellScript "download-local-llama-${safeName name}" ''
      set -euo pipefail
      model=${lib.escapeShellArg (modelPath model)}
      partial="$model.partial"
      marker="$model.verified-sha256"
      if [ -f "$model" ] && [ -f "$marker" ] && [ "$(< "$marker")" = ${lib.escapeShellArg model.sha256} ]; then
        exit 0
      fi
      if [ -f "$model" ] && ${pkgs.coreutils}/bin/printf '%s  %s\n' ${lib.escapeShellArg model.sha256} "$model" \
        | ${pkgs.coreutils}/bin/sha256sum --check --status; then
        ${pkgs.coreutils}/bin/printf '%s\n' ${lib.escapeShellArg model.sha256} > "$marker"
        exit 0
      fi
      ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$model")"
      ${pkgs.curl}/bin/curl --fail --location --retry 5 --continue-at - \
        --output "$partial" ${lib.escapeShellArg (modelUrl model)}
      ${pkgs.coreutils}/bin/printf '%s  %s\n' ${lib.escapeShellArg model.sha256} "$partial" \
        | ${pkgs.coreutils}/bin/sha256sum --check
      ${pkgs.coreutils}/bin/mv "$partial" "$model"
      ${pkgs.coreutils}/bin/printf '%s\n' ${lib.escapeShellArg model.sha256} > "$marker"
    ''
  ) cfg.models;

  downloadAllModels = pkgs.writeShellScript "download-all-local-llama-models" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_name: downloader: lib.escapeShellArg downloader) modelDownloads
    )}
  '';

  modelRunners = lib.mapAttrs (
    name: model:
    let
      args = [
        "${pkgs.llama-cpp}/bin/llama-server"
        "--model"
        (modelPath model)
        "--host"
        bindAddress
        "--ctx-size"
        (toString model.contextSize)
        "--parallel"
        (toString model.parallelSlots)
        "--alias"
        name
        "--metrics"
        "--no-webui"
        "--log-timestamps"
        "--log-colors"
        "off"
      ]
      ++ lib.optionals (model.gpuLayers != null) [
        "--n-gpu-layers"
        (toString model.gpuLayers)
      ];
    in
    pkgs.writeShellScript "run-local-llama-${safeName name}" ''
      set -euo pipefail
      port="''${1:?llama-swap did not provide a dynamic port}"
      ${modelDownloads.${name}}
      exec ${lib.escapeShellArgs args} --port "$port"
    ''
  ) cfg.models;

  swapConfig = yaml.generate "llama-swap.yaml" {
    startPort = modelStartPort;
    # A first run downloads the weights before llama-server answers /health.
    healthCheckTimeout = 7200;
    globalTTL = 0;
    unloadTimeout = 5;
    includeAliasesInList = true;
    sendLoadingState = false;
    logToStdout = "both";
    models = lib.mapAttrs (name: model: {
      cmd = "${modelRunners.${name}} \${PORT}";
      aliases = [ ];
      inherit (model) description;
      name = model.displayName;
      checkEndpoint = "/health";
      useModelName = name;
      concurrencyLimit = model.parallelSlots;
      metadata = {
        context_length = builtins.div model.contextSize model.parallelSlots;
        total_context = model.contextSize;
        parallel_slots = model.parallelSlots;
      };
    }) cfg.models;
  };

  modelFiles = lib.mapAttrsToList (_name: model: model.file) cfg.models;
in
{
  options.services.localLlama = {
    enable = lib.mkEnableOption "local OpenAI-compatible llama.cpp inference";
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Pinned model registry keyed by the primary request model ID.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != { };
        message = "services.localLlama.models must contain at least one model";
      }
      {
        assertion = builtins.length modelFiles == builtins.length (lib.unique modelFiles);
        message = "services.localLlama model filenames must be unique";
      }
    ];

    systemd.services.local-llama-swap = {
      description = "llama-swap local model router";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        Type = "simple";
        User = "llama";
        Group = "llama";
        StateDirectory = "llama";
        StateDirectoryMode = "0750";
        WorkingDirectory = stateDirectory;
        ExecStartPre = downloadAllModels;
        ExecStart = lib.escapeShellArgs [
          "${pkgs.llama-swap}/bin/llama-swap"
          "-config"
          swapConfig
          "-listen"
          "${bindAddress}:${toString backendPort}"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "10s";
        KillMode = "control-group";
        KillSignal = "SIGTERM";
      };
    };

    systemd.services.ai-stack-resume = {
      description = "Recover the local AI stack after suspend";
      wantedBy = [ "suspend.target" ];
      after = [ "suspend.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart ai-stack.target";
      };
    };

    services.logind.settings.Login.IdleAction = "ignore";

    # The ingress, its logging, metrics, and operator tooling are shared with
    # the Requesty backend; this module only supplies the local one.
    services.aiIngress = {
      enable = true;
      backendUrl = "http://${bindAddress}:${toString backendPort}";
      priceMap = lib.mapAttrs (_: model: model.cost) cfg.models;
      lifecycleUnits = [
        "ai-stack.target"
        "local-llama-swap.service"
        "local-llama-logger.service"
      ];
      # Model downloads and the llama-swap handoff need paths the confined
      # filesystem view would hide.
      hardened = false;
      extraAfter = [ "local-llama-swap.service" ];
    };
  };
}
