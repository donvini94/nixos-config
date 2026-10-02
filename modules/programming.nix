{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    python313
    uv
    ty
    ruff

    rust-analyzer
    rustup
    rustfmt
    cargo-watch
    clippy
    rustc

    lldb
    gdb
    jdk21

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
