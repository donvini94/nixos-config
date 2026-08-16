{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  enableAI = true;
  requesty = import ../../lib/requesty-models.nix;
  hermes = import ../../lib/hermes-agent.nix;
  hermesN8nHandoff = pkgs.callPackage ../../packages/hermes-n8n-handoff.nix { };
  # Both founders drive the same agent from their own host accounts. The CLI is
  # intentionally shared state, not a per-user session boundary.
  hermesUsers = [
    username
    "kyrill"
  ];
  inherit (requesty) defaultModel models;
  secretFile = ../../secrets/alucard-ai.yaml;
  hermesProxyPort = 18084;
  hermesProxyUrl = "http://127.0.0.1:${toString hermesProxyPort}";
  hermesEgressAllowlist = pkgs.writeText "hermes-egress-allowlist" ''
    ^api\.telegram\.org$
    ^setup\.hermes-agent\.nousresearch\.com$
  '';
in
{
  imports = [
    ../../modules/ai-ingress.nix
    ../../modules/remote-openai.nix
    ../../modules/n8n.nix
    ../../modules/n8n-credentials.nix
    ../../modules/hermes-dashboard.nix
  ];

  config = lib.mkIf enableAI {
    assertions = [
      {
        assertion = lib.all (address: address == "127.0.0.1") [
          config.services.remoteOpenAI.bindAddress
          config.services.localN8n.bindAddress
          config.services.localObservability.bindAddress
        ];
        message = "Alucard AI services must remain loopback-only; use Tailscale Serve";
      }
      {
        # The upstream module has no bind-address option: Hermes reads these
        # from .env, so the loopback guarantee lives in the rendered values.
        assertion =
          hermes.runtimeEnv.HERMES_DASHBOARD_HOST == "127.0.0.1"
          && hermes.runtimeEnv.API_SERVER_HOST == "127.0.0.1";
        message = "Alucard Hermes dashboard and API must stay loopback-only; use Tailscale Serve";
      }
      {
        assertion =
          lib.intersectLists [
            5678
            8080
            8642
            9119
            13000
            13001
            18081
            hermesProxyPort
            19000
            19091
            19100
            19991
          ] config.networking.firewall.allowedTCPPorts == [ ];
        message = "Alucard AI ports must not be opened on the global firewall";
      }
    ];

    sops.secrets = {
      "requesty/api_key" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "n8n/encryption_key" = {
        sopsFile = secretFile;
        owner = username;
        mode = "0400";
      };
      "n8n/runner_auth_token" = {
        sopsFile = secretFile;
        owner = username;
        mode = "0400";
      };
      # Shared by the n8n webhook credential and Hermes' handoff command; the
      # two must agree or the inbox rejects Hermes with 403.
      "n8n/webhook_token" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "hermes/dashboard_password" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "hermes/dashboard_password_hash" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "hermes/dashboard_session_secret" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "hermes/api_server_key" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "hermes/telegram_bot_token" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      # Comma-separated numeric Telegram IDs. Structurally multi-value: append
      # the second founder's ID when it is known. Never "*", never allow-all.
      "hermes/telegram_allowed_users" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
    }
    //
      lib.genAttrs
        [
          "langfuse/postgres_password"
          "langfuse/clickhouse_password"
          "langfuse/redis_auth"
          "langfuse/minio_root_password"
          "langfuse/salt"
          "langfuse/encryption_key"
          "langfuse/nextauth_secret"
          "langfuse/project_public_key"
          "langfuse/project_secret_key"
          "langfuse/admin_password"
          "grafana/admin_password"
        ]
        (_: {
          sopsFile = secretFile;
          owner = "root";
          mode = "0400";
        });

    sops.templates."n8n-runner.env" = {
      content = ''
        N8N_RUNNERS_AUTH_TOKEN=${config.sops.placeholder."n8n/runner_auth_token"}
      '';
      restartUnits = [ "docker-n8n-runners.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Nix/SOPS is authoritative for the whole secret half of Hermes' .env: the
    # upstream module rewrites that file on every activation instead of
    # reconciling single keys, so anything only stored by the dashboard would be
    # dropped. Telegram credentials were migrated out of the live container's
    # .env on 2026-08-16. Edit SOPS, never the dashboard.
    sops.templates."hermes.env" = {
      content = ''
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=demo
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=${
          config.sops.placeholder."hermes/dashboard_password_hash"
        }
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes/dashboard_session_secret"}
        API_SERVER_KEY=${config.sops.placeholder."hermes/api_server_key"}
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes/telegram_bot_token"}
        TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes/telegram_allowed_users"}
        N8N_WEBHOOK_TOKEN=${config.sops.placeholder."n8n/webhook_token"}
      '';
      restartUnits = [ "hermes-agent.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Upstream wants multi-user.target; this stack is gated behind
    # ai-stack.target and must not start before the ingress it talks to.
    # restartTriggers covers .env *shape* changes; the template's restartUnits
    # covers secret-value changes.
    systemd.services.hermes-agent = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [
        "local-llama-logger.service"
        "tinyproxy.service"
      ];
      requires = [ "local-llama-logger.service" ];
      wants = [ "tinyproxy.service" ];
      restartTriggers = [ config.sops.templates."hermes.env".file ];
    };

    sops.templates."observability.env" = {
      content = ''
        POSTGRES_PASSWORD=${config.sops.placeholder."langfuse/postgres_password"}
        CLICKHOUSE_PASSWORD=${config.sops.placeholder."langfuse/clickhouse_password"}
        REDIS_AUTH=${config.sops.placeholder."langfuse/redis_auth"}
        MINIO_ROOT_PASSWORD=${config.sops.placeholder."langfuse/minio_root_password"}
        LANGFUSE_SALT=${config.sops.placeholder."langfuse/salt"}
        LANGFUSE_ENCRYPTION_KEY=${config.sops.placeholder."langfuse/encryption_key"}
        NEXTAUTH_SECRET=${config.sops.placeholder."langfuse/nextauth_secret"}
        LANGFUSE_PROJECT_PUBLIC_KEY=${config.sops.placeholder."langfuse/project_public_key"}
        LANGFUSE_PROJECT_SECRET_KEY=${config.sops.placeholder."langfuse/project_secret_key"}
        LANGFUSE_INIT_USER_EMAIL=vincenzo@istbereit.de
        LANGFUSE_INIT_USER_NAME=Vincenzo
        LANGFUSE_INIT_USER_PASSWORD=${config.sops.placeholder."langfuse/admin_password"}
        GRAFANA_ADMIN_PASSWORD=${config.sops.placeholder."grafana/admin_password"}
      '';
      restartUnits = [ "observability-stack.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    sops.templates."opencode-langfuse.json" = {
      content = builtins.toJSON {
        publicKey = config.sops.placeholder."langfuse/project_public_key";
        secretKey = config.sops.placeholder."langfuse/project_secret_key";
        baseUrl = "http://127.0.0.1:13000";
        environment = "alucard";
        userId = username;
      };
      mode = "0400";
      owner = username;
      group = "users";
    };

    services.remoteOpenAI = {
      enable = true;
      backendUrl = "https://router.requesty.ai";
      backendHealthPath = "/v1/models";
      upstreamBearerCredentialFile = config.sops.secrets."requesty/api_key".path;
      inherit models defaultModel;
      operators = [ username ];
    };

    # Ingress-level tracing is the cross-client view: OMP, OpenCode, Hermes and
    # n8n all traverse this one proxy. OpenCode's own plugin adds nested
    # agent/tool spans on top; the two are never summed for billing.
    services.aiIngress.langfuse = {
      enable = true;
      publicKeyFile = config.sops.secrets."langfuse/project_public_key".path;
      secretKeyFile = config.sops.secrets."langfuse/project_secret_key".path;
    };

    # Hermes runs as its own service identity inside a container and reaches
    # the Org tree only through this inherited ACL.
    systemd.tmpfiles.rules = [
      "A+ /home/${username}/org - - - - u:hermes:rwX,d:u:hermes:rwx"
    ];

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      runnerAuthTokenFile = config.sops.secrets."n8n/runner_auth_token".path;
      runnerEnvironmentFile = config.sops.templates."n8n-runner.env".path;
      operators = [ username ];
      orgDirectory = "/home/${username}/org";
      hermesApiPort = 8642;
      workflowDirectory = ../../n8n/workflows/alucard;
    };

    # Both credentials are provisioned by n8n's own CLI so they land encrypted
    # in n8n's database; the values exist only in SOPS and systemd credentials.
    services.n8nCredentials = {
      enable = true;
      hermesApiKeyFile = config.sops.secrets."hermes/api_server_key".path;
      webhookTokenFile = config.sops.secrets."n8n/webhook_token".path;
    };

    # One agent for the trusted founding pair. Sessions separate by chat origin;
    # memory, skills, workspace and /org are shared on purpose. This is a
    # two-person team boundary, not customer multi-tenancy — if that ever
    # changes, deploy separate upstream instances instead of widening this one.
    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      settings = hermes.mkSettings {
        providerName = "alucard-requesty";
        inherit defaultModel;
        ingressUrl = "http://127.0.0.1:8080/v1";
        contextLength = models.${defaultModel}.context;
      };
      documents = {
        "AGENTS.md" = ../../hermes/workspace/AGENTS.md;
        "SOUL.md" = ../../hermes/workspace/SOUL.md;
      };
      environment = hermes.runtimeEnv // {
        # Supported messaging adapters egress through the domain-filtered proxy.
        HTTPS_PROXY = hermesProxyUrl;
        https_proxy = hermesProxyUrl;
        TELEGRAM_PROXY = hermesProxyUrl;
        NO_PROXY = "127.0.0.1,localhost";
        no_proxy = "127.0.0.1,localhost";
      };
      environmentFiles = [ config.sops.templates."hermes.env".path ];
      extraPackages = [ hermesN8nHandoff ];
      container = {
        enable = true;
        backend = "docker";
        image = hermes.image;
        hostUsers = hermesUsers;
        extraVolumes = [ "/home/${username}/org:/org:rw" ];
        # extraPackages only reaches the host profile and the native unit's
        # PATH; in container mode the agent's PATH comes from the image, so the
        # handoff command has to be named explicitly. The store is already
        # mounted read-only, so no extra volume is needed.
        extraOptions = hermes.containerOptions ++ [
          "--env"
          "PATH=${hermesN8nHandoff}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

    services.hermesDashboard.enable = true;

    # Supported Hermes messaging adapters use this domain-filtered proxy.
    # Agent policy separately limits tool-driven network calls to approved
    # localhost n8n webhooks.
    services.tinyproxy = {
      enable = true;
      settings = {
        Port = hermesProxyPort;
        Listen = "127.0.0.1";
        Allow = [ "127.0.0.1" ];
        Timeout = 120;
        MaxClients = 32;
        ConnectPort = 443;
        Filter = hermesEgressAllowlist;
        FilterType = "ere";
        FilterDefaultDeny = true;
        LogLevel = "Warning";
        Syslog = true;
      };
    };

    systemd.services.tinyproxy.serviceConfig = {
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };

    services.localObservability = {
      enable = true;
      environmentFile = config.sops.templates."observability.env".path;
      gpuMetrics = false;
      inferencePort = 8080;
      n8nPort = 5678;
      hostLabel = "alucard";
    };

    services.containerUpdates.units = [
      "docker-n8n.service"
      "docker-n8n-runners.service"
    ];

    nix.settings = {
      substituters = [ "https://hermes-agent.cachix.org" ];
      trusted-public-keys = [
        "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
      ];
    };
  };
}
