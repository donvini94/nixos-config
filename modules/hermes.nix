{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.localHermes;
  hermesPackage = cfg.package.override {
    extraDependencyGroups = cfg.extraDependencyGroups;
  };
  hermesHome = "${cfg.stateDirectory}/.hermes";

  serviceHardening = {
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ProtectSystem = "strict";
    ProtectHome = lib.mkForce true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectHostname = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    RemoveIPC = true;
    KeyringMode = "private";
    ProtectProc = "invisible";
    ProcSubset = "pid";
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
    TasksMax = 512;
    MemoryMax = "8G";
  };

  workspaceInit = pkgs.writeShellScript "hermes-workspace-init" ''
    set -euo pipefail
    workspace=${lib.escapeShellArg cfg.workspace}

    if [ ! -d "$workspace/.git" ]; then
      ${pkgs.git}/bin/git -C "$workspace" init --initial-branch=main
      ${pkgs.git}/bin/git -C "$workspace" config user.name "Hermes Agent"
      ${pkgs.git}/bin/git -C "$workspace" config user.email "hermes@localhost"
      ${pkgs.git}/bin/git -C "$workspace" add --all
      ${pkgs.git}/bin/git -C "$workspace" commit --allow-empty --message "chore: initialize Hermes sandbox"
    fi
  '';
  modelMetadataRefresh = pkgs.writeShellScript "hermes-model-metadata-refresh" ''
    set -euo pipefail
    models_target=${lib.escapeShellArg "${hermesHome}/models_dev_cache.json"}
    catalog_target=${lib.escapeShellArg "${hermesHome}/cache/model_catalog.json"}
    models_temporary="$models_target.new"
    catalog_temporary="$catalog_target.new"
    trap '${pkgs.coreutils}/bin/rm -f "$models_temporary" "$catalog_temporary"' EXIT

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$catalog_target")"
    ${pkgs.curl}/bin/curl \
      --fail --silent --show-error --location --max-time 30 \
      https://models.dev/api.json --output "$models_temporary"
    ${lib.getExe pkgs.jq} -e 'type == "object" and length > 0' "$models_temporary" >/dev/null
    ${pkgs.coreutils}/bin/chmod 0600 "$models_temporary"
    ${pkgs.coreutils}/bin/mv "$models_temporary" "$models_target"

    catalog_valid() {
      ${lib.getExe pkgs.jq} -e '
        (.version | type == "number" and . >= 1 and . <= 1)
        and (.providers | type == "object")
        and all(.providers[]; .models | type == "array")
      ' "$catalog_temporary" >/dev/null
    }

    if ! ${pkgs.curl}/bin/curl \
      --fail --silent --show-error --location --max-time 8 \
      https://hermes-agent.nousresearch.com/docs/api/model-catalog.json \
      --output "$catalog_temporary" || ! catalog_valid; then
      if ! ${pkgs.curl}/bin/curl \
        --fail --silent --show-error --location --max-time 8 \
        https://raw.githubusercontent.com/NousResearch/hermes-agent/main/website/static/api/model-catalog.json \
        --output "$catalog_temporary" || ! catalog_valid; then
        ${pkgs.coreutils}/bin/cp \
          ${inputs.hermes-agent}/website/static/api/model-catalog.json \
          "$catalog_temporary"
      fi
    fi
    ${pkgs.coreutils}/bin/chmod 0600 "$catalog_temporary"
    ${pkgs.coreutils}/bin/mv "$catalog_temporary" "$catalog_target"
    trap - EXIT
  '';
  hermesTui = pkgs.writeShellApplication {
    name = "hermes-tui";
    text = ''
      exec ${config.security.wrapperDir}/sudo -H -u hermes \
        ${pkgs.coreutils}/bin/env --chdir=${lib.escapeShellArg cfg.workspace} \
        ${lib.getExe hermesPackage} --tui "$@"
    '';
  };
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  options.services.localHermes = {
    enable = lib.mkEnableOption "isolated local Hermes Agent worker";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
      defaultText = lib.literalExpression "inputs.hermes-agent.packages.\${pkgs.system}.minimal";
      description = "Pinned upstream Hermes Agent package.";
    };

    extraDependencyGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional upstream Hermes optional dependency groups.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-27b-local";
    };

    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 65536;
      description = "Context advertised to Hermes; upstream requires at least 64,000 tokens.";
    };

    ingressUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080/v1";
    };

    proxyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional HTTPS egress proxy for messaging adapters and onboarding.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
    };

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.stateDirectory}/workspace";
    };

    dashboard = {
      enable = lib.mkEnableOption "loopback-only Hermes web dashboard" // {
        default = true;
      };
      bindAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional root-only dashboard authentication environment file.";
      };
    };

    operators = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users allowed to inspect the Hermes state and workspace.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.contextLength >= 64000;
        message = "services.localHermes.contextLength must satisfy Hermes' 64,000-token minimum";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.stateDirectory;
        message = "services.localHermes.stateDirectory must be below /var/lib";
      }
      {
        assertion = lib.hasPrefix "${cfg.stateDirectory}/" cfg.workspace;
        message = "services.localHermes.workspace must be below its isolated state directory";
      }
      {
        assertion = cfg.operators != [ ];
        message = "services.localHermes.operators must contain at least one user";
      }
    ];

    users.users = lib.genAttrs cfg.operators (_: {
      extraGroups = [ "hermes" ];
    });

    services.hermes-agent = {
      enable = true;
      package = cfg.package;
      inherit (cfg) extraDependencyGroups;
      stateDir = cfg.stateDirectory;
      workingDirectory = cfg.workspace;
      addToSystemPackages = false;
      # Hermes' dashboard restarts the gateway by sending it a clean SIGTERM.
      # Keep the upstream supervisor semantics so systemd brings it back.
      restart = "always";
      restartSec = 3;
      extraPackages = with pkgs; [
        findutils
        jq
        ripgrep
      ];

      settings = {
        database.journal_mode = "wal";

        providers."dracula-local" = {
          api = cfg.ingressUrl;
          default_model = cfg.model;
          transport = "chat_completions";
          discover_models = true;
          extra_headers.X-AI-Caller = "hermes";
          models."${cfg.model}".context_length = cfg.contextLength;
        };

        model = {
          default = cfg.model;
          provider = "custom:dracula-local";
          base_url = cfg.ingressUrl;
          context_length = cfg.contextLength;
          default_headers.X-AI-Caller = "hermes";
        };

        terminal = {
          backend = "local";
          cwd = cfg.workspace;
          home_mode = "profile";
          timeout = 300;
        };

        platform_toolsets.cli = [
          "terminal"
          "file"
          "skills"
          "todo"
          "memory"
          "session_search"
          "cronjob"
        ];

        agent.disabled_toolsets = [
          "web"
          "browser"
          "vision"
          "image_gen"
          "tts"
        ];

        approvals = {
          mode = "manual";
          timeout = 300;
          cron_mode = "deny";
          mcp_reload_confirm = true;
          destructive_slash_confirm = true;
          deny = [
            "git push*"
            "*curl*|*sh*"
            "*wget*|*sh*"
          ];
        };

        onboarding.profile_build = "off";
        dashboard.show_token_analytics = true;
      };

      documents = {
        "AGENTS.md" = ../hermes/workspace/AGENTS.md;
        "SOUL.md" = ../hermes/workspace/SOUL.md;
      };
    };

    systemd.services.hermes-workspace-init = {
      description = "Initialize the isolated Hermes Agent git workspace";
      before = [
        "hermes-agent.service"
        "hermes-dashboard.service"
      ];
      requiredBy = [ "hermes-agent.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
        Group = "hermes";
        WorkingDirectory = cfg.workspace;
        ExecStart = workspaceInit;
        PrivateNetwork = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.workspace ];
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };

    # The upstream NixOS module marks the whole state directory immutable to
    # Hermes. That also blocks the supported dashboard channel onboarding flow
    # from saving runtime credentials and enable flags. The gateway itself
    # retains HERMES_MANAGED=true; only operator-facing clients may change
    # runtime settings, while Nix-defined config keys continue to win on every
    # rebuild through the upstream merge activation.
    system.activationScripts.hermes-runtime-settings = lib.stringAfter [ "hermes-agent-setup" ] ''
      rm -f ${hermesHome}/.managed
    '';

    # Hermes' picker uses models.dev plus its own curated catalog. Fetch both in
    # a narrow service so the dashboard and child agent retain loopback-only
    # network access. The pinned upstream catalog is the offline fallback.
    systemd.services.hermes-model-metadata = {
      description = "Refresh Hermes model metadata without granting agent egress";
      wantedBy = [ "ai-stack.target" ];
      before = [ "hermes-dashboard.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
        Group = "hermes";
        ExecStart = modelMetadataRefresh;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        ReadWritePaths = [ hermesHome ];
        UMask = "0077";
      };
    };

    systemd.timers.hermes-model-metadata = {
      description = "Refresh Hermes model metadata daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };

    systemd.services.hermes-agent = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after =
        [
          "hermes-workspace-init.service"
          "local-llama-logger.service"
        ]
        ++ lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      wants = lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      requires = [
        "hermes-workspace-init.service"
        "local-llama-logger.service"
      ];
      # Keep process controls outside the upstream module's managed .env.
      # Dashboard QR onboarding owns runtime messaging credentials there;
      # declarative rebuilds must preserve them.
      environment =
        {
          HERMES_WRITE_SAFE_ROOT = "${cfg.workspace}:${hermesHome}";
        }
        // lib.optionalAttrs (cfg.proxyUrl != null) {
          HTTPS_PROXY = cfg.proxyUrl;
          https_proxy = cfg.proxyUrl;
          TELEGRAM_PROXY = cfg.proxyUrl;
          NO_PROXY = "127.0.0.1,localhost";
          no_proxy = "127.0.0.1,localhost";
        };
      serviceConfig = serviceHardening // {
        ReadWritePaths = [
          cfg.stateDirectory
          cfg.workspace
        ];
      };
    };

    systemd.services.hermes-dashboard = lib.mkIf cfg.dashboard.enable {
      description = "Hermes Agent local web dashboard";
      wantedBy = [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "hermes-workspace-init.service"
        "hermes-agent.service"
      ] ++ lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      wants = lib.optional (cfg.proxyUrl != null) "tinyproxy.service";
      requires = [ "hermes-workspace-init.service" ];
      restartTriggers = [ modelMetadataRefresh ];
      environment =
        {
          HOME = cfg.stateDirectory;
          HERMES_HOME = hermesHome;
        }
        // lib.optionalAttrs (cfg.proxyUrl != null) {
          HTTPS_PROXY = cfg.proxyUrl;
          https_proxy = cfg.proxyUrl;
          NO_PROXY = "127.0.0.1,localhost";
          no_proxy = "127.0.0.1,localhost";
        };
      path = [
        hermesPackage
        pkgs.bash
        pkgs.coreutils
        pkgs.git
      ];
      serviceConfig =
        serviceHardening
        // {
          Type = "simple";
          User = "hermes";
          Group = "hermes";
          WorkingDirectory = cfg.workspace;
          ExecStart = "${hermesPackage}/bin/hermes dashboard --host ${cfg.dashboard.bindAddress} --port ${toString cfg.dashboard.port} --no-open";
          Restart = "on-failure";
          RestartSec = 3;
          UMask = "0007";
          ReadWritePaths = [
            cfg.stateDirectory
            cfg.workspace
          ];
        }
        // lib.optionalAttrs (cfg.dashboard.environmentFile != null) {
          EnvironmentFile = cfg.dashboard.environmentFile;
        };
    };

    environment.systemPackages = [ hermesTui ];
  };
}
