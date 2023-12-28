{ config, lib, pkgs, ... }:

{

  networking.hostName = "dracula";


  programs.steam.enable = true;

  system.stateVersion = "23.11";
}
