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
    # hyprsunset 0.3.3 has no geo provider, so day/night is fixed-time profiles rather
    # than computed from lat/long.
    hyprsunset = {
      enable = true;
      settings = {
        profile = [
          {
            time = "7:00";
            identity = true;
          }
          {
            time = "20:00";
            temperature = 4000;
            gamma = 100;
          }
        ];
      };
    };
  };
}
