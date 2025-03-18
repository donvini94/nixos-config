{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Docs
    zeal

    # Haskell
    cabal-install
    haskell-language-server
    ghc
    ghcid
    stack
    haskellPackages.hoogle

    # Java
    jdk17
    jdk21

    # Nix
    nix-output-monitor
    nixfmt-rfc-style

    # Python
    python312
    python312Packages.pip
    python312Packages.virtualenvwrapper
    python312Packages.scrapy
    python312Packages.pandas
    python312Packages.numpy
    python312Packages.requests
    python312Packages.beautifulsoup4
    python312Packages.pyflakes
    python312Packages.debugpy
    pyright
    pipenv
    black
    isort
    pipenv

    # tooling
    devbox
    sqlite
    shfmt
    bash-language-server
    shellcheck
    dockfmt
    dockerfile-language-server-nodejs
    helix
    emacs30
    leetcode-cli
    bruno
    wakatime
    delta # syntax highlight pager for git
    aider-chat
    codecrafters-cli

    # Tree-sitter
    tree-sitter
    tree-sitter-grammars.tree-sitter-rust
    tree-sitter-grammars.tree-sitter-haskell
    tree-sitter-grammars.tree-sitter-python
    tree-sitter-grammars.tree-sitter-bash

    # Rust
    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy
    lldb
    gdb
    rustc

    # Web
    html-tidy
    nodePackages.js-beautify
    stylelint
    nodejs_22
  ];
}
