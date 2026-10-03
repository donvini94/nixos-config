# The OMP harness only: no authored agent context, and no Requesty profile — that
# profile reads Vincenzo's key, so which accounts receive it is the spend boundary.
# Kyrill reaches Anthropic and Codex through his own subscription logins instead.
{ pkgs, ... }:

{
  home = {
    username = "kyrill";
    homeDirectory = "/home/kyrill";
    stateVersion = "25.11";
    packages = [ (pkgs.callPackage ../../packages/omp-harness.nix { }) ];
  };
}
