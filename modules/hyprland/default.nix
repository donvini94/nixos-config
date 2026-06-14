{ pkgs, inputs, ... }:
let
  # Animated greeter background: a CC0 purple-aurora-over-lake loop (Pexels
  # #34794659, 3238x2160) fetched at build time. Kept out of git, reproducible via
  # the fixed-output hash. Chosen to match the desktop wallpaper (magenta aurora)
  # and the magenta login panel. The black_hole layout only paints the right ~60%
  # of the screen behind the form, so at 2160 tall this covers that region with no
  # upscaling on the 5120x2160 ultrawide (PreserveAspectCrop trims the sides).
  auroraWallpaper = pkgs.fetchurl {
    name = "sddm-aurora-loop.mp4"; # extension matters: the theme QML branches on it
    url = "https://videos.pexels.com/video-files/34794659/14752174_3238_2160_25fps.mp4";
    hash = "sha256-r0n94I8aM/xjjcwihe2DxfHDFjXctPW/SfBml57QHYo=";
  };

  # Poster shown for the instant before the video starts (theme hides it on play).
  # A still frame OF the aurora itself, so there is no jarring flash of a different
  # image. Built from the clip above; no extra asset in git.
  auroraPoster = pkgs.runCommand "sddm-aurora-poster.png"
    { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } ''
      ffmpeg -ss 2 -i ${auroraWallpaper} -frames:v 1 -update 1 $out
    '';

  # unixporn SDDM greeter (sddm-astronaut, Qt6). Swap `embeddedTheme` for any of:
  #   astronaut · black_hole · cyberpunk · hyprland_kath · jake_the_dog
  #   japanese_aesthetic · pixel_sakura · pixel_sakura_static
  #   post-apocalyptic_hacker · purple_leaves
  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    # themeConfig is emitted as `black_hole.conf.user`, which SDDM MERGES over the
    # base conf (non-empty keys only). So this overrides ONLY the background and
    # keeps all of black_hole's styling. The QML branches on the file extension:
    # .mp4 → MediaPlayer/VideoOutput (FFmpeg backend, already bundled in
    # qtmultimedia). The absolute store path resolves to file:// via Qt.resolvedUrl;
    # the placeholder PNG shows instantly so there is no black flash while it loads.
    themeConfig = {
      Background = "${auroraWallpaper}";
      BackgroundPlaceholder = "${auroraPoster}";
    };
  };
in
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
    # X11-backed greeter on purpose: the Wayland greeter path (mesa/egl-wayland
    # + nvidia) was implicated in the June-2026 GDM black screen. The Hyprland
    # session still runs on Wayland; only the login greeter is Xorg.
    displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm; # Qt6 — required by sddm-astronaut
      wayland.enable = false; # X11 greeter
      theme = "sddm-astronaut-theme";
      extraPackages = sddm-astronaut.propagatedBuildInputs; # qtsvg, qtmultimedia, qtvirtualkeyboard
    };
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
    sddm-astronaut # provides the themed greeter at share/sddm/themes
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
