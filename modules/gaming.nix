{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };
    gamescope.enable = true;
  };
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup
    bsnes-hd
    lutris
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

}
