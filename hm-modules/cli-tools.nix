# Cross-platform CLI tooling — imported by every host with home-manager.
#
# The split from packages.nix is by portability: everything here builds and is binary-cached
# on both x86_64-linux and aarch64-darwin at the locked nixpkgs rev.
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
    # lazygit backs the `lg` abbreviation in hm-modules/fish.nix.
    lazygit
    delta
    difftastic
    gh
    leetcode-cli
    wakatime-cli
    codecrafters-cli
    devbox

    # The nixd language server lives in lsp.nix.
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
