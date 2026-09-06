# Language servers for the OMP `lsp` tool.
#
# OMP auto-detects a built-in server when the working directory contains one of its
# rootMarkers and the binary resolves on $PATH. Do not add an lsp.json — a config file
# switches off auto-detection for every server it does not mention.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rust-analyzer

    # pyright and basedpyright must stay off $PATH: OMP resolves the Python server by
    # taking the first of pyright, basedpyright, pylsp, ty that appears there, so either
    # one silently demotes ty. `ty` navigates; `mypy --strict` is the gate per rule://python.
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
