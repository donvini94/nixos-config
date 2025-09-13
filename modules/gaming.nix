{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers

    };
    gamescope.enable = true;
  };
  programs.gamemode.enable = true;
  hardware.xone.enable = true; # support for the xbox controller USB dongle
  environment.systemPackages = with pkgs; [
    mangohud
    protonup
    bsnes-hd
    lutris
    wine-wayland
    winetricks
    wineWow64Packages.full
    mono
    (inputs.unstable.legacyPackages.x86_64-linux.heroic)
    pokemmo-installer
    egl-wayland
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  services.lsfg-vk = {
    enable = true;
    ui.enable = true; # installs gui for configuring lsfg-vk
  };
}
