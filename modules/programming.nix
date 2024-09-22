{
  config,
  lib,
  pkgs,
  ...
}:

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

    # Web
    html-tidy
    nodePackages.js-beautify
    stylelint
    nodejs_22

    # Java
    jdk17

    # Nix
    nix-output-monitor
    nixfmt-rfc-style

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
    sqlite
    shfmt
    shellcheck
    dockfmt
    dockerfile-language-server-nodejs
    helix
    emacs29

    # misc
    iosevka
  ];
}
