# n8n and Hermes with their secrets, grouped under ai-stack.target. `secretsFile` must
# hold the keys listed in ai/secrets.example.yaml.
{
  config,
  lib,
  ...
}:

let
  cfg = config.services.aiStack;
  sharedMount = lib.mapNullable (shared: {
    hostPath = shared.path;
    inherit (shared) mountPoint;
  }) cfg.sharedDirectory;
  # The n8n image runs as `node`, UID 1000; secret files it reads must belong to that UID.
  n8nUid = 1000;
  secret =
    attrs:
    {
      sopsFile = cfg.secretsFile;
      mode = "0400";
    }
    // attrs;
  hermesSecrets = [
    "requesty/api_key"
    "hermes/api_server_key"
    "hermes/dashboard_password_hash"
    "hermes/dashboard_session_secret"
  ]
  ++ lib.optionals cfg.hermes.telegram [
    "hermes/telegram_bot_token"
    # Comma-separated numeric Telegram IDs; never "*", never allow-all.
    "hermes/telegram_allowed_users"
  ];
  placeholder = name: config.sops.placeholder.${name};
in
{
  imports = [
    ./n8n.nix
    ./hermes.nix
  ];

  options.services.aiStack = {
    enable = lib.mkEnableOption "n8n and Hermes";

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS file holding the stack's secrets.";
    };

    hermes = {
      dashboardUser = lib.mkOption {
        type = lib.types.str;
        default = "operator";
        description = "Initial dashboard login; the UI can change it.";
      };

      telegram = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Configure Hermes' Telegram gateway from the secrets file.";
      };
    };

    sharedDirectory = lib.mkOption {
      default = null;
      description = "Optional host directory n8n and Hermes both read and write.";
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.str; };
            mountPoint = lib.mkOption {
              type = lib.types.str;
              default = "/shared";
              description = "Where both containers see the directory.";
            };
            owner = lib.mkOption { type = lib.types.str; };
            group = lib.mkOption {
              type = lib.types.str;
              default = "users";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          lib.intersectLists [
            5678
            5679
            8642
            9119
          ] config.networking.firewall.allowedTCPPorts == [ ];
        message = "n8n and Hermes ports must not be opened on the global firewall";
      }
    ];

    sops.secrets = {
      # Not restarted on change: a new key needs n8n's export/import migration.
      "n8n/encryption_key" = secret { uid = n8nUid; };
      "n8n/runner_auth_token" = secret {
        uid = n8nUid;
        restartUnits = [ "docker-n8n.service" ];
      };
    }
    // lib.genAttrs hermesSecrets (_: secret { owner = "root"; });

    sops.templates."n8n-runner.env" = {
      content = ''
        N8N_RUNNERS_AUTH_TOKEN=${placeholder "n8n/runner_auth_token"}
      '';
      restartUnits = [ "docker-n8n-runners.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Initial credentials; anything saved in the Hermes UI overrides them.
    sops.templates."hermes.env" = {
      content = ''
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${cfg.hermes.dashboardUser}
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=${placeholder "hermes/dashboard_password_hash"}
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${placeholder "hermes/dashboard_session_secret"}
        API_SERVER_KEY=${placeholder "hermes/api_server_key"}
        REQUESTY_API_KEY=${placeholder "requesty/api_key"}
      ''
      + lib.optionalString cfg.hermes.telegram ''
        TELEGRAM_BOT_TOKEN=${placeholder "hermes/telegram_bot_token"}
        TELEGRAM_ALLOWED_USERS=${placeholder "hermes/telegram_allowed_users"}
      '';
      restartUnits = [ "docker-hermes-agent.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Groups the stack's units: `systemctl restart ai-stack.target` restarts them all.
    systemd.targets.ai-stack = {
      description = "AI application stack";
      wantedBy = [ "multi-user.target" ];
    };

    # The agent container runs as the hermes user and reaches the shared directory through this ACL.
    systemd.tmpfiles.rules = lib.optionals (cfg.sharedDirectory != null) [
      "d ${cfg.sharedDirectory.path} 2770 ${cfg.sharedDirectory.owner} ${cfg.sharedDirectory.group} -"
      "A+ ${cfg.sharedDirectory.path} - - - - u:hermes:rwX,d:u:hermes:rwx"
    ];

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      runnerAuthTokenFile = config.sops.secrets."n8n/runner_auth_token".path;
      runnerEnvironmentFile = config.sops.templates."n8n-runner.env".path;
      inherit sharedMount;
    };

    services.hermesAgent = {
      enable = true;
      environmentFiles = [ config.sops.templates."hermes.env".path ];
      inherit sharedMount;
    };
  };
}
