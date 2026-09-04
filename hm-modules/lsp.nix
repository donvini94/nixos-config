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
# One server per language, matching the OMP built-in keys (`rust-analyzer`, `ty`, `ruff`,
# `nixd`, `jdtls`, `marksman`, `bashls`, `yamlls`). OMP keeps only one server per language
# for type intelligence and treats linter-only servers separately, so pairing `ty` with
# `ruff` is the intended shape rather than a conflict.
#
# Python is `ty` + `ruff`, matching what doom/config.org already registers (ty at priority
# 10, ruff as an add-on at 5) and what hosts/ac-0137/zed/settings.json already selects.
# basedpyright is deliberately ABSENT, not merely deprioritised: OMP resolves the Python
# server by taking the first of `pyright`, `basedpyright`, `pylsp`, `ty` that appears on
# $PATH, so ty is only ever reached when the other three are gone. Never add pyright or
# basedpyright to any host's PATH — it silently demotes ty everywhere.
#
# `ty` is the navigation server, NOT the CI gate: rule://python makes `mypy --strict` the
# gate and that stays true. mypy has no language server, and hover / go-to-definition /
# find-references are a different job from the gate.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Rust — rule://rust
    rust-analyzer

    # Python — `ty` for navigation, `ruff` for lint/format. `mypy --strict` remains the
    # gate per rule://python. See the header: basedpyright must stay off $PATH.
    ty
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
