{ pkgs, ... }:

{
  programs.caelestia = {
    enable = true;
    systemd.enable = true;
    settings = {
      paths.wallpaperDir = "/home/vincenzo/nixos-config/wallpapers";
      background.desktopClock = {
        enabled = true;
        position = "bottom-right";
      };
      general.idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        timeouts = [
          {
            timeout = 300;
            idleAction = "lock";
          }
          {
            timeout = 600;
            idleAction = "dpms off";
            returnAction = "dpms on";
          }
        ];
      };
      notifs.expire = true;
      general.apps = {
        terminal = [ "kitty" ];
        audio = [ "pavucontrol" ];
        explorer = [
          "kitty"
          "-e"
          "yazi"
        ];
        playback = [ "mpv" ];
      };
    };
    cli = {
      enable = true;
      settings.theme = {
        enableGtk = true;
        enableQt = true;
        enableHypr = true;
      };
    };
  };

  # xdg-desktop-portal-gtk must stay registered system-side in modules/hyprland/default.nix
  # under xdg.portal.extraPortals; as a user binary xdg-desktop-portal will not delegate to it.
  home.packages = with pkgs; [
    hyprpicker
    cliphist
    inotify-tools
    app2unit
    trash-cli
    nerd-fonts.jetbrains-mono
    wtype
  ];
}
