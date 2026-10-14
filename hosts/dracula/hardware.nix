{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_zen;
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
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50%";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
    "/media" = {
      device = "/dev/disk/by-label/media";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # systemd records the swapfile's resume location in EFI before hibernating.
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 64 * 1024;
      priority = 0;
    }
  ];

  # /tmp is RAM-backed; the 24 GiB GPU's saved allocations need disk space.
  boot.kernelParams = [ "nvidia.NVreg_TemporaryFilePath=/var/tmp" ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;
    xpadneo.enable = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };

  # To connect AirPods: uncomment, rebuild, pair, then re-comment
  # hardware.bluetooth.settings = { General = { ControllerMode = "bredr"; }; };
}
