{
  config,
  lib,
  username,
  ...
}:

let
  enableAI = true;
  defaultModel = "deepinfra/deepseek-v4-flash-0731";
  models.${defaultModel} = {
    name = "DeepSeek V4 Flash 0731 (DeepInfra via Requesty)";
    context = 131072;
    output = 32768;
    reasoning = true;
  };
  secretFile = ../../secrets/alucard-ai.yaml;
in
{
  imports = [
    ../../modules/remote-openai.nix
    ../../modules/n8n.nix
    ../../modules/hermes.nix
    ../../modules/wirken.nix
  ];

  config = lib.mkIf enableAI {
    assertions = [
      {
        assertion = lib.all (address: address == "127.0.0.1") [
          config.services.remoteOpenAI.bindAddress
          config.services.localN8n.bindAddress
          config.services.localHermes.dashboard.bindAddress
          config.services.localObservability.bindAddress
        ];
        message = "Alucard AI services must remain loopback-only; use SSH tunnels or Tailscale Serve";
      }
      {
        assertion =
          lib.intersectLists [
            5678
            8080
            9119
            13000
            13001
            18081
            18790
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
      "wirken/vault_passphrase" = {
        sopsFile = secretFile;
        owner = "root";
        mode = "0400";
      };
      "wirken/ingress_token" = {
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
      bearerCredentialFile = config.sops.secrets."wirken/ingress_token".path;
      bearerCredentialCaller = "wirken";
    };

    services.localN8n = {
      enable = true;
      encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
      runnerAuthTokenFile = config.sops.secrets."n8n/runner_auth_token".path;
      runnerEnvironmentFile = config.sops.templates."n8n-runner.env".path;
      operators = [ username ];
      orgInbox = "/home/${username}/org/ai-inbox";
    };

    services.localHermes = {
      enable = true;
      model = defaultModel;
      contextLength = models.${defaultModel}.context;
      operators = [ username ];
    };

    services.localWirken = {
      enable = true;
      model = defaultModel;
      vaultPassphraseFile = config.sops.secrets."wirken/vault_passphrase".path;
      ingressCredentialFile = config.sops.secrets."wirken/ingress_token".path;
      operators = [ username ];
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
      "wirken-sandbox-image.service"
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
