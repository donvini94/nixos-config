{ inputs, lib, config, pkgs, ... }:

{
  imports = [
    ./modules/packages.nix
    ./modules/fonts.nix
    ./modules/hyprland/default.nix
    ./modules/programming.nix
    ./modules/services.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  hardware.bluetooth.enable = true;
  security.rtkit.enable = true;

  users.users.vincenzo = {
    isNormalUser = true;
    description = "Vincenzo Pace";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ firefox ];
  };

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.trusted-users = [ "vincenzo" ];
    settings.auto-optimise-store = true;
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
  };

  environment.shells = with pkgs; [ bash nushell ];
  environment.variables.EDITOR = "nvim";

  security.pam.services.login.enableKwallet = true;
  security.pam.services.swaylock = { };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
}
