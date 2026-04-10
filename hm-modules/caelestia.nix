{ pkgs, ... }:

{
  programs.caelestia = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar.status.showBattery = false;
      paths.wallpaperDir = "/home/vincenzo/nixos-config/wallpapers";
      background.desktopClock = {
        enabled = true;
        position = "bottom-right";
      };
      general.idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        timeouts = [
          { timeout = 300; idleAction = "lock"; }
          { timeout = 600; idleAction = "dpms off"; returnAction = "dpms on"; }
        ];
      };
      notifs.expire = true;
      lock.sizes.heightMult = 1.0;
      general.apps = {
        terminal = [ "kitty" ];
        audio = [ "pavucontrol" ];
        explorer = [ "kitty" "-e" "yazi" ];
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

  # Caelestia runtime dependencies not already in system modules
  home.packages = with pkgs; [
    xdg-desktop-portal-gtk
    hyprpicker
    cliphist
    inotify-tools
    app2unit
    trash-cli
    adw-gtk3
    papirus-icon-theme
    nerd-fonts.jetbrains-mono
    wtype
  ];
}
