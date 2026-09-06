# The OMP harness only: no authored agent context, and no Requesty ingress
# profile — the ingress binds loopback and does no per-user authorization, so
# which accounts receive the profile is the spend boundary on Vincenzo's single
# upstream key. Kyrill reaches Anthropic and Codex through his own subscription
# logins instead.
{ pkgs, ... }:

{
  home = {
    username = "kyrill";
    homeDirectory = "/home/kyrill";
    stateVersion = "25.11";
    packages = [ (pkgs.callPackage ../../packages/omp-harness.nix { }) ];
  };
}
