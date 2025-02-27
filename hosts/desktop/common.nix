{
  config,
  lib,
  pkgs,
  username,
  ...
}:

{

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };
  };

  hardware = {
    pulseaudio.enable = false;
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };

  programs.ausweisapp.enable = true;
  programs.ausweisapp.openFirewall = true;

  networking = {
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    settings.trusted-users = [ "${username}" ];
    settings.auto-optimise-store = true;
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # noisetorch is a tool for noise suppression in voice chats
  programs.noisetorch.enable = true;
  security = {
    rtkit.enable = true;
    pam.services.login.enableKwallet = true;
    pam.services.swaylock = { };
  };

  #  services.desktopManager.plasma6.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };

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
  programs.virt-manager.enable = true;
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

  # Comment this in the first time you want to connect to AirPods.
  # In order to connect, you have to press the button on the back
  # of the AirPods case.
  # `breder` is only needed for the initial connection of the AirPods.
  # Afterwards the mode can be relaxed to `dual` (the default) again.
  #
  # hardware.bluetooth.settings = { General = { ControllerMode = "bredr"; }; };
}
