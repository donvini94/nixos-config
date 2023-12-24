{ config, pkgs, ... }: {
  wayland.windowManager.hyprland = {
    enable = true;
    settings = { };
    extraConfig = ''

      exec-once = dunst
      exec-once = waybar
      exec-once = swww init 
      exec-once = swww img /home/vincenzo/Pictures/w3_ultrawide.png
      exec-once = emacs --daemon
      exec-once = nm-applet --indicator &

      # See https://wiki.hyprland.org/Configuring/Monitors/
      monitor=,preferred,auto,auto
      monitor=eDP-1,1920x1080@60,0x0,1

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      # Execute your favorite apps at launch
      # exec-once = waybar & hyprpaper & firefox

      # Source a file (multi-file configs)
      # source = ~/.config/hypr/myColors.conf

      # Some default env vars.
      env = XCURSOR_SIZE,24

      # For all categories, see https://wiki.hyprland.org/Configuring/Variables/
      input {
          kb_layout = us
          follow_mouse = 1
          repeat_rate = 50
          repeat_delay = 200
          kb_options = caps:escape, grp:alt_shift_toggle
          kb_layout = us,de
          touchpad {
              natural_scroll = no
              disable_while_typing = true
              tap-to-click = false
          }
          sensitivity = 1.0 # -1.0 - 1.0, 0 means no modification.
      }

      general {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          gaps_in = 5
          gaps_out = 5
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          layout = dwindle
      }

      decoration {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          rounding = 16
          blur {
              enabled = true
              size = 10
              passes = 1
              new_optimizations = true
              brightness = 1.0
              noise = 0.02
          }

          drop_shadow = yes
          shadow_ignore_window = true
          shadow_offset = 0 2
          shadow_range = 20
          shadow_render_power = 3
          col.shadow = rgba(00000055)
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
          new_is_master = true
      }

      gestures {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = off
      }

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
      device:epic-mouse-v1 {
          sensitivity = -0.5
      }

      misc {
           enable_swallow = true
      }

      windowrulev2 = opacity 0.8 0.8,class:^(kitty)$
      windowrulev2 = opacity 0.9 0.9,class:^(anki)$
      windowrulev2 = opacity 0.9 0.9,class:^(Emacs)$
      windowrulev2 = opacity 0.9 0.9,class:^(signal)$
      windowrulev2 = opacity 0.9 0.9,class:^(org.telegram.desktop)$
      windowrulev2 = opacity 0.9 0.9,class:^(discord)$
      windowrulev2 = opacity 0.9 0.9,class:^(Slack)$

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      $mod = SUPER


      bind = $mod, Return, exec, kitty
      bind = $mod, Q, killactive,
      bind = $mod, E, exec, emacsclient -c
      bind = $mod, C, exec, emacsclient -n -e '(make-orgcapture-frame)'
      bind = $mod, V, togglefloating,
      bind = $mod, R, exec, wofi --show drun
      bind = $mod, S, exec, grim -g "$(slurp)" - | wl-copy
      bind = $mod, L, exec, swaylock --image ~/Pictures/w3_ultrawide.png
      #bind = $mod, P, pseudo, # dwindle
      bind = $mod_SHIFT, Escape, exec, wlogout -p layer-shell


      # Launch programs with keybind
      bind = $mod, W, exec, firefox
      bind = $mod, A, exec, anki
      bind = $mod, N, exec, kitty -e yazi
      bind = $mod_SHIFT, N, exec, pcmanfm
      bind = $mod, B, exec, blueberry
      bind = $mod_SHIFT, D, exec, discord
      bind = $mod_SHIFT, T, exec, telegram-desktop
      bind = $mod_SHIFT, S, exec, signal-desktop
      bind = $mod_SHIFT, P, exec, pavucontrol
      bind = $mod, P, exec, passmenu
      bind = $mod_SHIFT, H, exec, kitty -e btop

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
      bindle = , XF86MonBrightnessUp, exec, brightnessctl set +50
      bindle = , XF86MonBrightnessDown, exec, brightnessctl set 50-
      exec-once=bash ~/.config/hypr/start.sh
    '';
  };
}

