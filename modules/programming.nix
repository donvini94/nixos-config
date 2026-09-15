{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # torch/transformers/accelerate below need real CUDA to be useful for GPU
  # work; only swap them for the CUDA wheel build on a host that actually has
  # an NVIDIA GPU (modules/nvidia.nix sets this). Hosts without one keep the
  # plain CPU torch, which nixpkgs' own cache already serves.
  cudaAvailable = lib.elem "nvidia" config.services.xserver.videoDrivers;
  pythonInterpreter =
    if cudaAvailable then
      (import ../lib/cuda-torch.nix {
        nixpkgsFlake = inputs.nixpkgs;
        system = pkgs.stdenv.hostPlatform.system;
      }).pythonFor
        "python313"
    else
      pkgs.python313;
in
{
  environment.systemPackages = with pkgs; [
    # Python (system CUDA linkage)
    (pythonInterpreter.withPackages (
      ps: with ps; [
        pip
        virtualenvwrapper
        scrapy
        pandas
        numpy
        requests
        beautifulsoup4
        debugpy
        torch
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
