# The single AI ingress both hosts expose at 127.0.0.1:8080.
#
# Dracula points it at local llama-swap, Alucard at Requesty. Everything that
# is identical between them lives here: the systemd target, the `llama` service
# identity, the logging proxy, log rotation, operator tooling, and the polkit
# rule that lets operators drive the stack without root. `modules/llama.nix`
# and `modules/remote-openai.nix` now only acquire their respective backends
# and point this module at one.
#
# The proxy is the single source of truth for caller attribution, token counts,
# latency, cost, the JSONL audit log, Prometheus metrics, and Langfuse
# generation observations — every client (OMP, OpenCode, Hermes, n8n) is
# covered because they all speak to this one port.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aiIngress;
  stateDirectoryName = lib.removePrefix "/var/lib/" cfg.stateDirectory;

  # The proxy needs the Langfuse SDK, so it gets its own interpreter rather
  # than the bare python3 the rest of the system uses. Keeping the SDK here
  # instead of inside Hermes is deliberate: instrumentation belongs to the
  # ingress, which sees every client.
  python = pkgs.python3.withPackages (ps: [ ps.langfuse ]);
  proxy = pkgs.writeText "ai-ingress-proxy.py" (builtins.readFile ../ai-ingress/proxy.py);
  usageSummary = pkgs.writeText "ai-usage-summary.py" (
    builtins.readFile ../ai-ingress/usage-summary.py
  );

  prepareLogs = pkgs.writeShellScript "prepare-ai-ingress-logs" ''
    ${pkgs.coreutils}/bin/install -d -m 0750 ${lib.escapeShellArg (builtins.dirOf cfg.requestLog)}
    ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg cfg.requestLog}
    ${pkgs.coreutils}/bin/chmod 0640 ${lib.escapeShellArg cfg.requestLog}
  '';

  ingressUrl = "http://${cfg.bindAddress}:${toString cfg.port}";

  # A locally served model has no list price. Emitting a zero entry would make
  # every local request report a $0.00 "registry-estimate" instead of the
  # honest "unavailable", so zero-priced models are dropped from the map.
  billablePrices = lib.filterAttrs (_: price: price.input != 0 || price.output != 0) cfg.priceMap;

  # Shared by ai-stack-start and ai-stack-health: the target's Wants list is
  # the authoritative membership, so tooling never hardcodes unit names.
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

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Ingress bind address; loopback is a hard requirement.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Stable ingress port every AI client is configured against.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama";
    };

    requestLog = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDirectory}/logs/requests.jsonl";
    };

    logRetention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "Rotated request-log files retained.";
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

    environmentLabel = lib.mkOption {
      type = lib.types.str;
      description = "Host label recorded on every request and Langfuse observation.";
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
        Apply filesystem/namespace confinement to the proxy. Disabled for the
        local backend, whose model downloads and llama-swap handoff need paths
        outside the confined view.
      '';
    };

    langfuse = {
      enable = lib.mkEnableOption "Langfuse generation observations from the ingress";

      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:13000";
        description = "Self-hosted Langfuse ingestion endpoint.";
      };

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
        assertion = cfg.bindAddress == "127.0.0.1";
        message = "services.aiIngress must stay on loopback; publish it with Tailscale Serve";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.aiIngress.operators must contain at least one user";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.aiIngress.stateDirectory must be below /var/lib";
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
      description = "Payload-logging proxy for the AI ingress";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = cfg.extraAfter;

      environment = {
        LLAMA_BACKEND = cfg.backendUrl;
        LLAMA_BACKEND_HEALTH_PATH = cfg.backendHealthPath;
        LLAMA_PROXY_HOST = cfg.bindAddress;
        LLAMA_PROXY_PORT = toString cfg.port;
        LLAMA_REQUEST_LOG = cfg.requestLog;
        LLAMA_ENVIRONMENT = cfg.environmentLabel;
        LLAMA_PRICE_MAP = builtins.toJSON billablePrices;
      }
      // lib.optionalAttrs (cfg.allowedModels != [ ]) {
        LLAMA_ALLOWED_MODELS = builtins.toJSON cfg.allowedModels;
      }
      // lib.optionalAttrs (cfg.upstreamBearerCredentialFile != null) {
        LLAMA_UPSTREAM_BEARER_CREDENTIAL = "upstream-bearer-token";
      }
      // lib.optionalAttrs cfg.langfuse.enable {
        LANGFUSE_BASE_URL = cfg.langfuse.baseUrl;
        LANGFUSE_PUBLIC_KEY_CREDENTIAL = "langfuse-public-key";
        LANGFUSE_SECRET_KEY_CREDENTIAL = "langfuse-secret-key";
      };

      serviceConfig = {
        User = "llama";
        Group = "llama";
        StateDirectory = stateDirectoryName;
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

    # Inert unless polkit itself runs; servers do not enable it by default,
    # which silently made ai-stack-{start,stop} root-only.
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
        export LLAMA_REQUEST_LOG=${lib.escapeShellArg cfg.requestLog}
        exec ${python}/bin/python3 ${usageSummary} "$@"
      '')
    ];
  };
}
