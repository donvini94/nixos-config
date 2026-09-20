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
  # See lib/cuda-torch.nix: a fully independent nixpkgs evaluation, not a
  # host-wide overlay, so this never touches the ambient pkgs.tabbyapi/
  # pkgs.llama-cpp/pkgs.python3Packages/pkgs.cudaPackages used by the rest of
  # the system.
  cudaTorch = import ../../lib/cuda-torch.nix {
    nixpkgsFlake = inputs.nixpkgs;
    system = pkgs.stdenv.hostPlatform.system;
  };
  tabbyapiCuda = cudaTorch.pkgs.tabbyapi.override {
    python3Packages = (cudaTorch.pythonFor "python314").pkgs;
  };
  # llama.cpp's CUDA backend is a real from-source compile (ggml-cuda has no
  # prebuilt-wheel escape hatch the way torch-bin does), but cudaTorch's scoped
  # `cudaCapabilities = [ "8.6" ]` still applies to it: it cuts the build down
  # to this GPU's one architecture instead of nixpkgs' default 9-architecture
  # list (confirmed via `nix derivation show`: CMAKE_CUDA_ARCHITECTURES goes
  # from "75;80;86;89;90;100;103;120;121" to "86").
  llamaCppCuda = cudaTorch.pkgs.llama-cpp.override { cudaSupport = true; };
in
{
  imports = [
    inputs.determinate.nixosModules.default
    ../../modules/desktop.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ../../modules/ai-stack.nix
    ../../modules/llama.nix
    ../../modules/remote-openai.nix
    ../../modules/transcription.nix
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

  # nixpkgs.config.cudaSupport = true stays off: it cascades CUDA compilation
  # into torch, opencv, openvino, cudnn and more, none of which have a working
  # public binary cache (cuda-maintainers.cachix.org is deprecated; Hydra
  # never builds unfree packages; cache.nixos-cuda.org is the CUDA team's
  # non-public internal cache, not for redistribution — see lib/cuda-torch.nix
  # for sourcing). tabbyapiCuda above is the scoped alternative: it sources
  # torch from PyPI's official CUDA wheel instead of building it. It still
  # compiles `nccl`, `libnvshmem` (open source, no prebuilt alternative;
  # constrained to this GPU's one architecture — see lib/cuda-torch.nix) and
  # exllamav3's own small CUDA extension — a single real `nixos-rebuild build`
  # measured ~15-20 minutes of that, against an otherwise all-cache closure.
  services.localLlama = {
    enable = true;
    package = llamaCppCuda;
    defaultModel = "occamy-1.0-iq4_xs";
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
    models."occamy-1.0-iq4_xs" = {
      backend = "llamacpp";
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
      description = "Qwen3.5-35B-A3B tool-use/coding MoE fine-tune; hybrid linear+full attention (only 10/40 layers grow a KV cache), 3B active params/token; one long-context agent slot.";
      # CORRECTNESS (measured, not the GGUF repo's prose): fetched each
      # candidate quant's raw GGUF header directly (HTTP range requests, no
      # gguf tooling needed) and read `tokenizer.ggml.pre` at this exact
      # pinned revision. Q4_K_M, Q8_0, Q4_K_S, Q3_K_M and IQ4_XS all store
      # `qwen2` right now — none need `--override-kv`. TOKENIZER.md's body
      # text describing the ten new quants as "currently qwen35" is stale,
      # preserved pre-correction wording; its own "Release update" note at
      # the top says they "now store qwen2", which is what the live files
      # actually contain. IQ2_M/Q2_K/IQ3_M/IQ3_XS/IQ4_NL/Q5_K_M/Q6_K were not
      # individually re-checked but share the same corrected metadata batch
      # per that release note.
      #
      # QUANT CHOICE (measured on this GPU, RTX 3090 24576 MiB, llama.cpp
      # build 5266f24/10809, desktop compositor using 2.5-2.8 GiB
      # concurrently): Q4_K_M at -ngl 99/-c 131072/q8_0 KV needs ~1.36 GiB for
      # the KV cache alone (10 full-attention layers of 40; the rest are
      # linear-attention with a fixed-size state) and does not fit — cudaMalloc
      # OOM on the KV buffer with 0 other GPU load. `-ncmoe` fits it but costs
      # real throughput (pp512 2803->1141 t/s, tg128 158->105 t/s at ncmoe=6,
      # the smallest offload leaving >2 GiB headroom). Q4_K_S fits natively
      # (ncmoe=0) with full speed (pp512 3311, tg128 176 t/s) but only ~630
      # MiB headroom — too tight against that desktop fluctuation. IQ4_XS
      # fits natively with ~1.7-1.75 GiB headroom (matching Q4_K_M+ncmoe's
      # margin) at pp512 3544 t/s / tg128 165 t/s short-context and 2935 t/s
      # / 89 t/s at a real cold 75K-token turn — both well above Q4_K_M+ncmoe.
      # Quality cost is small and inside this validation's own noise floor:
      # wikitext-2 PPL 6.3147 vs Q4_K_M's 6.2429 (BF16 reference 6.2385);
      # 24-question code/math/json/tool subsets are tied or within one
      # question. No CPU-offload flag needed at this quant.
      #
      # CEILING: 131072 context is the ceiling for this quant on this GPU
      # while the desktop compositor is also running — do not raise it or
      # switch back to a bigger quant without re-measuring headroom the same
      # way (nvidia-smi under a real ~75-100K-token load, not idle-after-load).
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
    autoStart = false;
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
      # Was max-jobs=1/cores=0: two concurrent heavy C++/CUDA derivations
      # (torch, opencv, magma under a *global* cudaSupport=true) pushed 44GiB
      # RAM + 15GiB swap before either finished. That path is gone — CUDA
      # support is scoped through lib/cuda-torch.nix's prebuilt torch wheel
      # instead (see above), so the system no longer compiles torch/opencv/
      # magma from source at all. Two concurrent ordinary builds (e.g.
      # Hyprland from git + some other C++ package), each capped to half the
      # machine's cores, is a safe amount of parallelism on 12 cores / 46GiB.
      max-jobs = 2;
      cores = 6;
      # Cache trust belongs to the daemon, not to flake-supplied client settings. Keep the
      # list host-specific: these caches serve Dracula's desktop, Emacs and Hermes.
      #
      # No CUDA-specific substituter here on purpose: cuda-maintainers.cachix.org is
      # deprecated, cache.nixos-cuda.org is the CUDA team's non-public internal cache
      # (NixOS/nixpkgs#561684), and cache.flox.dev doesn't carry this nixpkgs revision's
      # hashes. lib/cuda-torch.nix sources CUDA torch from PyPI's official wheel instead,
      # so none of that is needed. cuda.cachix.org (an unofficial third-party cache) was
      # trusted here previously as a tradeoff for building CUDA locally; removed now that
      # nothing on this host needs it.
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
