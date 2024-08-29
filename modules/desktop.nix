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
    altserver-linux
    xorg.xhost
    blueberry
    xdg-desktop-portal-hyprland
    brightnessctl
    pinentry
    pinentry-rofi
    qt5ct
    qt6ct
    nwg-look
    mullvad-vpn
    gparted
    pavucontrol
    filezilla
  ];
}
