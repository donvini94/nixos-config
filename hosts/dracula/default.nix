{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [ ../../modules/gaming.nix ];

  networking.hostName = "dracula";

  # Boot
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_6_12;
    initrd = {
      kernelModules = [ ];
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
    };
    kernelModules = [
      "kvm-amd"
      "v4l2loopback"
    ];
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=2 card_label="DroidCam" exclusive_caps=1
    '';
  };

  # Filesystems
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
    "/media" = {
      device = "/dev/disk/by-label/media";
      fsType = "ext4";
    };
  };

  swapDevices = [ ];

  # Hardware
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    xpadneo.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = true;
      open = false;
    };
    nvidia-container-toolkit.enable = true;
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # Nix settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      download-buffer-size = 524288000;
      trusted-users = [ "${username}" ];
      auto-optimise-store = true;
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Desktop programs
  programs = {
    ausweisapp = {
      enable = true;
      openFirewall = true;
    };
    noisetorch.enable = true;
    obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
      ];
    };
  };

  # Security
  security = {
    rtkit.enable = true;
    pam.services.login.enableKwallet = true;
    pam.services.swaylock = { };
  };

  # Packages
  environment = {
    systemPackages = with pkgs; [
      cudatoolkit
      mesa
      calibre
      libva
      nvitop
      filebot
      transmission_4-gtk
      android-tools
      nvidia-container-toolkit
      lmstudio
    ];
    sessionVariables = {
      XCURSOR_SIZE = "24";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
    };
  };

  # Services
  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
    xserver.videoDrivers = lib.mkDefault [ "nvidia" ];
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings.features.cdi = true;
  };

  # User
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

  powerManagement.enable = true;

  # To connect AirPods: uncomment, rebuild, pair, then re-comment
  # hardware.bluetooth.settings = { General = { ControllerMode = "bredr"; }; };

  system.stateVersion = "23.11";
}
