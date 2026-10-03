# Alucard's agent and workflow services, backed by the AI ingress.
{
  config,
  lib,
  username,
  ...
}:

let
  cfg = config.services.aiStack;
  orgDirectory = "/home/${username}/org";
in
{
  imports = [
    ./ai-ingress.nix
    ./n8n.nix
    ./hermes.nix
    ./container-updates.nix
  ];

  options.services.aiStack = {
    enable = lib.mkEnableOption "AI ingress, n8n and Hermes";

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the AI stack starts automatically at boot.";
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
        owner = username;
        mode = "0400";
      };
      "hermes/api_server_key" = {
        sopsFile = cfg.secretsFile;
        owner = "root";
        mode = "0400";
      };
    };

    # OMP, Hermes and n8n all trace through this one proxy.
    services.aiIngress.autoStart = cfg.autoStart;

    services.aiIngress.langfuse = {
      enable = true;
      publicKeyFile = config.sops.secrets."langfuse/project_public_key".path;
      secretKeyFile = config.sops.secrets."langfuse/project_secret_key".path;
    };

    # The agent container runs as the hermes user and reaches the Org tree through this ACL.
    systemd.tmpfiles.rules = [
      "A+ ${orgDirectory} - - - - u:hermes:rwX,d:u:hermes:rwx"
    ];

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      orgOwner = username;
      inherit orgDirectory;
    };

    services.hermesAgent = {
      enable = true;
      inherit orgDirectory;
    };

    # The agent talks to the ingress, so it must not start before it.
    systemd.services.docker-hermes-agent = {
      after = [ "local-llama-logger.service" ];
      requires = [ "local-llama-logger.service" ];
    };

    services.containerUpdates.units = [
      "docker-n8n.service"
      "docker-hermes-agent.service"
    ];
  };
}
