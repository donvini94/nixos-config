{ pkgs, inputs, ... }:
{
  xdg.portal = {
    enable = true;
    configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [ "/libexec" ]; # links /libexec from derivations to /run/current-system/sw
  services = {
    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images
    displayManager.defaultSession = "hyprland";
    xserver = {
      enable = true;
      desktopManager = {
        xterm.enable = false;
      };
      displayManager = {
        gdm.enable = true;
      };
    };
  };

  programs = {
    hyprland = {

      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      xwayland.enable = true;
    };
    # monitor backlight control
    light.enable = true;
    thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    waybar # the status bar
    swww # the wallpaper
    swayidle # the idle timeout
    wlogout # logout menu
    wl-clipboard # copying and pasting
    xwaylandvideobridge

    pass-wayland
    wofi
    nwg-look
    lxappearance
    hyprcursor
    bibata-cursors
    egl-wayland

    xdg-desktop-portal-hyprland
    wf-recorder # creen recording
    grim # taking screenshots
    slurp # selecting a region to screenshot

    #mako # the notification daemon, the same as dunst
    dunst
    yad # a fork of zenity, for creating dialogs

    # audio
    alsa-utils # provides amixer/alsamixer/...
    mpd # for playing system sounds
    mpc-cli # command-line mpd client
    ncmpcpp # a mpd client with a UI
    networkmanagerapplet # provide GUI app: nm-connection-editor

    xfce.thunar # xfce4's file manager
  ];

  # fix https://github.com/ryan4yin/nix-config/issues/10
}
