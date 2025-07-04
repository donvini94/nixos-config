{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../../modules/gaming.nix ];

  networking.hostName = "dracula";
  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    texlive.combined.scheme-full
    cudatoolkit
    calibre
    libva
    nvitop
    rustdesk
    jetbrains.pycharm-professional
    jetbrains.rust-rover
    filebot
    transmission_4-gtk
    android-tools
    nvidia-container-toolkit

    # photos
    shotwell
    darktable

  ];

  programs.adb.enable = true;
  services = {
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };
  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";
  hardware.xpadneo.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };
  hardware.enableRedistributableFirmware = true;
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];
  virtualisation = {
    docker = {
      enable = true;
      autoPrune.enable = true;
      daemon.settings.features.cdi = true;
    };
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    open = false;
  };

  powerManagement.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  fileSystems."/media" = {
    device = "/dev/disk/by-label/media";
    fsType = "ext4";
  };

  swapDevices = [ ];

  environment = {
    variables = {
      XCURSOR_SIZE = "24";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
    };
    sessionVariables = {
      XCURSOR_SIZE = "24";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
    };
  };
  system.stateVersion = "23.11";
}
