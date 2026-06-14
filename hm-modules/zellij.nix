{ ... }:
{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false; # don't auto-start in every shell
    settings = {
      # Content surface → Modus Vivendi TINTED, to match kitty + Emacs (the
      # hybrid's "content = Modus" rule; chrome stays wallpaper-dynamic via
      # caelestia). Values mirrored exactly from the kitty themeFile
      # (kitty-themes/Modus_Vivendi_Tinted.conf) so zellij and kitty are
      # pixel-identical — note the tinted bg #0d0e1c, NOT pure black. Simple
      # palette format still works in zellij 0.44; with pane_frames=false the
      # only visible chrome is the status bar, now in Modus rather than the
      # green/blue default.
      theme = "modus-vivendi-tinted";
      themes.modus-vivendi-tinted = {
        fg = "#ffffff";
        bg = "#0d0e1c";
        black = "#0d0e1c";
        red = "#ff5f59";
        green = "#44bc44";
        yellow = "#d0bc00";
        blue = "#2fafff";
        magenta = "#feacd0";
        cyan = "#00d3d0";
        white = "#ffffff";
        orange = "#fec43f";
      };
      default_layout = "compact"; # minimal UI, more terminal space
      pane_frames = false; # cleaner look, borders only
      copy_on_select = true;
      copy_command = "wl-copy"; # route yanks to the Wayland clipboard, not a void
      copy_clipboard = "system"; # system clipboard, not the primary selection
      scrollback_editor = "emacsclient -a '' -c";

      mouse_mode = true; # click panes/tabs, drag borders, scroll
      scroll_buffer_size = 50000; # generous history, matches the kitty habit
      # Make work hard to lose: closing the terminal detaches instead of killing
      # the session, and panes are restored after a zellij server restart.
      on_force_close = "detach";
      session_serialization = true;
    };
  };

  # Declarative layouts (zellij reads $XDG_CONFIG_HOME/zellij/layouts/*.kdl).
  # Launch with `zellij -l <name>`.
  #
  # Pattern in the SSH panes: `ssh -t <host> "<cmd>; exec $SHELL -l"`.
  #   -t           forces a remote TTY so TUIs (btop/yazi/lazydocker) render.
  #   exec $SHELL  drops you into a normal login shell when you quit the app,
  #                instead of a dead "press Enter to rerun" pane.
  # All panes to the same host share one SSH ControlMaster socket (see ssh.nix),
  # so this is a single connection, not N.
  xdg.configFile = {
    # Local coding support — pairs with GUI Emacs (you edit there; magit handles
    # git). This is the supporting cast: a primary shell for build/test/run, a
    # long-running pane for a dev server / file watcher / logs, and a scratch
    # shell. Panes start in whatever dir you launch from:  cd ~/proj && zellij -l code
    "zellij/layouts/code.kdl".text = ''
      layout {
          tab name="code" focus=true {
              pane split_direction="vertical" {
                  pane size="60%" name="shell"
                  pane size="40%" split_direction="horizontal" {
                      pane name="watch"
                      pane name="scratch"
                  }
              }
          }
      }
    '';

    # Bereitserver session:  zellij -l bereit
    #   btop (left), yazi opened at the downloads share, and lazydocker.
    # The lazydocker pane connects via the `media-admin` alias, whose ssh config
    # carries the *arr-stack LocalForwards — so opening this layout also binds
    # those ports. It's the only pane with forwards, which avoids duplicate-bind
    # races; the others use plain `Bereitserver` and multiplex over the same
    # master. TERM is forced to xterm-256color for that pane because media-admin
    # otherwise sends TERM=xterm (8-colour), which would wash out lazydocker.
    # yazi starts at /media/hetzner/downloads; quit it and the shell is still
    # there, so a quick `cd` gets you home.
    "zellij/layouts/bereit.kdl".text = ''
      layout {
          tab name="bereit" focus=true {
              pane split_direction="vertical" {
                  pane size="50%" name="btop" command="ssh" {
                      args "-t" "Bereitserver" "btop; exec $SHELL -l"
                  }
                  pane size="50%" split_direction="horizontal" {
                      pane name="yazi (downloads)" command="ssh" {
                          args "-t" "Bereitserver" "cd /media/hetzner/downloads 2>/dev/null; yazi; exec $SHELL -l"
                      }
                      pane name="lazydocker (arr tunnels)" command="ssh" {
                          args "-t" "media-admin" "env TERM=xterm-256color lazydocker; exec $SHELL -l"
                      }
                  }
              }
          }
      }
    '';

    # Work session:  zellij -l work
    #   ssh into acGPT, sit in the compose dir, lazydocker + btop.
    # Requires an `acGPT` Host entry in ssh.nix (currently a commented stub —
    # mirror your Mac's ~/.ssh config there to enable this from NixOS).
    "zellij/layouts/work.kdl".text = ''
      layout {
          tab name="acGPT" focus=true {
              pane split_direction="vertical" {
                  pane size="60%" name="lazydocker" command="ssh" {
                      args "-t" "acGPT" "cd ~/onyx_v3/deployment/docker_compose; lazydocker; exec $SHELL -l"
                  }
                  pane size="40%" name="btop" command="ssh" {
                      args "-t" "acGPT" "btop; exec $SHELL -l"
                  }
              }
          }
      }
    '';
  };
}
