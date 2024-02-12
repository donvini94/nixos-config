{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [
    exercism
    ranger

    # utils
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq

    mathpix-snipping-tool
    pferd
    neofetch

    sxiv
    nsxiv
    mpv
    # productivity
    glow # markdown previewer in terminal
    zathura
    anki
    # communication
    telegram-desktop
    discord
    thunderbirdPackages.thunderbird-115
    slack
    signal-desktop
    teams-for-linux

    zotero

    # photos
    shotwell
    darktable
    imagemagick
  ];

}
