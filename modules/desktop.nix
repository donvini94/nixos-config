{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./packages.nix
    ./fonts.nix
    ./hyprland/default.nix
    ./programming.nix
    ./services.nix
  ];

  environment.systemPackages = with pkgs; [
    xorg.xhost
    blueberry
    brightnessctl
    pinentry-curses
    pinentry-rofi
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    nwg-look
    mullvad-vpn
    gparted
    pavucontrol
    filezilla
    power-profiles-daemon
    linux-firmware
    mtpfs
    droidcam
  ];
}
