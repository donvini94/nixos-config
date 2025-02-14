{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/gaming.nix
  ];
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      22
      3000
    ];
  };

  services = {
    ollama = {
      enable = true;
      acceleration = "cuda";
    };
    intune.enable = true;
  };

  networking.hostName = "valnar";
  environment.systemPackages = with pkgs; [
    cudatoolkit
    mesa
    nvitop
    nvidia-container-toolkit
    nvidia-vaapi-driver
    mangohud
    transmission_4-gtk
    microsoft-edge
  ];

  # Enable OpenGL
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
  services.xserver.videoDrivers = lib.mkDefault [
    "nvidia"
  ];
  virtualisation = {
    docker = {
      enable = true;
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
    #   prime = {
    #     offload = {
    #       enable = true;
    #       enableOffloadCmd = true;
    #     };
    #     nvidiaBusId = "PCI:1:0:0";
    #     intelBusId = "PCI:0:2:0";
    #   };
  };

  powerManagement.enable = true;
  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";
  environment = {
    variables = {
      XCURSOR_SIZE = "24";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
    sessionVariables = {
      XCURSOR_SIZE = "24";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      XDG_SESSION_TYPE = "wayland";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
  };

  # hardware.nix
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "sdhci_pci"
    "thunderbolt"
  ];
  boot.kernelModules = [
    "kvm-intel"
  ];

  # dolby atmos needs kernel 6.8+
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  nix.settings.max-jobs = 24;
  swapDevices = [ ];
  system.stateVersion = "23.11";
}
