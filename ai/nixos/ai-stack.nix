# Alucard's agent and workflow services.
{
  config,
  lib,
  ...
}:

let
  cfg = config.services.aiStack;
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
      description = "Operator account: owns the n8n secrets and the Org tree and drives the stack target.";
    };

    orgDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/org";
      description = "Org tree that n8n and Hermes read and write.";
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

    # The agent container runs as the hermes user and reaches the Org tree through this ACL.
    systemd.tmpfiles.rules = [
      "A+ ${cfg.orgDirectory} - - - - u:hermes:rwX,d:u:hermes:rwx"
    ];

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      runnerAuthTokenFile = config.sops.secrets."n8n/runner_auth_token".path;
      runnerEnvironmentFile = config.sops.templates."n8n-runner.env".path;
      orgOwner = cfg.user;
      inherit (cfg) orgDirectory;
    };

    services.hermesAgent = {
      enable = true;
      inherit (cfg) orgDirectory;
    };
  };
}
