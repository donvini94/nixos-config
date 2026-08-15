{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.remoteOpenAI;
  stateDirectoryName = lib.removePrefix "/var/lib/" cfg.stateDirectory;
  proxy = pkgs.writeText "openai-logging-proxy.py" (builtins.readFile ./llama-logging-proxy.py);
  usageSummary = pkgs.writeText "ai-usage-summary.py" (builtins.readFile ./llama-usage-summary.py);
  evalRunner = pkgs.writeText "ai-eval.py" (builtins.readFile ../eval/ai_eval.py);
  evalHarvester = pkgs.writeText "ai-eval-harvest.py" (builtins.readFile ../eval/harvest.py);
  expectedModels = pkgs.writeText "remote-openai-models" (
    lib.concatStringsSep "\n" (builtins.attrNames cfg.models) + "\n"
  );
  prepareLogs = pkgs.writeShellScript "prepare-remote-openai-logs" ''
    ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg (builtins.dirOf cfg.requestLog)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg cfg.requestLog}
    ${pkgs.coreutils}/bin/chmod 0640 ${lib.escapeShellArg cfg.requestLog}
  '';
  validateUpstream = pkgs.writeShellScript "validate-remote-openai" ''
    set -euo pipefail
    credential="$CREDENTIALS_DIRECTORY/upstream-bearer-token"
    if ${pkgs.gnugrep}/bin/grep --quiet '^REPLACE_' "$credential"; then
      echo "Replace the encrypted Requesty API-key placeholder before enabling Alucard AI" >&2
      exit 1
    fi

    response="$(${pkgs.coreutils}/bin/mktemp)"
    actual="$(${pkgs.coreutils}/bin/mktemp)"
    missing="$(${pkgs.coreutils}/bin/mktemp)"
    trap '${pkgs.coreutils}/bin/rm -f "$response" "$actual" "$missing"' EXIT
    {
      ${pkgs.coreutils}/bin/printf 'header = "Authorization: Bearer '
      ${pkgs.coreutils}/bin/tr -d '\r\n' < "$credential"
      ${pkgs.coreutils}/bin/printf '"\n'
    } | ${pkgs.curl}/bin/curl --config - --fail --silent --show-error \
      --output "$response" ${lib.escapeShellArg "${cfg.backendUrl}${cfg.backendHealthPath}"}
    ${pkgs.jq}/bin/jq --exit-status --raw-output '.data[].id' "$response" \
      | ${pkgs.coreutils}/bin/sort --unique > "$actual"
    ${pkgs.coreutils}/bin/comm -23 ${expectedModels} "$actual" > "$missing"
    if [ -s "$missing" ]; then
      echo "Configured models missing from the authenticated Requesty catalog:" >&2
      ${pkgs.coreutils}/bin/cat "$missing" >&2
      exit 1
    fi
  '';

  modelType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
        };
        context = lib.mkOption {
          type = lib.types.ints.positive;
        };
        output = lib.mkOption {
          type = lib.types.ints.positive;
        };
        reasoning = lib.mkOption {
          type = lib.types.bool;
          default = true;
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
          description = "USD per million input and output tokens.";
        };
      };
    }
  );
in
{
  options.services.remoteOpenAI = {
    enable = lib.mkEnableOption "authenticated remote OpenAI-compatible ingress";
    backendUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://router.requesty.ai";
      description = "Upstream origin without the /v1 request path.";
    };
    backendHealthPath = lib.mkOption {
      type = lib.types.str;
      default = "/v1/models";
      description = "Authenticated upstream path used by the local /health probe.";
    };
    upstreamBearerCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Root-only upstream API key injected by the ingress.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "Explicit client-visible model or Requesty policy registry.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama";
    };
    requestLog = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDirectory}/logs/requests.jsonl";
    };
    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    bearerCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional inbound token used only for caller attribution.";
    };
    bearerCredentialCaller = lib.mkOption {
      type = lib.types.str;
      default = "wirken";
    };
    logRetention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.upstreamBearerCredentialFile != null;
        message = "services.remoteOpenAI.upstreamBearerCredentialFile must be configured";
      }
      {
        assertion = cfg.models != { } && builtins.hasAttr cfg.defaultModel cfg.models;
        message = "services.remoteOpenAI.defaultModel must name a registered model";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.remoteOpenAI.operators must contain at least one user";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.remoteOpenAI.stateDirectory must be below /var/lib";
      }
    ];

    systemd.targets.ai-stack = {
      description = "AI application stack";
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

    systemd.services.local-llama-logger = {
      description = "Payload-logging proxy for the remote OpenAI backend";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        LLAMA_BACKEND = cfg.backendUrl;
        LLAMA_BACKEND_HEALTH_PATH = cfg.backendHealthPath;
        LLAMA_PROXY_HOST = cfg.bindAddress;
        LLAMA_PROXY_PORT = toString cfg.port;
        LLAMA_REQUEST_LOG = cfg.requestLog;
        LLAMA_ALLOWED_MODELS = builtins.toJSON (builtins.attrNames cfg.models);
        LLAMA_UPSTREAM_BEARER_CREDENTIAL = "upstream-bearer-token";
      }
      // lib.optionalAttrs (cfg.bearerCredentialFile != null) {
        LLAMA_BEARER_TOKEN_CREDENTIAL = "caller-bearer-token";
        LLAMA_BEARER_CALLER = cfg.bearerCredentialCaller;
      };
      serviceConfig = {
        User = "llama";
        Group = "llama";
        StateDirectory = stateDirectoryName;
        StateDirectoryMode = "0750";
        ExecStartPre = [
          validateUpstream
          prepareLogs
        ];
        ExecStart = "${pkgs.python3}/bin/python3 ${proxy}";
        LoadCredential = [
          "upstream-bearer-token:${cfg.upstreamBearerCredentialFile}"
        ]
        ++ lib.optional (
          cfg.bearerCredentialFile != null
        ) "caller-bearer-token:${cfg.bearerCredentialFile}";
        Restart = "on-failure";
        RestartSec = "2s";
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        const units = ["ai-stack.target", "local-llama-logger.service"];
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
        read -r -a stack_units <<< "$(${pkgs.systemd}/bin/systemctl show --property=Wants --value ai-stack.target)"
        for _ in $(${pkgs.coreutils}/bin/seq 1 200); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}" \
            && ${pkgs.curl}/bin/curl --fail --silent --max-time 1 \
              http://${cfg.bindAddress}:${toString cfg.port}/health >/dev/null; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "AI stack did not become healthy within 200 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-stop" ''
        set -euo pipefail
        read -r -a stack_units <<< "$(${pkgs.systemd}/bin/systemctl show --property=Wants --value ai-stack.target)"
        ${pkgs.systemd}/bin/systemctl stop ai-stack.target
        for _ in $(${pkgs.coreutils}/bin/seq 1 150); do
          all_stopped=true
          for unit in "''${stack_units[@]}"; do
            state="$(${pkgs.systemd}/bin/systemctl is-active "$unit" || true)"
            if [ "$state" != inactive ] && [ "$state" != failed ]; then
              all_stopped=false
              break
            fi
          done
          if [ "$all_stopped" = true ]; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.2
        done
        echo "AI services did not stop within 30 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-health" ''
        set -euo pipefail
        read -r -a stack_units <<< "$(${pkgs.systemd}/bin/systemctl show --property=Wants --value ai-stack.target)"
        ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}"
        exec ${pkgs.curl}/bin/curl --fail --silent --show-error \
          http://${cfg.bindAddress}:${toString cfg.port}/health
      '')
      (pkgs.writeShellScriptBin "ai-usage-summary" ''
        export LLAMA_REQUEST_LOG=${lib.escapeShellArg cfg.requestLog}
        exec ${pkgs.python3}/bin/python3 ${usageSummary} "$@"
      '')
      (pkgs.writeShellScriptBin "ai-eval" ''
        export PATH=${
          lib.makeBinPath [
            pkgs.git
            pkgs.coreutils
            pkgs.bash
          ]
        }:"$PATH"
        exec ${pkgs.python3}/bin/python3 ${evalRunner} "$@"
      '')
      (pkgs.writeShellScriptBin "ai-eval-harvest" ''
        export PATH=${lib.makeBinPath [ pkgs.git ]}:"$PATH"
        exec ${pkgs.python3}/bin/python3 ${evalHarvester} "$@"
      '')
    ];
  };
}
