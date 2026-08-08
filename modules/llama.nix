{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localLlama;
  stateDirectoryName = lib.removePrefix "/var/lib/" cfg.stateDirectory;
  modelPath = "${cfg.stateDirectory}/models/${cfg.model.file}";
  modelUrl = "https://huggingface.co/${cfg.model.repo}/resolve/${cfg.model.revision}/${cfg.model.file}";
  proxy = pkgs.writeText "llama-logging-proxy.py" (builtins.readFile ./llama-logging-proxy.py);
  prepareLogs = pkgs.writeShellScript "prepare-local-llama-logs" ''
    ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg (builtins.dirOf cfg.requestLog)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg cfg.requestLog}
    ${pkgs.coreutils}/bin/chmod 0640 ${lib.escapeShellArg cfg.requestLog}
  '';
  downloadModel = pkgs.writeShellScript "download-local-llama-model" ''
    set -euo pipefail
    model=${lib.escapeShellArg modelPath}
    partial="$model.partial"
    marker="$model.verified-sha256"
    if [ -f "$model" ] && [ -f "$marker" ] && [ "$(< "$marker")" = ${lib.escapeShellArg cfg.model.sha256} ]; then
      exit 0
    fi
    if [ -f "$model" ] && ${pkgs.coreutils}/bin/printf '%s  %s\n' ${lib.escapeShellArg cfg.model.sha256} "$model" \
      | ${pkgs.coreutils}/bin/sha256sum --check --status; then
      ${pkgs.coreutils}/bin/printf '%s\n' ${lib.escapeShellArg cfg.model.sha256} > "$marker"
      exit 0
    fi
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$model")"
    ${pkgs.curl}/bin/curl --fail --location --retry 5 --continue-at - \
      --output "$partial" ${lib.escapeShellArg modelUrl}
    ${pkgs.coreutils}/bin/printf '%s  %s\n' ${lib.escapeShellArg cfg.model.sha256} "$partial" \
      | ${pkgs.coreutils}/bin/sha256sum --check
    ${pkgs.coreutils}/bin/mv "$partial" "$model"
    ${pkgs.coreutils}/bin/printf '%s\n' ${lib.escapeShellArg cfg.model.sha256} > "$marker"
  '';
in
{
  options.services.localLlama = {
    enable = lib.mkEnableOption "local OpenAI-compatible llama.cpp inference";
    package = lib.mkPackageOption pkgs "llama-cpp" { };
    model = {
      repo = lib.mkOption {
        type = lib.types.str;
        description = "Hugging Face repository.";
      };
      revision = lib.mkOption {
        type = lib.types.str;
        description = "Pinned Hugging Face revision.";
      };
      file = lib.mkOption {
        type = lib.types.str;
        description = "GGUF filename.";
      };
      sha256 = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{64}";
        description = "GGUF SHA-256.";
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "local-coder";
        description = "Stable API model alias.";
      };
    };
    contextSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 65536;
    };
    parallelSlots = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
    };
    gpuLayers = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = "Number of model layers to offload to GPU, or null for llama.cpp automatic selection.";
    };
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Logging proxy/API port.";
    };
    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
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
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port != cfg.backendPort;
        message = "services.localLlama.port and backendPort must differ";
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

    systemd.services.local-llama = {
      description = "Local llama.cpp inference server";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      serviceConfig = {
        Type = "simple";
        User = "llama";
        Group = "llama";
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0750";
        ExecStartPre = downloadModel;
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/llama-server"
            "--model"
            modelPath
            "--host"
            cfg.bindAddress
            "--port"
            (toString cfg.backendPort)
            "--ctx-size"
            (toString cfg.contextSize)
            # llama-server divides the total context across parallel slots.
            "--parallel"
            (toString cfg.parallelSlots)
            "--alias"
            cfg.model.alias
            "--metrics"
            "--no-webui"
            "--log-timestamps"
            "--log-colors"
            "off"
          ]
          ++ lib.optionals (cfg.gpuLayers != null) [
            "--n-gpu-layers"
            (toString cfg.gpuLayers)
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "infinity";
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
        const units = ["ai-stack.target", "local-llama.service", "local-llama-logger.service"];
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
          llama_state="$(${pkgs.systemd}/bin/systemctl is-active local-llama.service || true)"
          logger_state="$(${pkgs.systemd}/bin/systemctl is-active local-llama-logger.service || true)"
          if { [ "$llama_state" = inactive ] || [ "$llama_state" = failed ]; } \
            && [ "$logger_state" = inactive ]; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.2
        done
        echo "AI services did not stop within 30 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-health" "exec ${pkgs.curl}/bin/curl --fail --silent --show-error http://${cfg.bindAddress}:${toString cfg.port}/health")
    ];
  };
}
