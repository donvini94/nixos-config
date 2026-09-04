# Cross-platform CLI tooling — imported by every host with home-manager.
#
# The split from packages.nix is by PORTABILITY, not by taste: everything here builds and
# is binary-cached on both x86_64-linux and aarch64-darwin at the locked nixpkgs rev, so
# the Mac and dracula get an identical command line. packages.nix keeps what is
# Linux-desktop-only (GUI apps, Wayland/GTK stacks) or deliberately Linux-only (the
# hledger family: its Haskell closure is ~900 MiB download / 6 GiB unpacked and the Mac
# has no ledger).
#
# Package placement rule from AGENTS.md still applies: anything needing system-level
# integration goes in a system module, not here.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Search
    ripgrep-all
    television
    entr
    lnav

    # Document tools
    csvlens
    graphviz
    pandoc

    # Download
    aria2

    # Reference
    cht-sh
    tldr

    # Dev tools
    delta
    difftastic
    leetcode-cli
    wakatime-cli
    codecrafters-cli
    devbox

    # Nix tooling (the nixd language server lives in lsp.nix)
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

    # Japanese
    mecab
    kakasi
    cmigemo
    ani-cli
  ];
}
