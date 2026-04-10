{ pkgs, ... }:

{
  imports = [
    ./packages.nix
    ./fonts.nix
    ./hyprland/default.nix
    ./programming.nix
    ./services.nix
  ];

  security = {
    pam.services.swaylock = { };
    pam.services.login.enableKwallet = true;
  };

  networking.stevenBlackHosts = {
    enable = true;
    blockFakenews = true;
    blockGambling = true;
    blockSocial = true;
  };

  environment.systemPackages = with pkgs; [
    xhost
    blueman
    brightnessctl
    pinentry-curses
    pinentry-rofi
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    nwg-look
    gparted
    pavucontrol
    filezilla
    linux-firmware
    mtpfs
    wofi-pass
    powertop
    picard
  ];
}
