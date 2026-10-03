{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:

let
  hermesDesktop = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop;
  hermesDesktopLauncher = pkgs.makeDesktopItem {
    name = "hermes-desktop";
    desktopName = "Hermes";
    comment = "Hermes Agent desktop client";
    exec = "${hermesDesktop}/bin/hermes-desktop";
    icon = "${hermesDesktop}/share/hermes-desktop/dist/hermes.png";
    categories = [ "Development" ];
  };
  # Keep CUDA scoped to inference and compile only for the RTX 3090.
  cudaPkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
      cudaCapabilities = [ "8.6" ];
    };
  };
  llamaCppCuda = cudaPkgs.llama-cpp.override {
    cudaSupport = true;
    cudaPackages = cudaPkgs.cudaPackages_13;
  };
in
{
  imports = [
    inputs.determinate.nixosModules.default
    ../../modules/desktop.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/observability
    ../../ai/nixos/llama.nix
    ../../modules/mail-credentials.nix
    ../../ai/nixos/requesty.nix
    ../../modules/transcription.nix
    ../../modules/gpu-mode.nix
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

  services.localLlama = {
    enable = true;
    package = llamaCppCuda;
    defaultModel = "occamy-1.0-iq4_xs";
    models."occamy-1.0-iq4_xs" = {
      repo = "Accio-Lab/occamy-1.0-GGUF";
      revision = "e8fe5e28e1b1c1f0cd0a39b85b16b631f17ca14e";
      files = [
        {
          path = "occamy-1.0-IQ4_XS.gguf";
          sha256 = "b587e40f11bda45e3a3f150e03dae0af9069eaa3036a43e8c34a0e6122858225";
        }
      ];
      modelFile = "occamy-1.0-IQ4_XS.gguf";
      displayName = "Occamy-1.0 IQ4_XS (GGUF, MoE)";
      description = "Qwen3.6-35B-A3B tool-use/coding MoE fine-tune; hybrid linear+full attention (only 10/40 layers grow a KV cache), 3B active params/token; one long-context agent slot.";
      # IQ4_XS leaves ~1.7 GiB headroom with the compositor running.
      # Re-measure VRAM under a long prompt before increasing context or quant size.
      contextSize = 131072;
      parallelSlots = 1;
      reasoning = true;
      serverArgs = [
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "-fa"
        "on"
        "-ngl"
        "99"
        "--jinja"
      ];
    };
  };

  services.localTranscription = {
    enable = true;
    operators = [ username ];
  };

  # The ASR engine and the LLM backend each want most of the 24 GiB card, and
  # games want all of it: `gpu-mode gaming` clears both.
  services.gpuMode.modes = {
    transcription = {
      unit = "local-transcription.service";
      start = "transcription-start";
      stop = "transcription-stop";
    };
    ai = {
      unit = "ai-stack.target";
      start = "ai-stack-start";
      stop = "ai-stack-stop";
    };
  };

  services.aiStackTarget = {
    operators = [ username ];
    autoStart = false;
  };

  sops.secrets."requesty/api_key" = {
    sopsFile = ../../secrets/dracula-ai.yaml;
    owner = username;
    mode = "0400";
  };
  services.requesty.apiKeyFile = config.sops.secrets."requesty/api_key".path;

  services.localObservability = {
    enable = true;
    autoStart = false;
    secretsFile = ../../secrets/dracula-ai.yaml;
    gpuMetrics = true;
    scrapeTargets.llama = 8080;
  };

  services.hostVulnerabilityScan.enable = true;
  determinate.enable = true;

  # Determinate Nixd owns garbage collection on this pilot. Keep its policy explicit and
  # disable Sentry crash reports; ordinary aggregate telemetry remains at the vendor default.
  environment.etc."determinate/config.json".text = builtins.toJSON {
    garbageCollector.strategy = "automatic";
    telemetry.sentry.endpoint = null;
  };

  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    settings = {
      max-jobs = 2;
      cores = 6;
      extra-substituters = [
        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://hermes-agent.cachix.org"
      ];
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
        "hermes-agent.cachix.org-1:jN3pjR50Mxi4SESKC/FIMNM6/LCosvPk2VUwzVvebzU="
      ];
    };
    gc.automatic = lib.mkForce false;
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
