{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Docs
    zeal

    zed-editor

    # Nix
    nix-output-monitor
    nixfmt-rfc-style

    # Python
    (python312.withPackages (
      ps: with ps; [
        pip
        virtualenvwrapper
        scrapy
        pandas
        numpy
        requests
        beautifulsoup4
        pyflakes
        debugpy
        torchWithCuda
        transformers
        pynvml
      ]
    ))
    pyright
    pipenv
    black
    isort
    uv

    # Tooling
    devbox
    sqlite
    shfmt
    bash-language-server
    shellcheck
    dockfmt
    dockerfile-language-server-nodejs
    helix
    emacs
    leetcode-cli
    bruno
    wakatime-cli
    delta
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
