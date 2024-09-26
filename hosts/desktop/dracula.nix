{
  config,
  lib,
  pkgs,
  ...
}:

{
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
    #rustdesk
    zed-editor
    warp-terminal
    github-desktop
    jetbrains.pycharm-professional
    jetbrains.rust-rover
    transmission_4-gtk

    # photos
    shotwell
    darktable
    imagemagick

  ];
  services.jellyfin.enable = true;
  services.jellyfin.openFirewall = true;
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    openFirewall = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];

  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [ "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];
  virtualisation = {
    docker = {
      enable = true;
      autoPrune.enable = true;
    };
  };
  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;
    forceFullCompositionPipeline = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.production;
    powerManagement.enable = true;
    open = false;
  };

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
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
    sessionVariables = {
      XCURSOR_SIZE = "24";
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
  };
  system.stateVersion = "23.11";
}
