{
  pkgs,
  inputs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    # Python (system CUDA linkage)
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

    # Rust (system toolchain)
    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy
    rustc

    # Debuggers (need ptrace capabilities)
    lldb
    gdb

    # Java (system JDK for jdtls)
    jdk21

    # Emacs (system service in modules/services.nix)
    emacs30-pgtk
    libvterm
    editorconfig-core-c

    # System runtimes
    sqlite
    nodejs_22

    # Shell tooling (system scripts)
    shfmt
    bash-language-server
    shellcheck

    # Nix LSP and tools from flake inputs
    inputs.nil.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-code
  ];
}
