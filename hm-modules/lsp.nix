# Language servers for the OMP `lsp` tool.
#
# OMP auto-detects its built-in server definitions by intersecting two conditions: the
# working directory contains one of the server's rootMarkers, and the server binary
# resolves in a project-local bin directory or on $PATH. No lsp.json is needed for any of
# these — a config file is only for overrides, and adding one would switch off
# auto-detection for every server it does not mention.
#
# This module exists because the servers were previously reachable only as a side effect
# of the desktop package set, which alucard does not import: `lsp` was silently inert
# there for every language, while the harness system prompt requires it for definitions,
# references and renames. Both hosts import this module so symbol-aware editing behaves
# identically on each.
#
# One server per language, matching the OMP built-in keys (`rust-analyzer`, `basedpyright`,
# `ruff`, `nixd`, `jdtls`, `marksman`, `bashls`, `yamlls`). OMP keeps only one server per
# language for type intelligence and treats linter-only servers separately, so pairing
# `basedpyright` with `ruff` is the intended shape rather than a conflict.
#
# `basedpyright` is the navigation server, NOT a second type checker: rule://python makes
# `mypy --strict` the gate, and that stays true. mypy has no language server, and hover /
# go-to-definition / find-references are a different job from the CI gate.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Rust — rule://rust
    rust-analyzer

    # Python — navigation only; `mypy --strict` remains the gate per rule://python
    basedpyright
    ruff

    # Nix — this repository is the most-edited tree on every host
    nixd

    # Java — SailPoint ISC rule development per rule://isc-rule
    jdt-language-server

    # Prose, config, and shell
    marksman
    bash-language-server
    yaml-language-server
  ];
}
