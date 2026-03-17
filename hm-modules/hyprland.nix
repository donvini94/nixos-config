{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      env = [
        # NVIDIA
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "NVD_BACKEND,direct"
        "AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1"

        # Wayland / toolkit
        "XDG_SESSION_TYPE,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "NIXOS_OZONE_WL,1"
        "QT_QPA_PLATFORMTHEME,qt6ct"

        # Cursor
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
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "master";
      };

      decoration = {
        rounding = 16;
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
        animation = [
          "border, 1, 2, default"
          "fade, 1, 2, default"
          "windows, 1, 2, default, popin 80%"
          "workspaces, 1, 2, default, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master.new_status = "inherit";

      misc = {
        enable_swallow = true;
        force_default_wallpaper = 0;
      };

      "$mod" = "SUPER";

      bind = [
        # ── Caelestia integrations ─────────────────────────────
        "$mod, R, global, caelestia:launcher"
        "$mod SHIFT, L, global, caelestia:lock"
        "CTRL ALT, Delete, global, caelestia:session"
        "CTRL ALT, C, global, caelestia:clearNotifs"
        "$mod SHIFT, G, global, caelestia:showall"
        "$mod SHIFT, Escape, global, caelestia:session"
        ", Print, global, caelestia:screenshotFreeze"
        "$mod, Print, global, caelestia:screenshot"

        # ── Window management ──────────────────────────────────
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive,"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen"
        "$mod, Y, togglesplit"
        "$mod, S, exec, grim -g \"$(slurp)\" - | wl-copy"

        # Navigate windows (vim-style j/k)
        "$mod, J, cyclenext"
        "$mod, K, cyclenext, prev"
        "$mod SHIFT, J, movewindow, l"
        "$mod SHIFT, K, movewindow, r"

        # Master layout: resize and promote
        "$mod, H, layoutmsg, mfact -0.05"
        "$mod, L, layoutmsg, mfact +0.05"
        "$mod, space, layoutmsg, swapwithmaster"

        # Scratchpad: persistent hidden workspace
        "$mod, minus, togglespecialworkspace, scratchpad"
        "$mod SHIFT, minus, movetoworkspace, special:scratchpad"

        # Clipboard history
        "$mod, period, exec, cliphist list | wofi -d | cliphist decode | wl-copy"

        # ── Emacs ──────────────────────────────────────────────
        "$mod, E, exec, emacsclient -a '' -c"
        "$mod, C, exec, emacsclient -a '' -n -e '(make-orgcapture-frame)'"
        "$mod, O, exec, emacsclient -a '' -e '(org-agenda nil \"a\")'"

        # ── Apps ───────────────────────────────────────────────
        "$mod, W, exec, firefox"
        "$mod, A, exec, steam-run anki"
        "$mod, Z, exec, zotero"
        "$mod, N, exec, kitty -e yazi"
        "$mod, T, exec, darkman toggle"
        "$mod, B, exec, blueman"
        "$mod, G, exec, steam"
        "$mod, M, exec, thunderbird"
        "$mod, D, exec, kitty -e lazydocker"
        "$mod SHIFT, N, exec, thunar"
        "$mod SHIFT, D, exec, discord"
        "$mod SHIFT, T, exec, telegram-desktop"
        "$mod SHIFT, S, exec, signal-desktop"
        "$mod, P, exec, wofi-pass -i -s -c"
        "$mod SHIFT, P, exec, pavucontrol"
        "$mod SHIFT, H, exec, kitty -e btop"

        # ── Workspaces ─────────────────────────────────────────
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

      # Resize master with repeat
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
  };
}
