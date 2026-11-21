{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python313
    uv
    ty
    ruff

    rust-analyzer
    rustup
    cargo-watch
    dioxus-cli
    binaryen # wasm-opt; nixpkgs dx is built with no-downloads
    tailwindcss_4

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

    claude-code
    codex
  ];
}
