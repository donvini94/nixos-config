# Language servers for the OMP `lsp` tool.
#
# OMP auto-detects a built-in server when the working directory contains one of its
# rootMarkers and the binary resolves on $PATH. Do not add an lsp.json — a config file
# switches off auto-detection for every server it does not mention.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rust-analyzer

    # OMP prioritizes pyright/basedpyright/pylsp over ty when they are on PATH.
    ty
    ruff

    nixd

    # SailPoint ISC rule development per rule://isc-rule.
    jdt-language-server

    marksman
    bash-language-server
    yaml-language-server
  ];
}
