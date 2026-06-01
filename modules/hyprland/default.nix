{ pkgs, inputs, ... }:
{
  # programs.hyprland.enable already registers xdg-desktop-portal-hyprland
  # via xdg.portal.{extraPortals,configPackages}. We only need to add the gtk
  # backend, which provides org.freedesktop.portal.Settings (used by Qt/GTK
  # apps to read color-scheme/font-config) and the GTK file chooser.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  environment.pathsToLink = [ "/libexec" ];

  services = {
    gvfs.enable = true;
    tumbler.enable = true;
    displayManager.defaultSession = "hyprland";
    xserver = {
      enable = true;
      desktopManager.xterm.enable = false;
      xkb.layout = "us";
      xkb.options = "caps:escape, grp:alt_shift_toggle";
    };
    displayManager.gdm.enable = true;
  };

  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      xwayland.enable = true;
    };
    thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Caelestia-shell replaces: waybar, dunst, swww, swayidle, wlogout, wofi (launcher)
  # Keep only tools that caelestia does NOT provide
  environment.systemPackages = with pkgs; [
    wl-clipboard
    pass-wayland
    wofi # needed for wofi-pass
    egl-wayland
    wf-recorder
    grim
    slurp
    yad

    # Audio
    alsa-utils
    mpd
    mpc
    ncmpcpp

    thunar
  ];
}
