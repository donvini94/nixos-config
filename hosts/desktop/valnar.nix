{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:
let
  unstablePkgs = import inputs.unstable {
    config.allowUnfree = true;
  };
  pkgs = import inputs.nixpkgs {
    config.allowUnfree = true;
  };

in
{
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
  unstablePkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "microsoft-identity-broker"
    ];
  services.intune.enable = true;

  systemd.packages = [
    unstablePkgs.microsoft-identity-broker
    unstablePkgs.intune-portal
  ];
  systemd.tmpfiles.packages = [ unstablePkgs.intune-portal ];
  services.dbus.packages = [ unstablePkgs.microsoft-identity-broker ];

  networking.hostName = "valnar";
  environment.systemPackages =
    with pkgs;
    [
      cudatoolkit
      mesa
      nvitop
      nvidia-container-toolkit
      nvidia-vaapi-driver
      mangohud
      transmission_4-gtk
    ]
    ++ (with unstablePkgs; [
      micrisoft-identity-broker
      intune-portal
    ]);

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
  # Sound speaker fix, see #1039
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=auto
  '';

  boot.blacklistedKernelModules = [ "snd_soc_avs" ];
  # dolby atmos needs kernel 6.8+
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  nix.settings.max-jobs = 24;
  swapDevices = [ ];
  system.stateVersion = "23.11";
  nixpkgs.config.allowUnfree = true;
}
