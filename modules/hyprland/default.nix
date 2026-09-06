{ pkgs, inputs, ... }:
let
  # Nix path literal: the clip MUST be git-tracked or the flake won't see it.
  greeterWallpaper = ../../wallpapers/goku-shadow-sunset-dragon-ball-moewalls-com.mp4;

  # Placeholder shown until the video starts; the theme hides it on play.
  greeterPoster = pkgs.runCommand "sddm-greeter-poster.png"
    { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } ''
      ffmpeg -ss 2 -i ${greeterWallpaper} -frames:v 1 -update 1 $out
    '';

  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    # themeConfig is emitted as `black_hole.conf.user`, which SDDM MERGES over the
    # base conf (non-empty keys only). The QML branches on the Background file
    # extension: .mp4 → MediaPlayer/VideoOutput (FFmpeg backend, bundled in
    # qtmultimedia). Absolute store paths resolve to file:// via Qt.resolvedUrl.
    themeConfig = {
      Background = "${greeterWallpaper}";
      BackgroundPlaceholder = "${greeterPoster}";
      CropBackground = "true"; # region == video size (3840x2160), so this is a 1:1 no-op
      DimBackground = "0.0";

      # The theme sizes the form at `parent.width / 2.5` with no config key for it;
      # at 5120 that is a 2048px panel and the video keeps the remaining width.
      FormPosition = "left";
      HaveFormBackground = "true";

      # Palette hand-sampled from the wallpaper frame; re-derive it if the wallpaper changes.
      FormBackgroundColor = "#211728";
      BackgroundColor = "#211728";
      DimBackgroundColor = "#211728";
      DropdownBackgroundColor = "#211728";

      LoginFieldBackgroundColor = "#382342";
      PasswordFieldBackgroundColor = "#382342";

      LoginButtonBackgroundColor = "#fb5d37";
      HighlightBackgroundColor = "#fb5d37";
      DropdownSelectedBackgroundColor = "#fb5d37";
      HighlightBorderColor = "#ab3a51";

      TimeTextColor = "#fcda89";
      LoginFieldTextColor = "#fcda89";
      PasswordFieldTextColor = "#fcda89";
      UserIconColor = "#fcda89";
      PasswordIconColor = "#fcda89";
      SystemButtonsIconsColor = "#fcda89";
      SessionButtonTextColor = "#fcda89";
      VirtualKeyboardButtonTextColor = "#fcda89";
      DropdownTextColor = "#fcda89";

      HeaderTextColor = "#f7a35a";
      DateTextColor = "#f7a35a";

      LoginButtonTextColor = "#211728";
      HighlightTextColor = "#211728";

      PlaceholderTextColor = "#a8746e";
      WarningColor = "#f35d50";

      HoverUserIconColor = "#fb5d37";
      HoverPasswordIconColor = "#fb5d37";
      HoverSystemButtonsIconsColor = "#fb5d37";
      HoverSessionButtonTextColor = "#fb5d37";
      HoverVirtualKeyboardButtonTextColor = "#fb5d37";
    };
  };
in
{
  # programs.hyprland.enable already registers xdg-desktop-portal-hyprland; only the
  # gtk backend (org.freedesktop.portal.Settings, GTK file chooser) needs adding here.
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
      # The Dell U4025QW advertises 2560x1080 as its base-EDID preferred mode and
      # exposes native 5120x2160 only via a DisplayID extension; NVIDIA 595.84
      # auto-selects the 2560 base mode for the X greeter, squeezing the login form.
      # SDDM runs setupCommands in its Xsetup, so force native mode there; the
      # Wayland session sets its own mode. Output name is detected so this survives
      # NVIDIA's DP-N enumeration.
      displayManager.setupCommands = ''
        out=$(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gnugrep}/bin/grep -m1 ' connected' | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        [ -n "$out" ] && ${pkgs.xrandr}/bin/xrandr --output "$out" --mode 5120x2160 || true
      '';
    };
    # X11-backed greeter on purpose: the Wayland greeter path (mesa/egl-wayland +
    # nvidia) was implicated in the June-2026 GDM black screen. The Hyprland session
    # still runs on Wayland; only the login greeter is Xorg.
    displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm; # Qt6 — required by sddm-astronaut
      wayland.enable = false;
      theme = "sddm-astronaut-theme";
      extraPackages = sddm-astronaut.propagatedBuildInputs;
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

  # caelestia-shell already provides waybar, dunst, swww, swayidle, wlogout and the
  # wofi launcher; only add tools it does not.
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

    alsa-utils
    mpd
    mpc
    ncmpcpp

    thunar
  ];
}
