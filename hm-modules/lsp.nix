# Language servers on the user PATH.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rust-analyzer

    ty
    ruff

    nixd

    # SailPoint ISC Java rule development.
    jdt-language-server

    marksman
    bash-language-server
    yaml-language-server
  ];
}
