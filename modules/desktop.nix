{ pkgs, ... }:

{
  imports = [
    ./packages.nix
    ./fonts.nix
    ./hyprland/default.nix
    ./programming.nix
    ./services.nix
  ];

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
    droidcam

    # Desktop-only tools (not needed on server)
    wofi-pass
    powertop
    piper
    lact
    picard
    undervolt
    s-tui
    stress
  ];
}
