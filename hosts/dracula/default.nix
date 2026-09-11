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
    firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  };

  services.tailscale = {
    enable = true;
    disableTaildrop = true;
    openFirewall = false;
    useRoutingFeatures = "none";
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  nixpkgs.config.cudaSupport = true;

  services.localLlama = {
    enable = true;
    defaultModel = "qwen3.8-27b-exl3-3.5bpw";
    models."qwen3.8-27b-exl3-3.5bpw" = {
      repo = "Mia-AiLab/Qwen3.8-27B-EXL3-3.5bpw";
      revision = "19441ac874c4018295da848e250f23511361cda4";
      files = [
        {
          path = "chat_template.jinja";
          sourceUrl = "https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates/resolve/855bffc49448e299789730ff92c9b8d834d6cc14/chat_template.jinja";
          sha256 = "e57684bae4156211a55473c5a63be976a405a37ab5be5ae0e5abf1df5349c4b2";
        }
        {
          path = "config.json";
          sha256 = "153407dcf65483b121759efc6bdd0e41e124e1e297496a9ba979936689a4b9d2";
        }
        {
          path = "generation_config.json";
          sha256 = "e70c136c1b78ddc1fb0905bac8e733a4dc448d4f852a5dd75143fffc70be550e";
        }
        {
          path = "merges.txt";
          sha256 = "a9d356d7bdf1ef4949e3e748e95b8e10ad9d4e2e838eddc38a0a7b6b94d1db8d";
        }
        {
          path = "model-00001-of-00002.safetensors";
          sha256 = "7b77214fe58ff15fed0b4af55e3cd92f38842b8711886d68954e8071ff8270c6";
        }
        {
          path = "model-00002-of-00002.safetensors";
          sha256 = "411c83bb1070b27f3d670fc93e38dca0f17eb66429f64b5706901b12613188b2";
        }
        {
          path = "model.safetensors.index.json";
          sha256 = "ee2d5e73b5f8311ad331ce3c94a29d1143225064b278a18fa9966cba54d2802e";
        }
        {
          path = "preprocessor_config.json";
          sha256 = "27225450ac9c6529872ee1924fcb0962ff5634834f817040f444118116f4e516";
        }
        {
          path = "quantization_config.json";
          sha256 = "d5e7e4c411084ef898b470e35a20181093bf3adbb1282e9d81674ce7b3d9069d";
        }
        {
          path = "tokenizer.json";
          sha256 = "0997f410c57a1f4e53b09e4be8f4a172d90edd9564368fb0847030937229b9f3";
        }
        {
          path = "tokenizer_config.json";
          sha256 = "b11349aafa7cdc6a320767cf7ceb29ed82f7eda5d65e8e0819e76f0ce947bf27";
        }
        {
          path = "video_preprocessor_config.json";
          sha256 = "7768af27c1fafa9cc9011c1dc20067e03f8915e03b63504550e11d5066986d13";
        }
        {
          path = "vocab.json";
          sha256 = "ce99b4cb2983d118806ce0a8b777a35b093e2000a503ebde25853284c9dfa003";
        }
      ];
      displayName = "Qwen3.8 27B EXL3 3.5bpw (dense)";
      description = "Dense Qwen3.8 default; EXL3 3.5bpw weights; text-only serving; one 32,768-token agent slot.";
      # CEILING: keep one 32,768-token FP16 cache within Dracula's 24 GiB GPU; raise it only after measuring TabbyAPI's live footprint.
      contextSize = 32768;
      parallelSlots = 1;
      reasoning = true;
      toolFormat = "qwen3_5";
    };
  };

  services.aiIngress.operators = [ username ];

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
      defaultModel = config.services.localLlama.defaultModel;
      contextLength =
        config.services.localLlama.models.${config.services.localLlama.defaultModel}.contextSize;
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
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPlhh/4miDPy8MD7ckimo0ZlEyRIIQymAeNrpvbURg+H0G+kztFgr2x0muzAVwy5noz7511zQBkG9q+lJfWHzjGvVibew5HhcdlECkzpStrkRkupM0l7Ql1ILlQb/lME1v4TM+JM1nCbOgIqkjKJ/dzE3WqHz8CfJ6ilf5QedKHnAFbMu6miOGHMJxDje+0t/51QPul513d2oyIjtUBjtW0Yo77PgSuopFbhEI//cn0P7QVJArbmv7YZqGNifVzMyzQBlvXQtJC0CR/bGTJwspCCU2xIangzHrkKxRqkZJrk1zC5JyMbW1oRUZ3ah7MbUq/ivAUfjvzvkrZS5DbigMmSIbGmoK9d/k6pQjj4gyL1Q5KZRq4g2JKkV6Uhaqr2yfG2F0T6FGKnhGO6P5PK2bkAobfCfLL5IGkceK/WB0InMKfdbii971CeUY0qk+1ad7Fn9txuR5omttkEtM9Hh9Afz1kGxa4ia9+d71OV4KoXVykqr/bD284rhOooX4/mU= vincenzo@dracula"
    ];
  };

  system.stateVersion = "23.11";
}
