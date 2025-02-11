{
  config,
  lib,
  pkgs,
  ...
}:

{

  home.packages = with pkgs; [
    exercism
    ranger

    # utils
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    yt-dlp
    wofi-pass

    # media
    sxiv
    nsxiv
    mpv

    # productivity
    glow # markdown previewer in terminal
    zathura
    poppler_utils
    anki
    qolibri # japanese dictionaries
    mecab # japanese furigana
    kakasi
    cmigemo
    animdl
    ani-cli

    # communication
    discord
    thunderbird
    slack
    signal-desktop
    teams-for-linux
    zotero
    zoom-us
    element-desktop

  ];
}
