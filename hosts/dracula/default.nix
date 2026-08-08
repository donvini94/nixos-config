{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../modules/desktop.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/llama.nix
    ./hardware.nix
    ./services.nix
  ];

  networking = {
    hostName = "dracula";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs.config.cudaSupport = true;

  services.localLlama = {
    enable = true;
    defaultModel = "qwen3.6-27b-local";
    models = {
      "qwen3.6-27b-local" = {
        repo = "unsloth/Qwen3.6-27B-GGUF";
        revision = "82d411acf4a06cfb8d9b073a5211bf410bfc29bf";
        file = "Qwen3.6-27B-Q4_K_M.gguf";
        sha256 = "5ed60d0af4650a854b1755bd392f9aef4872643dc25a254bc68043fa638392a0";
        displayName = "Qwen3.6 27B Q4_K_M (dense)";
        description = "Dense baseline; 32,768 tokens per parallel slot.";
        contextSize = 65536;
        parallelSlots = 2;
        gpuLayers = 999;
      };
      "qwen3.6-35b-a3b" = {
        repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
        revision = "a483e9e6cbd595906af30beda3187c2663a1118c";
        file = "Qwen3.6-35B-A3B-UD-Q3_K_M.gguf";
        sha256 = "1b715841683f960bd9a49f008181bd910ee169b78d4cf465b6fde7f4d929ff99";
        displayName = "Qwen3.6 35B-A3B UD-Q3_K_M (MoE)";
        description = "35B-total MoE baseline; no vision projector; 32,768 tokens per parallel slot.";
        contextSize = 65536;
        parallelSlots = 2;
        gpuLayers = 999;
      };
    };
    bindAddress = "127.0.0.1";
    port = 8080;
    backendPort = 18080;
    modelStartPort = 18100;
    operators = [ username ];
  };

  nix = {
    settings = {
      trusted-users = [ "${username}" ];
      substituters = [ "https://cuda-maintainers.cachix.org" ];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
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
    packages = with pkgs; [ firefox ];
  };

  system.stateVersion = "23.11";
}
