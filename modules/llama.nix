{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localLlama;
  stateDirectoryName = lib.removePrefix "/var/lib/" cfg.stateDirectory;
  proxy = pkgs.writeText "llama-logging-proxy.py" (builtins.readFile ./llama-logging-proxy.py);
  usageSummary = pkgs.writeText "llama-usage-summary.py" (builtins.readFile ./llama-usage-summary.py);
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
        aliases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional request model IDs routed to ${name}.";
        };
        contextSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 65536;
          description = "Total llama-server context across every parallel slot.";
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
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
      };
    }
  );

  modelPath = model: "${cfg.stateDirectory}/models/${model.file}";
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
        "${cfg.package}/bin/llama-server"
        "--model"
        (modelPath model)
        "--host"
        cfg.bindAddress
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
      ]
      ++ model.extraArgs;
    in
    pkgs.writeShellScript "run-local-llama-${safeName name}" ''
      set -euo pipefail
      port="''${1:?llama-swap did not provide a dynamic port}"
      ${modelDownloads.${name}}
      exec ${lib.escapeShellArgs args} --port "$port"
    ''
  ) cfg.models;

  swapConfig = yaml.generate "llama-swap.yaml" {
    startPort = cfg.modelStartPort;
    healthCheckTimeout = cfg.healthCheckTimeout;
    globalTTL = 0;
    unloadTimeout = 5;
    includeAliasesInList = true;
    sendLoadingState = false;
    logToStdout = "both";
    models = lib.mapAttrs (name: model: {
      cmd = "${modelRunners.${name}} \${PORT}";
      inherit (model) aliases description;
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

  prepareLogs = pkgs.writeShellScript "prepare-local-llama-logs" ''
    ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg (builtins.dirOf cfg.requestLog)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg cfg.requestLog}
    ${pkgs.coreutils}/bin/chmod 0640 ${lib.escapeShellArg cfg.requestLog}
  '';

  modelNames = builtins.attrNames cfg.models;
  allModelIds = modelNames ++ lib.concatMap (name: cfg.models.${name}.aliases) modelNames;
  modelFiles = map (name: cfg.models.${name}.file) modelNames;
  dynamicPorts = lib.range cfg.modelStartPort (cfg.modelStartPort + builtins.length modelNames - 1);
in
{
  options.services.localLlama = {
    enable = lib.mkEnableOption "local OpenAI-compatible llama.cpp inference";
    package = lib.mkPackageOption pkgs "llama-cpp" { };
    swapPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/llama-swap.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../packages/llama-swap.nix { }";
      description = "Pinned llama-swap package.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Pinned model registry keyed by the primary request model ID.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      description = "Default model ID selected by clients; llama-swap still routes every request explicitly.";
    };
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Stable logging proxy/API port.";
    };
    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "llama-swap listen port behind the logging proxy.";
    };
    modelStartPort = lib.mkOption {
      type = lib.types.port;
      default = 18100;
      description = "First dynamic llama-server port assigned by llama-swap.";
    };
    healthCheckTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 7200;
      description = "Seconds llama-swap waits for a downloaded model to become ready.";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to inspect local model state and request logs.";
    };
    requestLog = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama/logs/requests.jsonl";
    };
    logRetention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Rotated log files retained.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port != cfg.backendPort;
        message = "services.localLlama.port and backendPort must differ";
      }
      {
        assertion = cfg.models != { };
        message = "services.localLlama.models must contain at least one model";
      }
      {
        assertion = builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.localLlama.defaultModel must name a registered model";
      }
      {
        assertion = builtins.length allModelIds == builtins.length (lib.unique allModelIds);
        message = "services.localLlama model IDs and aliases must be globally unique";
      }
      {
        assertion = builtins.length modelFiles == builtins.length (lib.unique modelFiles);
        message = "services.localLlama model filenames must be unique";
      }
      {
        assertion = !(builtins.elem cfg.port dynamicPorts) && !(builtins.elem cfg.backendPort dynamicPorts);
        message = "services.localLlama dynamic model ports must not overlap ingress ports";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.localLlama.stateDirectory must be below /var/lib";
      }
    ];

    systemd.targets.ai-stack = {
      description = "Local AI stack";
      wantedBy = [ "multi-user.target" ];
    };

    users = {
      groups.llama = { };
      users = {
        llama = {
          isSystemUser = true;
          group = "llama";
          home = cfg.stateDirectory;
        };
      }
      // lib.genAttrs cfg.operators (_: {
        extraGroups = [ "llama" ];
      });
    };

    systemd.services.local-llama-swap = {
      description = "llama-swap local model router";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        Type = "simple";
        User = "llama";
        Group = "llama";
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0750";
        WorkingDirectory = cfg.stateDirectory;
        ExecStartPre = downloadAllModels;
        ExecStart = lib.escapeShellArgs [
          "${cfg.swapPackage}/bin/llama-swap"
          "-config"
          swapConfig
          "-listen"
          "${cfg.bindAddress}:${toString cfg.backendPort}"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "infinity";
        TimeoutStopSec = "10s";
        KillMode = "control-group";
        KillSignal = "SIGKILL";
      };
    };

    systemd.services.local-llama-logger = {
      description = "Payload-logging proxy for local llama.cpp";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      environment = {
        LLAMA_BACKEND = "http://${cfg.bindAddress}:${toString cfg.backendPort}";
        LLAMA_PROXY_HOST = cfg.bindAddress;
        LLAMA_PROXY_PORT = toString cfg.port;
        LLAMA_REQUEST_LOG = cfg.requestLog;
      };
      serviceConfig = {
        User = "llama";
        Group = "llama";
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0750";
        ExecStartPre = prepareLogs;
        ExecStart = "${pkgs.python3}/bin/python3 ${proxy}";
        Restart = "on-failure";
        RestartSec = "2s";
        UMask = "0027";
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

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        const units = ["ai-stack.target", "local-llama-swap.service", "local-llama-logger.service"];
        const verbs = ["start", "stop", "restart", "kill"];
        if (action.id === "org.freedesktop.systemd1.manage-units"
            && subject.isInGroup("llama")
            && units.indexOf(action.lookup("unit")) !== -1
            && verbs.indexOf(action.lookup("verb")) !== -1) {
          return polkit.Result.YES;
        }
      });
    '';

    services.logrotate.settings.${cfg.requestLog} = {
      daily = true;
      size = "1G";
      rotate = cfg.logRetention;
      compress = true;
      missingok = true;
      notifempty = true;
      copytruncate = true;
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ai-stack-start" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl start ai-stack.target
        for _ in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.curl}/bin/curl --fail --silent --max-time 1 http://${cfg.bindAddress}:${toString cfg.port}/health >/dev/null; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "AI stack did not become healthy within 120 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-stop" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl stop ai-stack.target
        for _ in $(${pkgs.coreutils}/bin/seq 1 150); do
          swap_state="$(${pkgs.systemd}/bin/systemctl is-active local-llama-swap.service || true)"
          logger_state="$(${pkgs.systemd}/bin/systemctl is-active local-llama-logger.service || true)"
          if { [ "$swap_state" = inactive ] || [ "$swap_state" = failed ]; } \
            && [ "$logger_state" = inactive ]; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.2
        done
        echo "AI services did not stop within 30 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-health" "exec ${pkgs.curl}/bin/curl --fail --silent --show-error http://${cfg.bindAddress}:${toString cfg.port}/health")
      (pkgs.writeShellScriptBin "ai-usage-summary" ''
        export LLAMA_REQUEST_LOG=${lib.escapeShellArg cfg.requestLog}
        exec ${pkgs.python3}/bin/python3 ${usageSummary} "$@"
      '')
    ];
  };
}
