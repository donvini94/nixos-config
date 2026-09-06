# The AI stack both dracula and alucard run identically. Host deltas are additional
# definitions in the host files, merged by NixOS, never restatements of what is here.
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
    ./observability.nix
    ./container-updates.nix
  ];

  options.services.aiStack = {
    enable = lib.mkEnableOption "the shared AI stack: ingress tracing, n8n, Hermes and observability";

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Host SOPS file holding the n8n, Hermes, Langfuse and Grafana secrets.";
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

    observability = {
      gpuMetrics = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Scrape GPU metrics through the DCGM exporter.";
      };

      hostLabel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Prometheus host label; null keeps the observability module's own default.";
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
          sopsFile = cfg.secretsFile;
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

    # OMP, Hermes and n8n all trace through this one proxy.
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
      inherit (cfg) workflowDirectory;
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      settings = hermes.mkSettings {
        inherit (cfg.hermes) providerName defaultModel contextLength;
        ingressUrl = "http://127.0.0.1:8080/v1";
      };
      documents = {
        "AGENTS.md" = ../hermes/workspace/AGENTS.md;
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

    services.localObservability = {
      enable = true;
      environmentFile = config.sops.templates."observability.env".path;
      inherit (cfg.observability) gpuMetrics;
      inferencePort = 8080;
      n8nPort = 5678;
    }
    // lib.optionalAttrs (cfg.observability.hostLabel != null) {
      inherit (cfg.observability) hostLabel;
    };

    services.containerUpdates.units = [
      "docker-n8n.service"
      "docker-n8n-runners.service"
    ];
  };
}
