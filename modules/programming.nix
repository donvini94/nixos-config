{
  pkgs,
  unstablePkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Docs
    zeal

    unstablePkgs.zed-editor

    # Nix
    nix-output-monitor
    nixfmt
    nixd

    # Java (system JDK for jdtls — project JDKs come from devbox)
    jdk21

    # Python
    (python313.withPackages (
      ps: with ps; [
        pip
        virtualenvwrapper
        scrapy
        pandas
        numpy
        requests
        beautifulsoup4
        pyflakes # TODO: ruff replaces this — remove once ruff is confirmed working
        debugpy
        torchWithCuda
        transformers
        pynvml

        # ML / data science
        jupyter
        jupyterlab
        matplotlib
        seaborn
        scikit-learn
        datasets
        accelerate
        wandb
        tensorboard
      ]
    ))
    ty
    ruff
    pipenv
    uv

    # Tooling
    devbox
    sqlite
    shfmt
    bash-language-server
    shellcheck
    dockfmt
    dockerfile-language-server
    helix
    emacs30-pgtk
    leetcode-cli
    bruno
    wakatime-cli
    delta
    aider-chat
    codecrafters-cli
    warp-terminal
    claude-code-acp

    # Tree-sitter
    tree-sitter
    tree-sitter-grammars.tree-sitter-rust
    tree-sitter-grammars.tree-sitter-haskell
    tree-sitter-grammars.tree-sitter-python
    tree-sitter-grammars.tree-sitter-bash
    tree-sitter-grammars.tree-sitter-typst

    # Rust
    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy
    lldb
    gdb
    rustc

    # Typst
    typst
    tinymist

    # Docs & writing
    texlive.combined.scheme-medium
    hunspell
    hunspellDicts.en_US
    hunspellDicts.de_DE
    vale
    proselint

    # Emacs support
    libvterm
    editorconfig-core-c

    # Web
    html-tidy
    nodePackages.js-beautify
    stylelint
    nodejs_22
  ];
}
