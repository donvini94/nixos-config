{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  requesty = import ../../lib/requesty.nix;
  hermes = import ../../lib/hermes-agent.nix;
  inherit (requesty) defaultModel;
  secretFile = ../../secrets/alucard-ai.yaml;
  hermesProxyPort = 18084;
  hermesProxyUrl = "http://127.0.0.1:${toString hermesProxyPort}";
  hermesEgressAllowlist = pkgs.writeText "hermes-egress-allowlist" (
    lib.concatMapStringsSep "\n" (
      host: "^${lib.escapeRegex host}$"
    ) config.services.aiStack.hermes.egressHosts
    + "\n"
  );
in
{
  imports = [
    ../../modules/ai-stack.nix
    ../../modules/remote-openai.nix
  ];

  assertions = [
    {
      assertion = lib.all (address: address == "127.0.0.1") [
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

  sops.secrets =
    lib.genAttrs
      [
        "requesty/api_key"
        "hermes/dashboard_password"
        "hermes/dashboard_password_hash"
        "hermes/dashboard_session_secret"
        "hermes/telegram_bot_token"
        # Comma-separated numeric Telegram IDs; never "*", never allow-all.
        "hermes/telegram_allowed_users"
      ]
      (_: {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      });

  # SOPS owns these secrets: the upstream module rewrites the whole .env on
  # every activation, so dashboard-only edits are dropped.
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
    '';
    restartUnits = [ "hermes-agent.service" ];
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.aiStack = {
    enable = true;
    secretsFile = secretFile;
    hermes = {
      providerName = "alucard-requesty";
      inherit defaultModel;
    };
  };

  services.localObservability = {
    enable = true;
    secretsFile = secretFile;
    inferencePort = 8080;
    n8nPort = 5678;
  };

  services.aiIngress = {
    backendUrl = "https://router.requesty.ai";
    backendHealthPath = "/v1/models";
    upstreamBearerCredentialFile = config.sops.secrets."requesty/api_key".path;
    operators = [ username ];
  };

  services.remoteOpenAI = {
    enable = true;
    inherit defaultModel;
  };

  services.hermes-agent = {
    environment = {
      HTTPS_PROXY = hermesProxyUrl;
      https_proxy = hermesProxyUrl;
      TELEGRAM_PROXY = hermesProxyUrl;
      NO_PROXY = "127.0.0.1,localhost";
      no_proxy = "127.0.0.1,localhost";
    };
    container = {
      # One agent for the trusted founding pair: sessions separate by chat
      # origin, but memory, skills, workspace and /org are shared. The CLI is
      # shared state, not a per-user session boundary. Widening this past two
      # people means deploying separate upstream instances instead.
      hostUsers = [ "kyrill" ];
    };
  };

  # restartTriggers covers .env *shape* changes; the template's restartUnits
  # covers secret-value changes.
  systemd.services.hermes-agent = {
    after = [ "tinyproxy.service" ];
    wants = [ "tinyproxy.service" ];
    restartTriggers = [ config.sops.templates."hermes.env".file ];
  };

  # Messaging and approved MCP package downloads use this domain-filtered proxy.
  # New remote MCP destinations require an explicit host allowlist entry.
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

  nix.settings = {
    extra-substituters = [ "https://hermes-agent.cachix.org" ];
    extra-trusted-public-keys = [
      "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
    ];
  };
}
