{
  config,
  lib,
  username,
  ...
}:

let
  secretFile = ../../secrets/alucard-ai.yaml;
in
{
  imports = [
    ../../ai/nixos/ai-stack.nix
    ../../ai/nixos/requesty.nix
  ];

  assertions = [
    {
      assertion = config.services.localN8n.bindAddress == "127.0.0.1";
      message = "Alucard AI services must remain loopback-only; use Tailscale Serve";
    }
    {
      assertion =
        lib.intersectLists [
          5678
          8642
          9119
          13000
          13001
          18081
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
        "requesty/hermes_api_key"
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
      })
    // {
      # This host's interactive clients (Pi, OMP) use their own key.
      "requesty/api_key" = {
        sopsFile = secretFile;
        owner = username;
        mode = "0400";
      };
    };

  services.requesty.apiKeyFile = config.sops.secrets."requesty/api_key".path;

  # Initial credentials; anything saved in the Hermes UI overrides them.
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
      REQUESTY_API_KEY=${config.sops.placeholder."requesty/hermes_api_key"}
    '';
    restartUnits = [ "docker-hermes-agent.service" ];
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.aiStack = {
    user = username;
    enable = true;
    sharedDirectory = {
      path = "/home/${username}/org";
      mountPoint = "/org";
      owner = username;
    };
    secretsFile = secretFile;
  };

  # Alucard is the central monitoring server and the canary customer host.
  services.observability = {
    exporters.enable = true;
    server = {
      enable = true;
      secretsFile = secretFile;
      localTargets.n8n = 5678;
    };
  };

  # Keep the identity existing files and the Org ACL already use.
  services.hermesAgent = {
    uid = 985;
    gid = 981;
    environmentFiles = [ config.sops.templates."hermes.env".path ];
  };
}
