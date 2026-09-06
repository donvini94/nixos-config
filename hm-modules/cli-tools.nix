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
{
  lib,
  pkgs,
  ...
}:

let
  # omp-learn requires Bun >= 1.3.14, while the locked nixpkgs has 1.3.13.
  # Remove this override when nixpkgs catches up.
  bunVersion = "1.4.2";
  bunSource =
    {
      aarch64-darwin = {
        archive = "bun-darwin-aarch64";
        hash = "sha256-kJh6OhbX21VtiGrD1VHnttPt8KHPQ6yu1iLoZ2vh0S8=";
      };
      aarch64-linux = {
        archive = "bun-linux-aarch64";
        hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
      };
      x86_64-darwin = {
        archive = "bun-darwin-x64-baseline";
        hash = "sha256-utW71s8U0JgNEV9ZVMn/kE32GdXplNLaH/zNPzFjALA=";
      };
      x86_64-linux = {
        archive = "bun-linux-x64-baseline";
        hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system};
  bun = pkgs.bun.overrideAttrs {
    version = bunVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/${bunSource.archive}.zip";
      inherit (bunSource) hash;
    };
    sourceRoot = bunSource.archive;
  };
in
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
    bun
    # lazygit backs the `lg` abbreviation in hm-modules/fish.nix, so it has to
    # exist wherever that module is imported.
    lazygit
    delta
    difftastic
    gh
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
