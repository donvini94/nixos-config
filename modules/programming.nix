{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Haskell
    cabal-install
    haskell-language-server
    ghc
    ghcid
    stack
    haskellPackages.hoogle

    #go
    go
    gccgo
    gotools
    gore
    gotests
    gotest
    gopls
    gomodifytags

    # Rust
    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy
    jetbrains.rust-rover

    # Python
    python311
    python311Packages.pip
    nodePackages.pyright
    pipenv
    jetbrains.pycharm-professional
    black
    isort
    pipenv
    pytest
    nosetests

    # Web
    html-tidy
    js-beautify
    stylelint

    # Java
    jdk17

    # Nix
    nix-output-monitor
    nixfmt

    # Docs
    plantuml
    zeal

    # Tree-sitter
    tree-sitter
    tree-sitter-grammars.tree-sitter-rust
    tree-sitter-grammars.tree-sitter-haskell
    tree-sitter-grammars.tree-sitter-python

    # tooling
    devbox
    github-desktop
    sqlite
    shfmt
    shellcheck
    dockfmt
    oxker # docker tui
    lazydocker
    warp-terminal
    editorconfig
    nodePackages.bash-language-server
    dockerfile-language-server-nodejs
  ];
}
