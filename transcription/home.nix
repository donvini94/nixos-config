{ pkgs, ... }:
{
  home.packages = with pkgs; [
    handy
    wtype
    wl-clipboard
  ];

  wayland.windowManager.hyprland.settings = {
    exec-once = [ "${pkgs.handy}/bin/handy --start-hidden" ];
    bind = [ "$mod, grave, exec, ${pkgs.handy}/bin/handy --toggle-transcription" ];
  };
}
