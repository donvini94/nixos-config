# Alucard's agent and workflow services, backed by the AI ingress.
{
  config,
  lib,
  username,
  ...
}:

let
  cfg = config.services.aiStack;
  hermes = import ../lib/hermes-agent.nix;
in
{
  imports = [
    ./ai-ingress.nix
    ./n8n.nix
    ./hermes-dashboard.nix
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

    workflowDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Host-specific n8n workflow directory.";
    };

    hermes = {
      providerName = lib.mkOption {
        type = lib.types.str;
        description = "Name Hermes gives the ingress-backed provider.";
      };

      defaultModel = lib.mkOption {
        type = lib.types.str;
        description = "Model Hermes requests from the ingress.";
      };

      contextLength = lib.mkOption {
        type = lib.types.int;
        description = "Context window Hermes assumes for the default model.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "n8n/encryption_key" = {
        sopsFile = cfg.secretsFile;
        owner = username;
        mode = "0400";
      };
      "n8n/runner_auth_token" = {
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

    sops.templates."n8n-runner.env" = {
      content = ''
        N8N_RUNNERS_AUTH_TOKEN=${config.sops.placeholder."n8n/runner_auth_token"}
      '';
      restartUnits = [ "docker-n8n-runners.service" ];
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # OMP, Hermes and n8n all trace through this one proxy.
    services.aiIngress.autoStart = cfg.autoStart;

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
      orgOwner = username;
      orgDirectory = "/home/${username}/org";
      inherit (cfg) workflowDirectory;
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      workingDirectory = "/var/lib/hermes/workspace";
      settings = hermes.mkSettings {
        inherit (cfg.hermes) providerName defaultModel contextLength;
        ingressUrl = "http://127.0.0.1:8080/v1";
      };
      documents = {
        "AGENTS.md" = ../hermes/workspace/AGENTS.md;
      };
      hermesHomeFiles = {
        "SOUL.md" = ../hermes/workspace/SOUL.md;
      };
      environment = hermes.runtimeEnv;
      # Each host defines this template itself; the contents genuinely differ.
      environmentFiles = [ config.sops.templates."hermes.env".path ];
      container = {
        enable = true;
        backend = "docker";
        image = hermes.image;
        hostUsers = [ username ];
        extraVolumes = [ "/home/${username}/org:/org:rw" ];
        extraOptions = hermes.containerOptions;
      };
    };

    services.hermesDashboard.enable = true;

    # Upstream wants multi-user.target; this stack is gated behind
    # ai-stack.target and must not start before the ingress it talks to.
    systemd.services.hermes-agent = {
      wantedBy = lib.mkForce [ "ai-stack.target" ];
      partOf = [ "ai-stack.target" ];
      after = [ "local-llama-logger.service" ];
      requires = [ "local-llama-logger.service" ];
    };

    services.containerUpdates.units = [
      "docker-n8n.service"
      "docker-n8n-runners.service"
    ];
  };
}
