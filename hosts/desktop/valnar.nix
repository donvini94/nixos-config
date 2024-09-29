{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd
        ];
      };
    };
  };

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      443
      22
      3000
    ];
  };

  networking.hostName = "valnar";
  environment.systemPackages = with pkgs; [
    cudatoolkit
    mesa
    nvitop
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = lib.mkDefault [
    "nvidia"
  ];
  hardware.graphics.extraPackages = with pkgs; [ vaapiVdpau ];
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
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };

  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";
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

  # hardware.nix
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
    "thunderbolt"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  swapDevices = [ ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  system.stateVersion = "23.11";
}
