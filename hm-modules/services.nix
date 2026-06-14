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
    # Hyprland-native blue-light filter (replaces gammastep, which kept losing
    # its wlr-gamma-control connection on hyprctl reload / rebuild and looping).
    # NOTE: hyprsunset uses Hyprland's CTM protocol — verify it actually engages
    # on the NVIDIA driver (see comment below). 0.3.3 has no geo provider, so
    # day/night is fixed-time profiles rather than computed from lat/long.
    hyprsunset = {
      enable = true;
      settings = {
        profile = [
          {
            time = "7:00";
            identity = true; # daytime: no colour shift
          }
          {
            time = "20:00";
            temperature = 4000; # evening: warm
            gamma = 100;
          }
        ];
      };
    };
  };
}
