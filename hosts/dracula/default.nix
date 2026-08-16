{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:

let
  requesty = import ../../lib/requesty-models.nix;
  hermes = import ../../lib/hermes-agent.nix;
  hermesDesktop = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop;
  hermesDesktopLauncher = pkgs.makeDesktopItem {
    name = "hermes-desktop";
    desktopName = "Hermes";
    comment = "Hermes Agent desktop client";
    exec = "${hermesDesktop}/bin/hermes-desktop";
    icon = "${hermesDesktop}/share/hermes-desktop/dist/hermes.png";
    categories = [ "Development" ];
  };
in
{
  imports = [
    ../../modules/desktop.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/ai-ingress.nix
    ../../modules/llama.nix
    ../../modules/remote-openai.nix
    ../../modules/n8n.nix
    ../../modules/hermes-dashboard.nix
    ../../modules/observability.nix
    ../../modules/container-updates.nix
    ./hardware.nix
    ./services.nix
  ];

  networking = {
    hostName = "dracula";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  services.tailscale = {
    enable = true;
    disableTaildrop = true;
    openFirewall = false;
    useRoutingFeatures = "none";
  };

  nixpkgs.config.cudaSupport = true;

  services.localLlama = {
    enable = true;
    defaultModel = "dirk-qwen3.8-27b-local";
    models = {
      "dirk-qwen3.8-27b-local" = {
        repo = "peculiar-ragdoll/Dirk-Qwen3.8-27B-GGUF";
        revision = "027902e9811019480b8b074aed93fa6084f782a9";
        file = "Dirk-Qwen3.8-27B-UD-Q4_K_XL.gguf";
        sha256 = "405359214aa8bd77b1af70121bc2d7878f3395b73dea16ae362ce71fa56b248e";
        displayName = "Dirk Qwen3.8 27B UD-Q4_K_XL (dense)";
        description = "Dense Qwen3.8 default; Q4 weights; text-only serving; one 32,768-token agent slot.";
        # Q4 releases 2.14 GiB of weight memory versus Q5. Retain the validated
        # 32,768-token / 2 GiB KV-cache cap until this artifact is live-measured.
        contextSize = 32768;
        parallelSlots = 1;
        gpuLayers = 999;
      };
      "qwen3.6-35b-a3b" = {
        repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
        revision = "a483e9e6cbd595906af30beda3187c2663a1118c";
        file = "Qwen3.6-35B-A3B-UD-Q3_K_M.gguf";
        sha256 = "1b715841683f960bd9a49f008181bd910ee169b78d4cf465b6fde7f4d929ff99";
        displayName = "Qwen3.6 35B-A3B UD-Q3_K_M (MoE)";
        description = "35B-total MoE baseline; no vision projector; one 65,536-token agent slot.";
        contextSize = 65536;
        parallelSlots = 1;
        gpuLayers = 999;
      };
    };
    bindAddress = "127.0.0.1";
    port = 8080;
    backendPort = 18080;
    modelStartPort = 18100;
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

  # Hermes runs as its own service identity inside a container and reaches the
  # Org tree only through this inherited ACL.
  systemd.tmpfiles.rules = [
    "A+ /home/${username}/org - - - - u:hermes:rwX,d:u:hermes:rwx"
  ];

  # No Requesty credential is copied to Dracula. Interactive clients reach the
  # authenticated Alucard ingress privately over Tailscale.
  services.remoteOpenAI = {
    inherit (requesty) models defaultModel;
  };

  sops.secrets = {
    "n8n/encryption_key" = {
      sopsFile = ../../secrets/dracula-ai.yaml;
      owner = username;
      mode = "0400";
    };
    "n8n/runner_auth_token" = {
      sopsFile = ../../secrets/dracula-ai.yaml;
      owner = username;
      mode = "0400";
    };
    "hermes/api_server_key" = {
      sopsFile = ../../secrets/dracula-ai.yaml;
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
        sopsFile = ../../secrets/dracula-ai.yaml;
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

  sops.templates."hermes.env" = {
    content = ''
      API_SERVER_KEY=${config.sops.placeholder."hermes/api_server_key"}
    '';
    restartUnits = [ "hermes-agent.service" ];
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

  sops.templates."opencode-langfuse.json" = {
    content = builtins.toJSON {
      publicKey = config.sops.placeholder."langfuse/project_public_key";
      secretKey = config.sops.placeholder."langfuse/project_secret_key";
      baseUrl = "http://127.0.0.1:13000";
      environment = "dracula";
      userId = username;
    };
    mode = "0400";
    owner = username;
    group = "users";
  };

  services.localN8n = {
    enable = true;
    encryptionKeyFile = config.sops.secrets."n8n/encryption_key".path;
    runnerAuthTokenFile = config.sops.secrets."n8n/runner_auth_token".path;
    runnerEnvironmentFile = config.sops.templates."n8n-runner.env".path;
    operators = [ username ];
    orgDirectory = "/home/${username}/org";
    hermesApiPort = 8642;
    workflowDirectory = ../../n8n/workflows/dracula;
  };

  # Personal, single-operator agent. Alucard runs a separate shared instance;
  # the two never share state.
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    settings = hermes.mkSettings {
      providerName = "dracula-local";
      defaultModel = "dirk-qwen3.8-27b-local";
      ingressUrl = "http://127.0.0.1:8080/v1";
      contextLength = 32768;
    };
    documents = {
      "AGENTS.md" = ../../hermes/workspace/AGENTS.md;
      "SOUL.md" = ../../hermes/workspace/SOUL.md;
    };
    environment = hermes.runtimeEnv;
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

  # Upstream wants multi-user.target; this stack is gated behind ai-stack.target
  # and must not start before the ingress it talks to.
  systemd.services.hermes-agent = {
    wantedBy = lib.mkForce [ "ai-stack.target" ];
    partOf = [ "ai-stack.target" ];
    after = [ "local-llama-logger.service" ];
    requires = [ "local-llama-logger.service" ];
  };

  services.localObservability = {
    enable = true;
    environmentFile = config.sops.templates."observability.env".path;
    gpuMetrics = true;
    inferencePort = 8080;
    n8nPort = 5678;
  };

  services.containerUpdates = {
    enable = true;
    units = [
      "docker-n8n.service"
      "docker-n8n-runners.service"
    ];
  };

  nix = {
    settings = {
      trusted-users = [ "${username}" ];
      substituters = [
        "https://cuda-maintainers.cachix.org"
        "https://hermes-agent.cachix.org"
      ];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
      ];
    };
    gc.dates = "weekly";
  };

  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";

  users.users."${username}" = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
      "audio"
    ];
    packages = [
      pkgs.firefox
      hermesDesktop
      hermesDesktopLauncher
    ];
  };

  system.stateVersion = "23.11";
}
