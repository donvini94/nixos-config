{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./networking.nix
    ./private-access.nix
    ./security.nix
    ./services/default.nix
    ./media.nix
    ./users.nix
    ./syncthing.nix
    ./ai.nix
    ../../modules/packages.nix
    ../../modules/paperless.nix
    ../../modules/mailcow-tls.nix
    ../../modules/observability.nix
    ../../modules/container-updates.nix
    ../../modules/vulnerability-scan.nix
    ../../modules/host-vulnerability-scan.nix
    ../../modules/offsite-backup.nix
    ../../secrets/secrets.nix
  ];

  # The flake wires home-manager for the primary user only; Kyrill's own
  # account is named here.
  home-manager.users.kyrill = import ./home-kyrill.nix;

  services.containerUpdates = {
    enable = true;
    units = [ "media-stack.service" ];
  };

  services.containerVulnerabilityScan = {
    enable = true;
    rootlessDockerUser = username;
  };

  services.hostVulnerabilityScan.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "cifs" ];
  };

  # Shared base lives in configuration.nix.
  # Keep local rebuilds below the host's steady-state service demand.
  nix = {
    settings = {
      sandbox = true;
      max-jobs = 2;
      cores = 4;
      download-buffer-size = lib.mkForce 1048576;
      trusted-users = [ username ];
    };
    gc.dates = "23:00";
    optimise.automatic = lib.mkForce false;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  systemd = {
    oomd = {
      enableSystemSlice = true;
    };

    slices = {
      "user-1000".sliceConfig = {
        ManagedOOMMemoryPressure = "kill";
        ManagedOOMMemoryPressureLimit = "80%";
        ManagedOOMSwap = "kill";
      };
    };

    services = {
      nix-daemon.serviceConfig = {
        CPUWeight = 25;
        IOWeight = 25;
        OOMScoreAdjust = 500;
      };
      nix-gc.serviceConfig = {
        Nice = 10;
        IOSchedulingClass = "idle";
        OOMScoreAdjust = 500;
      };
    }
    //
      lib.genAttrs
        [
          "atuin"
          "calibre-web"
          "docker-n8n"
          "docker-n8n-runners"
          "docker-registry"
          "gotenberg"
          "hermes-agent"
          "hermes-dashboard"
          "jellyfin"
          "keycloak"
          "navidrome"
          "nginx"
          "paperless-consumer"
          "paperless-scheduler"
          "paperless-task-queue"
          "paperless-web"
          "postgresql"
          "redis-paperless"
          "tika"
        ]
        (_: {
          serviceConfig.ManagedOOMPreference = "avoid";
        });

    # Docker scopes are transient siblings of docker.service, not children of
    # the compose wrapper units. This prefix drop-in protects rootful workloads
    # such as mailcow when systemd-oomd selects within system.slice.
    units."docker-.scope" = {
      overrideStrategy = "asDropin";
      text = ''
        [Scope]
        ManagedOOMPreference=avoid
      '';
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  environment.systemPackages = with pkgs; [
    yazi
    # System package, not home-manager: `ssh host -- zellij ...` runs a
    # non-interactive shell that never sources the per-user profile.
    zellij
    openssl
    apacheHttpd
    filebot
    cifs-utils
    docker-compose
    # Required by Mailcow's official update.sh migration path.
    jq
    keycloak
    ffmpeg
    yt-dlp
    openstackclient
    inetutils
    claude-code
    nodejs_22
    cargo
    gcc
    lnav
  ];

  # On top of the home-manager fish: this is what makes fish a valid entry in
  # /etc/shells, the precondition for users.users.vincenzo.shell.
  programs.fish.enable = true;

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "screen-256color";
  };

  fileSystems."/mnt/hetzner" = {
    device = "//u487137.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."smb-hetzner".path}"
      "vers=3.1.1"
      "sec=ntlmssp"
      "seal"
      "iocharset=utf8"
      "file_mode=0644"
      "dir_mode=0755"
      "uid=jellyfin"
      "gid=jellyfin"
      "_netdev"
      "x-systemd.automount"
      "noauto"
      "nofail"
      "serverino"
    ];
  };

  system.stateVersion = "23.05";
}
