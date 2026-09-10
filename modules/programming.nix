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
        debugpy
        torchWithCuda
        transformers
        pynvml

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
    emacs-pgtk
    libvterm
    editorconfig-core-c

    sqlite
    nodejs_22

    shfmt
    bash-language-server
    shellcheck

    inputs.nil.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-code
    codex
  ];
}
