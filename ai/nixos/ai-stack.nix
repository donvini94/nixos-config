# n8n and Hermes with their secrets, plus the stack target.
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
in
{
  imports = [
    ./ai-stack-target.nix
    ./n8n.nix
    ./hermes.nix
  ];

  options.services.aiStack = {
    enable = lib.mkEnableOption "n8n and Hermes";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Operator account: owns the n8n secret files and may start and stop the stack target.";
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

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "SOPS file holding n8n and Hermes secrets.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "n8n/encryption_key" = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        mode = "0400";
      };
      "n8n/runner_auth_token" = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        mode = "0400";
      };
      "hermes/api_server_key" = {
        sopsFile = cfg.secretsFile;
        owner = "root";
        mode = "0400";
      };
    };

    sops.templates."n8n-runner.env" = {
      content = ''
        N8N_RUNNERS_AUTH_TOKEN=${config.sops.placeholder."n8n/runner_auth_token"}
      '';
      restartUnits = [ "docker-n8n-runners.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    services.aiStackTarget = {
      enable = true;
      operators = [ cfg.user ];
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
      inherit sharedMount;
    };
  };
}
