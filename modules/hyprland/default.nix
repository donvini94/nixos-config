{ pkgs, inputs, ... }:
let
  # Animated greeter background: a user-supplied Dragon Ball "Goku sunset" loop,
  # 3840x2160 @60fps, living in-repo under wallpapers/. NOTE: this is a Nix path
  # literal, so the file MUST be git-tracked or the flake won't see it (and it is a
  # ~62MB binary committed to the repo — a deliberate tradeoff for using a local,
  # curated clip instead of an external fetch). The basename keeps its .mp4
  # extension, which the theme QML needs to pick the MediaPlayer (video) branch.
  greeterWallpaper = ../../wallpapers/goku-shadow-sunset-dragon-ball-moewalls-com.mp4;

  # Poster shown for the instant before the video starts (theme hides it on play).
  # A still frame OF the clip itself, so there is no jarring flash. Built at build
  # time; no extra committed asset.
  greeterPoster = pkgs.runCommand "sddm-greeter-poster.png"
    { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } ''
      ffmpeg -ss 2 -i ${greeterWallpaper} -frames:v 1 -update 1 $out
    '';

  # unixporn SDDM greeter (sddm-astronaut, Qt6). Swap `embeddedTheme` for any of:
  #   astronaut · black_hole · cyberpunk · hyprland_kath · jake_the_dog
  #   japanese_aesthetic · pixel_sakura · pixel_sakura_static
  #   post-apocalyptic_hacker · purple_leaves
  sddm-astronaut = (pkgs.sddm-astronaut.override {
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

      # Layout: solid panel on the LEFT, video to its right (anchored to the form).
      # The form WIDTH is patched in Main.qml below (no config key for it).
      FormPosition = "left";
      HaveFormBackground = "true";

      # --- Palette adapted to the Goku-sunset wallpaper (colours sampled from the
      # frame: dark-purple base, sun-orange accent, warm-cream text, coral warning).
      # Re-derive these if the wallpaper changes. ---
      FormBackgroundColor = "#211728"; # dominant dark purple → the solid left panel
      BackgroundColor = "#211728";
      DimBackgroundColor = "#211728";
      DropdownBackgroundColor = "#211728";

      LoginFieldBackgroundColor = "#382342"; # mid dark purple, distinct from panel
      PasswordFieldBackgroundColor = "#382342";

      LoginButtonBackgroundColor = "#fb5d37"; # sun orange = accent
      HighlightBackgroundColor = "#fb5d37";
      DropdownSelectedBackgroundColor = "#fb5d37";
      HighlightBorderColor = "#ab3a51";

      TimeTextColor = "#fcda89"; # warm cream = primary text (high contrast on dark)
      LoginFieldTextColor = "#fcda89";
      PasswordFieldTextColor = "#fcda89";
      UserIconColor = "#fcda89";
      PasswordIconColor = "#fcda89";
      SystemButtonsIconsColor = "#fcda89";
      SessionButtonTextColor = "#fcda89";
      VirtualKeyboardButtonTextColor = "#fcda89";
      DropdownTextColor = "#fcda89";

      HeaderTextColor = "#f7a35a"; # secondary text = softer orange
      DateTextColor = "#f7a35a";

      LoginButtonTextColor = "#211728"; # dark text on the orange accent (contrast)
      HighlightTextColor = "#211728";

      PlaceholderTextColor = "#a8746e"; # muted warm
      WarningColor = "#f35d50"; # coral red = alert

      HoverUserIconColor = "#fb5d37";
      HoverPasswordIconColor = "#fb5d37";
      HoverSystemButtonsIconsColor = "#fb5d37";
      HoverSessionButtonTextColor = "#fb5d37";
      HoverVirtualKeyboardButtonTextColor = "#fb5d37";
    };
  }).overrideAttrs (old: {
    # The login-form width is hard-coded in Main.qml (`parent.width / 2.5`) with no
    # config key. Repoint it so on the 5120-wide ultrawide the video keeps its
    # NATIVE 3840px on the right and the form takes the remaining 1280px (1:1, no
    # scaling). The Math.max floor keeps the form usable if the greeter ever comes
    # up narrower than 5120 (e.g. NVIDIA auto-selecting the monitor's 2560 base-EDID
    # mode): `parent.width - 3840` == `parent.width * 0.25` at exactly 5120, so the
    # intended layout is unchanged, but the form can never collapse to <=0 width.
    # Use postFixup, NOT postInstall: the override's custom installPhase never calls
    # `runHook postInstall`, but fixupPhase runs by default and calls postFixup.
    postFixup = (old.postFixup or "") + ''
      f=$out/share/sddm/themes/sddm-astronaut-theme/Main.qml
      chmod u+w "$f"
      substituteInPlace "$f" --replace 'parent.width / 2.5' 'Math.max(parent.width - 3840, parent.width * 0.25)'
    '';
  });
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
      # The Dell U4025QW advertises 2560x1080 as its base-EDID preferred mode and
      # exposes native 5120x2160 only via a DisplayID extension. NVIDIA 595.84
      # auto-selects the 2560 base mode for the X greeter (it picked 5120 before
      # the driver bump), which squeezes the login form. SDDM runs setupCommands
      # in its Xsetup, so force native mode there. Session is Wayland/Hyprland and
      # unaffected (it sets its own mode via `highres`). Output name is detected so
      # this survives NVIDIA's DP-N enumeration.
      displayManager.setupCommands = ''
        out=$(${pkgs.xrandr}/bin/xrandr --query | ${pkgs.gnugrep}/bin/grep -m1 ' connected' | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        [ -n "$out" ] && ${pkgs.xrandr}/bin/xrandr --output "$out" --mode 5120x2160 || true
      '';
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
