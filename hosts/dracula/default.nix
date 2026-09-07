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
    ../../modules/ai-stack.nix
    ../../modules/llama.nix
    ../../modules/remote-openai.nix
    ../../modules/host-vulnerability-scan.nix
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
        # Q4 frees 2.14 GiB versus Q5; KV cache is capped at 32,768 tokens / 2 GiB.
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

  # No Requesty credential is copied to Dracula. Interactive clients reach the
  # authenticated Alucard ingress privately over Tailscale.
  services.remoteOpenAI = {
    inherit (requesty) models defaultModel;
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

  # Personal, single-operator agent. Alucard runs a separate shared instance;
  # the two never share state.
  services.aiStack = {
    enable = true;
    secretsFile = ../../secrets/dracula-ai.yaml;
    workflowDirectory = ../../n8n/workflows/dracula;
    hermes = {
      providerName = "dracula-local";
      defaultModel = "dirk-qwen3.8-27b-local";
      contextLength = config.services.localLlama.models."dirk-qwen3.8-27b-local".contextSize;
    };
    observability.gpuMetrics = true;
  };

  services.containerUpdates.enable = true;
  services.hostVulnerabilityScan.enable = true;

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

  sops.age.keyFile = "/home/${username}/.config/sops/age/keys.txt";

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
