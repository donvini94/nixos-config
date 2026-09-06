{ pkgs, ... }:

{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

    };
    gamescope.enable = true;
  };
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renicer = 10;
        softrealtime = "auto";
        inhibit_screensaver = 1;
      };
    };
  };
  hardware.xone.enable = true; # Xbox controller USB dongle.
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-ng
    wine-wayland
    winetricks
    wineWow64Packages.full
    mono
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  services.lsfg-vk = {
    enable = true;
    ui.enable = true;
  };
}
