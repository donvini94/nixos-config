# Linux-desktop package set: Wayland/GTK-bound, GUI-only, or deliberately Linux-only.
# Cross-platform CLI tooling lives in cli-tools.nix, which the Mac imports too.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mupdf

    # The hledger closure is Haskell-heavy (~900 MiB download, ~6 GiB unpacked);
    # deliberately not on the Mac.
    hledger
    hledger-ui
    hledger-utils
    hledger-interest
    hledger-web

    zed-editor
    zeal
    bruno
    aider-chat
    warp-terminal
    claude-agent-acp
    chromium

    texliveMedium

    nsxiv

    anki
    zotero
    zoom-us

    qolibri

    discord
    telegram-desktop
    thunderbird
    slack
    signal-desktop
    teams-for-linux
  ];
}
