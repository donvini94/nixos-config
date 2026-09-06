{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    # HM's default configType flipped to "lua"; the config below is hyprlang.
    configType = "hyprlang";
    settings = {
      env = [
        # Host-specific GPU ordering for the Aquamarine backend.
        "AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1"

        "XDG_SESSION_TYPE,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "NIXOS_OZONE_WL,1"
        "QT_QPA_PLATFORMTHEME,qt6ct"

        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Bibata-Modern-Ice"
        "HYPRCURSOR_THEME,Bibata-Modern-Ice"
        "HYPRCURSOR_SIZE,24"
      ];

      cursor.no_hardware_cursors = true;

      exec-once = [
        "nm-applet --indicator"
        "wl-paste --watch cliphist store"
        "hyprctl setcursor Bibata-Modern-Ice 24"
      ];

      monitor = ",highres@highrr,auto,auto";

      input = {
        kb_layout = "us,de";
        follow_mouse = 1;
        repeat_rate = 50;
        repeat_delay = 200;
        kb_options = "caps:escape, grp:alt_shift_toggle";
        touchpad = {
          natural_scroll = false;
          disable_while_typing = true;
        };
        sensitivity = "1.0";
      };

      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        # Border colours are set in extraConfig below: HM sorts top-level settings keys
        # alphabetically, so a `source` key would emit AFTER `general`, leaving $primary
        # undefined at point of use.
        layout = "master";
      };

      decoration = {
        rounding = 16;
        dim_inactive = true;
        dim_strength = "0.1";
        blur = {
          enabled = true;
          size = 10;
          passes = 1;
          new_optimizations = true;
          brightness = "1.0";
          noise = "0.02";
        };
      };

      xwayland.force_zero_scaling = true;

      animations = {
        enabled = true;
        # HM hoists `bezier` (importantPrefix), so the curves are defined before the
        # animation block uses them.
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "overshot, 0.05, 0.9, 0.1, 1.05"
          "almostLinear, 0.5, 0.5, 0.75, 1.0"
        ];
        animation = [
          "windows, 1, 3.5, overshot, popin 80%"
          "windowsOut, 1, 3, easeOutQuint, popin 80%"
          "border, 1, 5.4, easeOutQuint"
          "fade, 1, 3, almostLinear"
          "workspaces, 1, 4, easeOutQuint, slide"
        ];
      };

      master.new_status = "inherit";

      misc = {
        enable_swallow = true;
        force_default_wallpaper = 0;
      };

      # Pause caelestia's idle monitor while any window is fullscreen: gamepad input
      # bypasses wl_seat, so games never reset the idle timer. Hyprland holds the Wayland
      # idle-inhibitor and caelestia honors it via IdleMonitor.respectInhibitors.
      # Hyprland 0.55 rewrote the rule engine to v3 flat syntax, where matchers need a
      # `match:` prefix: pre-0.55 `idleinhibit fullscreen, class:.*` is now
      # `idle_inhibit fullscreen, match:class .*`.
      windowrule = [
        "idle_inhibit fullscreen, match:class .*"
      ];

      "$mod" = "SUPER";

      bind = [
        "$mod, R, global, caelestia:launcher"
        "$mod SHIFT, L, global, caelestia:lock"
        "CTRL ALT, Delete, global, caelestia:session"
        "CTRL ALT, C, global, caelestia:clearNotifs"
        "$mod SHIFT, G, global, caelestia:showall"
        "$mod SHIFT, Escape, global, caelestia:session"
        ", Print, global, caelestia:screenshotFreeze"
        "$mod, Print, global, caelestia:screenshot"
        "$mod, BackSpace, global, caelestia:sidebar"

        "$mod, Return, exec, kitty"
        "$mod, Q, killactive,"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen"
        "$mod, Y, layoutmsg, orientationnext"
        "$mod, S, exec, grim -g \"$(slurp)\" - | wl-copy"

        "$mod, J, cyclenext"
        "$mod, K, cyclenext, prev"
        "$mod SHIFT, J, movewindow, l"
        "$mod SHIFT, K, movewindow, r"

        "$mod, H, layoutmsg, mfact -0.05"
        "$mod, L, layoutmsg, mfact +0.05"
        "$mod, space, layoutmsg, swapwithmaster"

        "$mod, minus, togglespecialworkspace, scratchpad"
        "$mod SHIFT, minus, movetoworkspace, special:scratchpad"

        "$mod, period, exec, cliphist list | wofi -d | cliphist decode | wl-copy"

        "$mod, E, exec, emacsclient -a '' -c"
        "$mod, C, exec, emacsclient -a '' -n -e '(make-orgcapture-frame)'"
        "$mod, O, exec, emacsclient -a '' -e '(org-agenda nil \"a\")'"

        "$mod, W, exec, firefox"
        "$mod, A, exec, steam-run anki"
        "$mod, Z, exec, zotero"
        "$mod, N, exec, kitty -e yazi"
        "$mod, T, exec, darkman toggle"
        "$mod, B, exec, blueman"
        "$mod, G, exec, mangohud steam"
        "$mod, M, exec, thunderbird"
        "$mod, D, exec, kitty -e lazydocker"
        "$mod SHIFT, N, exec, thunar"
        "$mod SHIFT, D, exec, discord"
        "$mod SHIFT, T, exec, telegram-desktop"
        "$mod SHIFT, S, exec, signal-desktop"
        "$mod, P, exec, wofi-pass -i -s -c"
        "$mod SHIFT, P, exec, pavucontrol"
        "$mod SHIFT, H, exec, kitty -e btop"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      binde = [
        ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
        ", XF86MonBrightnessDown, global, caelestia:brightnessDown"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bindle = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l \"1.0\" @DEFAULT_AUDIO_SINK@ 6%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l \"1.0\" @DEFAULT_AUDIO_SINK@ 6%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];
    };

    # caelestia writes ~/.config/hypr/scheme/current.conf at runtime, defining $primary,
    # $tertiary, $surfaceVariant as bare hex; re-declaring the border colours here tracks
    # the active wallpaper palette. It must be extraConfig and not settings.source: HM
    # appends extraConfig verbatim AFTER the generated settings, so `source` is evaluated
    # before the $vars are used and this `general {}` overrides the structured one above.
    # current.conf is runtime state, not reproducible from a bare checkout — run
    # `caelestia scheme set -n dynamic` once on a fresh machine; if the file is missing
    # hyprland logs a source error and keeps defaults.
    extraConfig = ''
      source = /home/vincenzo/.config/hypr/scheme/current.conf
      general {
        col.active_border = rgb($primary) rgb($tertiary) 45deg
        col.inactive_border = rgb($surfaceVariant)
      }
    '';
  };
}
