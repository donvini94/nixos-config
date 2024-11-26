{ config, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = { };
    extraConfig = ''


      env = XCURSOR_SIZE,24
      env = AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1
      env = HYPRCURSOR_THEME,Bibata-Modern-Ice
      env = HYPRCURSOR_SIZE,24
      env = XDG_CURRENT_DESKTOP,Hyprland
      env = LIBVA_DRIVER_NAME,nvidia
      env = XDG_SESSION_TYPE,wayland
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = NVD_BACKEND,direct
      env = QT_IM_MODULE,fcitx
      env = XMODIFIERS,@im=fcitx
      cursor {
          no_hardware_cursors = true
      }


      exec-once = dunst
      exec-once = waybar
      exec-once = nm-applet --indicator &
      exec-once = hyprctl setcursor Bibata-Modern-Ice 24
      exec-once = swww-daemon
      exec-once = fcitx5

      # See https://wiki.hyprland.org/Configuring/Monitors/
      monitor=,preferred,auto,auto

      input {
          kb_layout = us,de
          follow_mouse = 1
          repeat_rate = 50
          repeat_delay = 200
          kb_options = caps:escape, grp:alt_shift_toggle
          touchpad {
              natural_scroll = no
              disable_while_typing = true
          }
          sensitivity = 1.0 # -1.0 - 1.0, 0 means no modification.
      }

      general {
          gaps_in = 5
          gaps_out = 5
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          layout = master
      }

      decoration {
          rounding = 16
          blur {
              enabled = true
              size = 10
              passes = 1
              new_optimizations = true
              brightness = 1.0
              noise = 0.02
          }
      }
      xwayland {
            force_zero_scaling = true
          }

       animations {
            enabled = true
            animation = border, 1, 2, default
            animation = fade, 1, 2, default
            animation = windows, 1, 2, default, popin 80%
            animation = workspaces, 1, 2, default, slide
          }


      dwindle {
          pseudotile = true # master switch for pseudotiling. Enabling is bound to mod + P in the keybinds section below
          preserve_split = yes # you probably want this
      }

      master {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          new_status = inherit
      }

      gestures {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = off
      }

      misc {
            enable_swallow = true
            force_default_wallpaper = 0
      }

      windowrulev2 = opacity 0.9 0.9,class:^(kitty)$

      # Screensharing rules for XWayland applications like discord
      windowrulev2 = opacity 0.0 override, class:^(xwaylandvideobridge)$
      windowrulev2 = noanim, class:^(xwaylandvideobridge)$
      windowrulev2 = noinitialfocus, class:^(xwaylandvideobridge)$
      windowrulev2 = maxsize 1 1, class:^(xwaylandvideobridge)$
      windowrulev2 = noblur, class:^(xwaylandvideobridge)$

      $mod = SUPER
      bind = $mod, Return, exec, kitty
      bind = $mod, Q, killactive,
      bind = $mod, E, exec, emacsclient -c
      bind = $mod, C, exec, emacsclient -n -e '(make-orgcapture-frame)'
      bind = $mod, V, togglefloating,
      bind = $mod, R, exec, wofi --show drun
      bind = $mod, S, exec, grim -g "$(slurp)" - | wl-copy
      bind = $mod, L, exec, swaylock
      bind = $mod, Y, togglesplit
      bind = $mod_SHIFT, Escape, exec, wlogout -p layer-shell


      # Launch programs with keybind
      bind = $mod, W, exec, firefox
      bind = $mod, A, exec, anki
      bind = $mod, Z, exec, zotero
      bind = $mod, N, exec, kitty -e yazi
      bind = $mod, T, exec, darkman toggle
      bind = $mod_SHIFT, N, exec, pcmanfm
      bind = $mod, B, exec, blueberry
      bind = $mod_SHIFT, D, exec, discord
      bind = $mod_SHIFT, T, exec, telegram-desktop
      bind = $mod_SHIFT, S, exec, signal-desktop
      bind = $mod_SHIFT, P, exec, pavucontrol
      bind = $mod, P, exec, passmenu -i
      bind = $mod_SHIFT, H, exec, kitty -e btop
      bind = $mod , D, exec, kitty -e lazydocker
      bind = $mod, G, exec, gamescope -W 3840 -H 2160 -r 60 -e -- steam

      # Window Navigation
      bind = $mod, J, cyclenext
      bind = $mod, K, cyclenext, prev
      bind = $mod, F, fullscreen

      bind = $mod_SHIFT, J, movewindow, l
      bind = $mod_SHIFT, K, movewindow, r

      # Switch workspaces with mod + [0-9]
      bind = $mod, 1, workspace, 1
      bind = $mod, 2, workspace, 2
      bind = $mod, 3, workspace, 3
      bind = $mod, 4, workspace, 4
      bind = $mod, 5, workspace, 5
      bind = $mod, 6, workspace, 6
      bind = $mod, 7, workspace, 7
      bind = $mod, 8, workspace, 8
      bind = $mod, 9, workspace, 9
      bind = $mod, 0, workspace, 10

      # Move active window to a workspace with mod + SHIFT + [0-9]
      bind = $mod SHIFT, 1, movetoworkspace, 1
      bind = $mod SHIFT, 2, movetoworkspace, 2
      bind = $mod SHIFT, 3, movetoworkspace, 3
      bind = $mod SHIFT, 4, movetoworkspace, 4
      bind = $mod SHIFT, 5, movetoworkspace, 5
      bind = $mod SHIFT, 6, movetoworkspace, 6
      bind = $mod SHIFT, 7, movetoworkspace, 7
      bind = $mod SHIFT, 8, movetoworkspace, 8
      bind = $mod SHIFT, 9, movetoworkspace, 9
      bind = $mod SHIFT, 0, movetoworkspace, 10

      # Scroll through existing workspaces with mod + scroll
      bind = $mod, mouse_down, workspace, e+1
      bind = $mod, mouse_up, workspace, e-1

      # Move/resize windows with mod + LMB/RMB and dragging
      bindm = $mod, mouse:272, movewindow
      bindm = $mod, mouse:273, resizewindow

      # volume
      bindle = , XF86AudioRaiseVolume, exec, wpctl set-volume -l "1.0" @DEFAULT_AUDIO_SINK@ 6%+
      bindle = , XF86AudioLowerVolume, exec, wpctl set-volume -l "1.0" @DEFAULT_AUDIO_SINK@ 6%-
      bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindl = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

      # backlight
      bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
      bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-



    '';
  };
}
