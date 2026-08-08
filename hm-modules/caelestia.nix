{ pkgs, ... }:

{
  programs.caelestia = {
    enable = true;
    systemd.enable = true;
    settings = {
      # NOTE: caelestia dropped `bar.status.showBattery`; the bar's battery is now
      # an entry in the `bar.statusIcons` list. Omitted entirely here — this is a
      # battery-less desktop, so caelestia renders no battery icon regardless.
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

  # Caelestia runtime dependencies not already in system modules.
  # xdg-desktop-portal-gtk lives in modules/hyprland/default.nix under
  # xdg.portal.extraPortals — it must be registered system-side, not installed
  # as a user binary, or xdg-desktop-portal will not delegate to it.
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
