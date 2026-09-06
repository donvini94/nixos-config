# Sync target is the tailnet, not a public vhost; plain HTTP inside WireGuard.
{ lib, pkgs, ... }:

{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    # Darwin's Ctrl-R belongs to fisher's fzf.fish; atuin keeps Up-arrow only.
    flags = lib.optional pkgs.stdenv.hostPlatform.isDarwin "--disable-ctrl-r";
    settings = {
      auto_sync = true;
      sync_address = "http://alucard.tailf117a1.ts.net:28888";
      search_mode = "prefix";
    };
  };
}
