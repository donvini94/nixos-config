{ pkgs, ... }:

{

  home.packages = [ pkgs.inter ];

  services.playerctld.enable = true;

  programs.waybar = {
    enable = true;
    package = pkgs.waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    });
    settings = {
      mainBar = {
        margin = "0";
        layer = "top";
        modules-left = [
          "custom/nix"
          "hyprland/workspaces"
        ];
        #        modules-center = [ "custom/pomodoro" ];
        modules-right = [
          "pulseaudio"
          "network#interface"
          "network#speed"
          "cpu"
          "battery"
          "clock"
          "tray"
        ];

        "custom/pomodoro" = {
          exec = "echo -e \"  $(emacsclient -e '(ruborcalor/org-pomodoro-time)' | cut -d '\"' -f 2)\"";
          interval = 1;
          tooltip = false;
        };
        "hyprland/workspaces" = {
          format = "{name} : {icon}";
          on-click = "activate";
          sort-by-number = true;
          format-icons = {
            "1" = "";
            "2" = "";
            "3" = "";
            "4" = "";
            "5" = "";
            "6" = "";
            "7" = "";
            "8" = "";
            "9" = "";
            "active" = "";
            "default" = "";
          };
        };

        "custom/nix" = {
          format = "󱄅 ";
        };

        pulseaudio = {
          format = "{volume}% {icon} ";
          on-click = "pavucontrol";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = "0% {icon} ";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "default" = [
              ""
              ""
              ""
            ];
          };
        };

        "network#interface" = {
          format-ethernet = "󰣶  {ifname}";
          format-wifi = " {essid} ({signalStrength}%) 󰖩";
          tooltip = true;
          tooltip-format = "{ipaddr}";
          on-click = "kitty -e 'nmtui'";
        };

        "network#speed" = {
          format = "⇡{bandwidthUpBits} ⇣{bandwidthDownBits}";
        };

        cpu = {
          format = "  {usage}% 󱐌 {avg_frequency}";
        };

        battery = {
          format-critical = "{icon} {capacity}%";
          format = "{icon} {capacity}%";
          format-icons = [
            "󰁺"
            "󰁾"
            "󰂀"
            "󱟢"
          ];
        };

        clock = {
          format = "   {:%H:%M}";
          format-alt = "󰃭  {:%Y-%m-%d}";
        };

        tray = {
          icon-size = 16;
          spacing = 10;
        };
      };
    };

    style = ''
      @define-color accent #7aa2f7;
      @define-color foreground #c0caf5;
      * {
      	border: none;
      	border-radius: 0;
      	font-family: Nerd Font Hack;
      	font-size: 14px;
      	min-height: 24px;
      }

      window#waybar {
      	background: transparent;
      }

      window#waybar.hidden {
      	opacity: 0.2;
      }

      #window {
          margin-top: 8px;
          padding-left: 16px;
          padding-right: 16px;
      	border-radius: 26px;
      	transition: none;
      	/*
          color: #f8f8f2;
      	background: #282a36;
          */
          color: transparent;
      	background: transparent;
      }

      window#waybar.termite #window,
      window#waybar.Firefox #window,
      window#waybar.Navigator #window,
      window#waybar.PCSX2 #window {
          color: #4d4d4d;
      	background: #e6e6e6;
      }

      #workspaces {
      	margin-top: 8px;
      	margin-left: 12px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	background: #282a36;
      	transition: none;
      }

      #workspaces button {
      	transition: none;
      	color: #f8f8f2;
      	background: transparent;
      	font-size: 16px;
      }

      #workspaces button.focused {
      	color: #9aedfe;
      }

      #workspaces button:hover {
      	transition: none;
      	box-shadow: inherit;
      	text-shadow: inherit;
      	color: #ff79c6;
      }

      #mpd {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	background: #282a36;
      	transition: none;
      	color: #4d4d4d;
      	background: #5af78e;
      }

      #mpd.disconnected,
      #mpd.stopped {
      	color: #f8f8f2;
      	background: #282a36;
      }

      #network {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #bd93f9;
      }

      #pulseaudio {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #9aedfe;
      }

      #temperature {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #5af78e;
      }

      #cpu {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #f1fa8c;
      }

      #memory {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #ff6e67;
      }

      #battery {
      	margin-top: 8px;
      	margin-left: 8px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #4d4d4d;
      	background: #5af78e;
      }
      #custom-nix {
        color: @accent;
        font-size: 32px;
      	margin-top: 8px;
      	margin-left: 20px;
      }
      #custom-pomodoro {
        background: #ff6e67;       /* Consistent with #clock and #workspaces */
        color: #4d4d4d;            /* Matches the foreground color */
        margin-top: 8px;
        margin-left: 8px;
        padding-left: 16px;
        padding-right: 16px;
        border-radius: 26px;
        transition: none;
        font-size: 14px;      /* Slightly larger, matching main font size */
        padding: 4px 8px;     /* Add padding for a clean look */
        border-radius: 26px;
      }
      #clock {
      	margin-top: 8px;
      	margin-left: 8px;
      	margin-right: 12px;
      	padding-left: 16px;
      	padding-right: 16px;
      	margin-bottom: 0;
      	border-radius: 26px;
      	transition: none;
      	color: #f8f8f2;
      	background: #282a36;
      }
    '';
  };
}
