# The shared AI ingress on 127.0.0.1:8080: the ai-stack target, the `llama` service
# identity, the logging proxy, log rotation, operator tooling and the polkit rule.
# `modules/llama.nix` and `modules/remote-openai.nix` each supply only a backend.
#
# Every client (OMP, Hermes, n8n) speaks to this one port, so the proxy is
# the only source of caller attribution, token counts, cost and the JSONL audit log.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiIngress;
  # The ingress binds loopback only; it is published with Tailscale Serve.
  bindAddress = "127.0.0.1";
  port = 8080;
  stateDirectory = "/var/lib/llama";
  requestLog = "${stateDirectory}/logs/requests.jsonl";
  logRetention = 14;

  # The proxy needs the Langfuse SDK, so it gets its own interpreter.
  python = pkgs.python3.withPackages (ps: [ ps.langfuse ]);
  proxy = pkgs.writeText "ai-ingress-proxy.py" (builtins.readFile ../ai-ingress/proxy.py);
  usageSummary = pkgs.writeText "ai-usage-summary.py" (
    builtins.readFile ../ai-ingress/usage-summary.py
  );

  prepareLogs = pkgs.writeShellScript "prepare-ai-ingress-logs" ''
    ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg (builtins.dirOf requestLog)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg requestLog}
    ${pkgs.coreutils}/bin/chmod 0640 ${lib.escapeShellArg requestLog}
  '';

  ingressUrl = "http://${bindAddress}:${toString port}";

  # A locally served model has no list price: a zero entry would make every local
  # request report a $0.00 "registry-estimate" instead of an honest "unavailable".
  billablePrices = lib.filterAttrs (_: price: price.input != 0 || price.output != 0) cfg.priceMap;

  # The target's Wants list is the authoritative membership; tooling never hardcodes units.
  readStackUnits = ''
    read -r -a stack_units <<< "$(${pkgs.systemd}/bin/systemctl show --property=Wants --value ai-stack.target)"
  '';
in
{
  options.services.aiIngress = {
    enable = lib.mkEnableOption "the shared loopback AI ingress";

    backendUrl = lib.mkOption {
      type = lib.types.str;
      description = "Upstream origin without the /v1 request path.";
    };

    backendHealthPath = lib.mkOption {
      type = lib.types.str;
      default = "/health";
      description = "Upstream path used by the local /health probe.";
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to inspect request logs and drive ai-stack.target.";
    };

    lifecycleUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ai-stack.target"
        "local-llama-logger.service"
      ];
      description = "Units the operator group may start/stop without root; backends append their own.";
    };

    allowedModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Model allowlist; empty disables filtering (local backends route by name).";
    };

    priceMap = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            input = lib.mkOption { type = lib.types.number; };
            output = lib.mkOption { type = lib.types.number; };
          };
        }
      );
      default = { };
      description = ''
        List prices in USD per million tokens, keyed by model id. Used only to
        compute an independent estimate; provider-reported cost is never
        replaced by it.
      '';
    };

    upstreamBearerCredentialFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Upstream API key injected by the ingress, when the backend needs one.";
    };

    extraPreStart = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Backend-specific ExecStartPre checks, run before the log preparation.";
    };

    extraAfter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional units the ingress must start after.";
    };

    hardened = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Apply filesystem/namespace confinement to the proxy.
      '';
    };

    langfuse = {
      enable = lib.mkEnableOption "Langfuse generation observations from the ingress";

      publicKeyFile = lib.mkOption {
        type = lib.types.path;
        description = "File containing the Langfuse project public key.";
      };

      secretKeyFile = lib.mkOption {
        type = lib.types.path;
        description = "File containing the Langfuse project secret key.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.operators != [ ];
        message = "services.aiIngress.operators must contain at least one user";
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
          home = stateDirectory;
        };
      }
      // lib.genAttrs cfg.operators (_: {
        extraGroups = [ "llama" ];
      });
    };

    systemd.services.local-llama-logger = {
      description = "Payload-logging proxy for the AI ingress";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = cfg.extraAfter;

      environment = {
        LLAMA_BACKEND = cfg.backendUrl;
        LLAMA_BACKEND_HEALTH_PATH = cfg.backendHealthPath;
        LLAMA_PROXY_HOST = bindAddress;
        LLAMA_PROXY_PORT = toString port;
        LLAMA_REQUEST_LOG = requestLog;
        LLAMA_ENVIRONMENT = config.networking.hostName;
        LLAMA_PRICE_MAP = builtins.toJSON billablePrices;
      }
      // lib.optionalAttrs (cfg.allowedModels != [ ]) {
        LLAMA_ALLOWED_MODELS = builtins.toJSON cfg.allowedModels;
      }
      // lib.optionalAttrs (cfg.upstreamBearerCredentialFile != null) {
        LLAMA_UPSTREAM_BEARER_CREDENTIAL = "upstream-bearer-token";
      }
      // lib.optionalAttrs cfg.langfuse.enable {
        LANGFUSE_BASE_URL = "http://127.0.0.1:13000";
        LANGFUSE_PUBLIC_KEY_CREDENTIAL = "langfuse-public-key";
        LANGFUSE_SECRET_KEY_CREDENTIAL = "langfuse-secret-key";
      };

      serviceConfig = {
        User = "llama";
        Group = "llama";
        StateDirectory = "llama";
        StateDirectoryMode = "0750";
        ExecStartPre = cfg.extraPreStart ++ [ prepareLogs ];
        ExecStart = "${python}/bin/python3 ${proxy}";
        LoadCredential =
          lib.optional (
            cfg.upstreamBearerCredentialFile != null
          ) "upstream-bearer-token:${cfg.upstreamBearerCredentialFile}"
          ++ lib.optionals cfg.langfuse.enable [
            "langfuse-public-key:${cfg.langfuse.publicKeyFile}"
            "langfuse-secret-key:${cfg.langfuse.secretKeyFile}"
          ];
        Restart = "on-failure";
        RestartSec = "2s";
        UMask = "0027";
      }
      // lib.optionalAttrs cfg.hardened {
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

    # Inert unless polkit itself runs; servers do not enable it by default, which
    # leaves ai-stack-{start,stop} root-only.
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        const units = ${builtins.toJSON cfg.lifecycleUnits};
        const verbs = ["start", "stop", "restart", "kill"];
        if (action.id === "org.freedesktop.systemd1.manage-units"
            && subject.isInGroup("llama")
            && units.indexOf(action.lookup("unit")) !== -1
            && verbs.indexOf(action.lookup("verb")) !== -1) {
          return polkit.Result.YES;
        }
      });
    '';

    services.logrotate.settings.${requestLog} = {
      daily = true;
      size = "1G";
      rotate = logRetention;
      compress = true;
      missingok = true;
      notifempty = true;
      copytruncate = true;
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ai-stack-start" ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl start ai-stack.target
        ${readStackUnits}
        for _ in $(${pkgs.coreutils}/bin/seq 1 200); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}" \
            && ${pkgs.curl}/bin/curl --fail --silent --max-time 1 ${ingressUrl}/health >/dev/null; then
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "AI stack did not become healthy within 200 seconds" >&2
        exit 1
      '')
      (pkgs.writeShellScriptBin "ai-stack-stop" ''
        set -euo pipefail
        ${readStackUnits}
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
        ${readStackUnits}
        ${pkgs.systemd}/bin/systemctl is-active --quiet ai-stack.target "''${stack_units[@]}"
        exec ${pkgs.curl}/bin/curl --fail --silent --show-error ${ingressUrl}/health
      '')
      (pkgs.writeShellScriptBin "ai-usage-summary" ''
        export LLAMA_REQUEST_LOG=${lib.escapeShellArg requestLog}
        exec ${python}/bin/python3 ${usageSummary} "$@"
      '')
    ];
  };
}
