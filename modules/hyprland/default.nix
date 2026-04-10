{ pkgs, inputs, ... }:
{
  xdg.portal.enable = true;

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
    xdg-desktop-portal-hyprland
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
