{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.mpv = {
    enable = true;
    bindings = {
      l = "seek 5";
      h = "seek -5";
      j = "seek -60";
      k = "seek 60";
      S = "cycle sub";
      f = "cycle fullscreen";
      "[" = "multiply speed 1/1.1";
      "]" = "multiply speed 1.1";
      I = "cycle-values vf 'sub,lavfi=negate' ''";
    };
    config = {

      hwdec = "auto";
      vo = "gpu";
      profile = "gpu-hq";
      gpu-context = "wayland";
    };
  };
}
