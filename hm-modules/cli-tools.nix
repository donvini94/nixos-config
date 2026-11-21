# CLI tools shared by Linux and Darwin.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ripgrep-all
    television
    entr
    lnav

    csvlens
    graphviz
    pandoc

    aria2

    cht-sh
    tldr

    bun
    # Doom :term ghostel compiles its native module with zig (M-x ghostel-module-compile).
    zig
    # lazygit backs the `lg` abbreviation in hm-modules/fish.nix.
    lazygit
    delta
    difftastic
    gh
    leetcode-cli
    wakatime-cli
    codecrafters-cli
    devbox
    devenv

    # The nil language server lives in lsp.nix.
    nix-output-monitor
    nixfmt

    (tree-sitter.withPlugins (g: [
      g.tree-sitter-rust
      g.tree-sitter-haskell
      g.tree-sitter-python
      g.tree-sitter-bash
      g.tree-sitter-typst
    ]))

    typst
    tinymist
    hunspell
    hunspellDicts.en_US
    hunspellDicts.de_DE
    vale
    proselint

    dockfmt
    dockerfile-language-server

    html-tidy
    js-beautify
    stylelint

    exercism
    ranger
    jq
    yq-go
    yt-dlp
    poppler-utils
    glow

    mecab
    kakasi
    cmigemo
    ani-cli
  ];
}
