{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Search (desktop extras beyond system baseline)
    ripgrep-all
    television
    entr
    lnav

    # Document tools
    csvlens
    graphviz
    pandoc
    mupdf

    # Download
    aria2

    # Reference
    cht-sh
    tldr

    # Finance
    hledger
    hledger-ui
    hledger-utils
    hledger-interest
    hledger-web

    # Dev tools
    zed-editor
    zeal
    leetcode-cli
    bruno
    wakatime-cli
    delta
    aider-chat
    codecrafters-cli
    warp-terminal
    claude-agent-acp
    devbox

    # Nix tooling (the nixd language server lives in lsp.nix, which alucard
    # also imports — this package set is desktop-only)
    nix-output-monitor
    nixfmt

    # Tree-sitter
    (tree-sitter.withPlugins (g: [
      g.tree-sitter-rust
      g.tree-sitter-haskell
      g.tree-sitter-python
      g.tree-sitter-bash
      g.tree-sitter-typst
    ]))

    # Writing & docs
    typst
    tinymist
    texliveMedium
    hunspell
    hunspellDicts.en_US
    hunspellDicts.de_DE
    vale
    proselint

    # Docker tooling
    dockfmt
    dockerfile-language-server

    # Web dev
    html-tidy
    js-beautify
    stylelint

    # Utilities
    exercism
    ranger
    jq
    yq-go
    yt-dlp
    poppler-utils
    glow

    # Media
    nsxiv

    # Productivity
    anki
    zotero
    zoom-us

    # Japanese
    qolibri
    mecab
    kakasi
    cmigemo
    ani-cli

    # Communication
    discord
    telegram-desktop
    thunderbird
    slack
    signal-desktop
    teams-for-linux
  ];
}
