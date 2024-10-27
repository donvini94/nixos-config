{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Docs
    plantuml
    zeal

    #go
    go
    gccgo
    gotools
    gore
    gotests
    gotest
    gopls
    gomodifytags

    # Haskell
    cabal-install
    haskell-language-server
    ghc
    ghcid
    stack
    haskellPackages.hoogle

    # Java
    jdk17

    # Nix
    nix-output-monitor
    nixfmt-rfc-style
    nil # nix language server

    # Python
    python312
    python312Packages.pip
    python312Packages.virtualenvwrapper
    python312Packages.scrapy
    python312Packages.pandas
    python312Packages.numpy
    python312Packages.requests
    python312Packages.beautifulsoup4
    pyright
    pipenv
    black
    isort
    pipenv

    # tooling
    devbox
    sqlite
    shfmt
    shellcheck
    dockfmt
    dockerfile-language-server-nodejs
    helix
    emacs29
    leetcode-cli
    postman
    bruno

    # Tree-sitter
    tree-sitter
    tree-sitter-grammars.tree-sitter-rust
    tree-sitter-grammars.tree-sitter-haskell
    tree-sitter-grammars.tree-sitter-python

    # Rust
    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy

    # Web
    html-tidy
    nodePackages.js-beautify
    stylelint
    nodejs_22
  ];
}
