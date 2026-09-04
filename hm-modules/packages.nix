# Linux-desktop package set. Cross-platform CLI tooling lives in cli-tools.nix, which
# the Mac imports too; this file is the part that is Wayland/GTK-bound, GUI-only, or
# deliberately Linux-only.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Document tools
    mupdf

    # Finance — the hledger closure is Haskell-heavy (~900 MiB download,
    # ~6 GiB unpacked); deliberately not on the Mac.
    hledger
    hledger-ui
    hledger-utils
    hledger-interest
    hledger-web

    # Dev tools
    zed-editor
    zeal
    bruno
    aider-chat
    warp-terminal
    claude-agent-acp

    # Writing & docs
    texliveMedium

    # Media
    nsxiv

    # Productivity
    anki
    zotero
    zoom-us

    # Japanese
    qolibri

    # Communication
    discord
    telegram-desktop
    thunderbird
    slack
    signal-desktop
    teams-for-linux
  ];
}
