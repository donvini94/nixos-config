{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../modules/desktop.nix
    ../../modules/nvidia.nix
    ../../modules/gaming.nix
    ./hardware.nix
    ./services.nix
  ];

  networking = {
    hostName = "dracula";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  nixpkgs.config.cudaSupport = true;

  nix = {
    settings.trusted-users = [ "${username}" ];
    gc.dates = "weekly";
  };

  sops.age.keyFile = "/home/vincenzo/.config/sops/age/keys.txt";

  users.users."${username}" = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
      "audio"
    ];
    packages = with pkgs; [ firefox ];
  };

  system.stateVersion = "23.11";
}
