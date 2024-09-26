{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  networking.hostName = "asgar";
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # LIBVA_DRIVER_NAME=iHD
    vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
    vaapiVdpau
    libvdpau-va-gl
  ];

  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";
  # Hardware-configuration.nix
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  swapDevices = [ { device = "/dev/disk/by-uuid/ab5cfdd2-bacf-4f7b-9dc5-db7d92e07699"; } ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Recommended from T480 hardwareconfig github
  services.throttled.enable = lib.mkDefault true;
  services.fstrim.enable = lib.mkDefault true;

  system.stateVersion = "23.05";
}
