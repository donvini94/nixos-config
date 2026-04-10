{ ... }:

{
  services = {
    udiskie.enable = true;
    syncthing.enable = true;
    mpd = {
      enable = true;
      musicDirectory = "/media/music";
      network.startWhenNeeded = true;
    };
    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 49.782959;
      longitude = 7.65118;
    };
  };
}
