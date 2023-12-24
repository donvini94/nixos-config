{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Haskell
    cabal-install
    haskell-language-server
    ghc
    ghcid
    stack

    # Rust
    rust-analyzer
    rustup
    rustfmt
    # Python
    python311
    python311Packages.pip

    # Java
    jdk17

    # Nix
    nix-output-monitor
    nixfmt


    # Docs
    plantuml
  ];
}










