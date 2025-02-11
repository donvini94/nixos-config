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
    pinentry
    pinentry-rofi
    libsForQt5.qt5ct
    qt6ct
    nwg-look
    mullvad-vpn
    gparted
    pavucontrol
    filezilla
  ];
}
