# The single source of truth for the zellij setup on every machine: hm-modules/zellij/
# default.nix writes ~/.config/zellij on AC-0137 and dracula, hosts/alucard/zellij.nix writes
# /etc/zellij on alucard. The keymap cannot be allowed to drift between them, because `zjr`
# drives a zellij running on the server and it is that server's config.kdl which interprets
# your keystrokes.
#
# No Alt bindings anywhere: on the Mac, Option is AeroSpace's modifier
# (hosts/ac-0137/aerospace.toml) and Ghostty's compose key, which on a German layout is how
# you type @ | \ { } [ ]; on dracula, Hyprland takes CTRL+ALT. Zellij's stock keymap is out
# too — it owns Ctrl-p/n/h/s/b/o/g in every pane, where Ctrl-h is Backspace, Ctrl-p/Ctrl-n
# are fish history and Ctrl-o is the vim jumplist.
#
# The shape is zellij's "Unlock-First (non-colliding)" model, pinned declaratively here
# rather than clicked into the Configuration screen:
# https://zellij.dev/tutorials/colliding-keybindings/
{
  pkgs,
  # Editor for `EditScrollback`. A server has no frame to open, so there it must be a
  # terminal editor.
  scrollbackEditor,
  # Program the selection is piped to. null leaves zellij on OSC 52, which is the right
  # answer for a session reached only over SSH: the escape sequence travels back to
  # whichever terminal you are sitting at.
  copyCommand ? null,
}:
let
  cheatsheet = ./cheatsheet.md;

  # Modus Vivendi TINTED, mirrored from the kitty themeFile
  # (kitty-themes/Modus_Vivendi_Tinted.conf); the bg is the tinted #0d0e1c, not pure black.
  theme = ''
    themes {
        modus-vivendi-tinted {
            fg "#ffffff"
            bg "#0d0e1c"
            black "#0d0e1c"
            red "#ff5f59"
            green "#44bc44"
            yellow "#d0bc00"
            blue "#2fafff"
            magenta "#feacd0"
            cyan "#00d3d0"
            white "#ffffff"
            orange "#fec43f"
        }
    }
  '';
in
rec {
  # Every custom layout must open with this, or the session comes up with no tab
  # bar and no hint bar at all.
  uiTemplate = ''
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
  '';

  configText = ''
    // Generated from hm-modules/zellij/lib.nix — do not edit in place.

    // The bars live in the "default" layout; "compact" swaps them for a single top line
    // with no keybind hints.
    default_layout "default"

    // Kitty launches fish while the login shell can remain bash; pin panes to the
    // interactive shell so fish abbreviations and integrations are available.
    default_shell "fish"

    // Start every pane pass-through; Ctrl g is the only key zellij owns.
    default_mode "locked"

    theme "modus-vivendi-tinted"
    ${theme}

    // Tell every pane that the surface it is drawn on is dark. A TUI asking the terminal
    // for its background with OSC 11 is talking to the multiplexer, not the terminal, so
    // that answer is not trustworthy; vim's `background`, ncurses apps and OMP read
    // COLORFGBG instead. "15;0" is xterm's convention for white on black, which is what
    // the theme above pins.
    env {
        COLORFGBG "15;0"
    }

    // "titles" is a one-line pane header rather than a full box: pane names, focus
    // indicator and the floating-pane PIN control, without the chrome of a full frame.
    pane_frames true
    pane_frame_style "titles"

    mouse_mode true
    copy_on_select true
    ${
      if copyCommand == null then
        "// no copy_command: selections travel out over OSC 52"
      else
        ''copy_command "${copyCommand}"''
    }
    copy_clipboard "system"
    scrollback_editor "${scrollbackEditor}"
    scroll_buffer_size 50000

    on_force_close "detach"
    session_serialization true
    serialize_pane_viewport true
    scrollback_lines_to_serialize 10000

    // Driving a zellij on alucard from a zellij here is the normal case. Without "descend"
    // the outer session eats Ctrl g and the inner one is unreachable; `Ctrl g o ]`
    // (FocusHostSession, below) climbs back out. Both ends run this config.
    nested_session_handling "descend"

    show_release_notes false

    // `Ctrl g` is the only key zellij owns while locked: it turns the zellij layer on and
    // `Esc` turns it off. Any action that hands the keyboard to something else — a plugin,
    // an editor, the cheatsheet, another session — relocks.
    keybinds clear-defaults=true {
        locked {
            bind "Ctrl g" { SwitchToMode "Normal"; }
        }

        // Single-action binds are what the status bar's tip line looks for, so `n` and
        // `=`/`-` must stay free of a trailing SwitchToMode or the tip renders
        // "UNBOUND => new pane".
        normal {
            // Sticky sub-modes.
            bind "p" { SwitchToMode "Pane"; }
            bind "t" { SwitchToMode "Tab"; }
            bind "r" { SwitchToMode "Resize"; }
            bind "m" { SwitchToMode "Move"; }
            bind "s" { SwitchToMode "Scroll"; }
            bind "o" { SwitchToMode "Session"; }

            bind "h" "Left" { MoveFocusOrTab "Left"; }
            bind "l" "Right" { MoveFocusOrTab "Right"; }
            bind "j" "Down" { MoveFocus "Down"; }
            bind "k" "Up" { MoveFocus "Up"; }

            bind "H" { MovePane "Left"; }
            bind "J" { MovePane "Down"; }
            bind "K" { MovePane "Up"; }
            bind "L" { MovePane "Right"; }

            bind "n" { NewPane; }
            bind "d" { NewPane "Down"; }
            bind "v" { NewPane "Right"; }
            bind "x" { CloseFocus; }
            bind "z" { ToggleFocusFullscreen; }
            bind "f" { ToggleFloatingPanes; }
            bind "e" { TogglePaneEmbedOrFloating; }
            bind "i" { TogglePanePinned; }
            bind "=" "+" { Resize "Increase"; }
            bind "-" { Resize "Decrease"; }
            bind "Space" { NextSwapLayout; }

            bind "c" { NewTab; }
            bind "Tab" { ToggleTab; }
            bind "[" { GoToPreviousTab; }
            bind "]" { GoToNextTab; }
            bind "1" { GoToTab 1; }
            bind "2" { GoToTab 2; }
            bind "3" { GoToTab 3; }
            bind "4" { GoToTab 4; }
            bind "5" { GoToTab 5; }
            bind "6" { GoToTab 6; }
            bind "7" { GoToTab 7; }
            bind "8" { GoToTab 8; }
            bind "9" { GoToTab 9; }

            bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }
            bind "E" { EditScrollback; SwitchToMode "Locked"; }

            bind "w" {
                LaunchOrFocusPlugin "session-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "F" {
                LaunchOrFocusPlugin "filepicker" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "D" { Detach; }

            bind "?" {
                Run "${pkgs.glow}/bin/glow" "-p" "${cheatsheet}" {
                    floating true
                    x "8%"
                    y "6%"
                    width "84%"
                    height "88%"
                    name "zellij cheatsheet"
                    close_on_exit true
                };
                SwitchToMode "Locked"
            }
        }

        pane {
            bind "h" "Left" { MoveFocus "Left"; }
            bind "l" "Right" { MoveFocus "Right"; }
            bind "j" "Down" { MoveFocus "Down"; }
            bind "k" "Up" { MoveFocus "Up"; }
            bind "p" { SwitchFocus; }
            bind ";" { FocusLastPane; }
            bind "n" { NewPane; }
            bind "d" { NewPane "Down"; }
            bind "v" { NewPane "Right"; }
            bind "s" { NewPane "stacked"; }
            bind "x" { CloseFocus; }
            bind "f" { ToggleFocusFullscreen; }
            bind "F" { ToggleFocusNoUiFullscreen; }
            bind "w" { ToggleFloatingPanes; }
            bind "e" { TogglePaneEmbedOrFloating; }
            bind "i" { TogglePanePinned; }
            bind "z" { TogglePaneFrames; }
            bind "b" { BreakPane; }
            bind "c" { SwitchToMode "RenamePane"; PaneNameInput 0; }
        }

        tab {
            bind "h" "Left" "Up" "k" { GoToPreviousTab; }
            bind "l" "Right" "Down" "j" { GoToNextTab; }
            bind "n" { NewTab; }
            bind "x" { CloseTab; }
            bind "b" { BreakPane; }
            bind "s" { ToggleActiveSyncTab; }
            bind "[" { MoveTab "Left"; }
            bind "]" { MoveTab "Right"; }
            bind "Tab" { ToggleTab; }
            bind "c" { SwitchToMode "RenameTab"; TabNameInput 0; }
            bind "1" { GoToTab 1; }
            bind "2" { GoToTab 2; }
            bind "3" { GoToTab 3; }
            bind "4" { GoToTab 4; }
            bind "5" { GoToTab 5; }
            bind "6" { GoToTab 6; }
            bind "7" { GoToTab 7; }
            bind "8" { GoToTab 8; }
            bind "9" { GoToTab 9; }
        }

        resize {
            bind "h" "Left" { Resize "Increase Left"; }
            bind "j" "Down" { Resize "Increase Down"; }
            bind "k" "Up" { Resize "Increase Up"; }
            bind "l" "Right" { Resize "Increase Right"; }
            bind "H" { Resize "Decrease Left"; }
            bind "J" { Resize "Decrease Down"; }
            bind "K" { Resize "Decrease Up"; }
            bind "L" { Resize "Decrease Right"; }
            bind "=" "+" { Resize "Increase"; }
            bind "-" { Resize "Decrease"; }
        }

        move {
            bind "h" "Left" { MovePane "Left"; }
            bind "j" "Down" { MovePane "Down"; }
            bind "k" "Up" { MovePane "Up"; }
            bind "l" "Right" { MovePane "Right"; }
            bind "n" "Tab" { MovePane; }
            bind "p" { MovePaneBackwards; }
        }

        scroll {
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "d" { HalfPageScrollDown; }
            bind "u" { HalfPageScrollUp; }
            bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
            bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
            bind "g" { ScrollToTop; }
            bind "G" { ScrollToBottom; }
            // Prompt jumping and command selection need OSC 133, which fish
            // emits; in a plain bash pane these do nothing.
            bind "[" { ScrollToPreviousPrompt; }
            bind "]" { ScrollToNextPrompt; }
            bind "m" { SelectCommandAtScrollPosition; }
            bind "y" { CopyLastCommandOutput; }
            bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }
            bind "e" { EditScrollback; SwitchToMode "Locked"; }
        }

        search {
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "d" { HalfPageScrollDown; }
            bind "u" { HalfPageScrollUp; }
            bind "Ctrl f" "PageDown" { PageScrollDown; }
            bind "Ctrl b" "PageUp" { PageScrollUp; }
            bind "n" { Search "down"; }
            bind "N" { Search "up"; }
            bind "c" { SearchToggleOption "CaseSensitivity"; }
            bind "w" { SearchToggleOption "Wrap"; }
            bind "o" { SearchToggleOption "WholeWord"; }
        }

        entersearch {
            bind "Esc" { SwitchToMode "Scroll"; }
            bind "Enter" { SwitchToMode "Search"; }
        }

        session {
            bind "d" { Detach; }
            bind "w" {
                LaunchOrFocusPlugin "session-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "c" {
                LaunchOrFocusPlugin "configuration" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "p" {
                LaunchOrFocusPlugin "plugin-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "l" {
                LaunchOrFocusPlugin "zellij:layout-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "a" {
                LaunchOrFocusPlugin "zellij:about" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }

            bind "]" { FocusHostSession; SwitchToMode "Locked"; }
            bind "[" { FocusGuestSession; SwitchToMode "Locked"; }
            bind "f" { ToggleHostFullscreen; SwitchToMode "Locked"; }
        }

        renametab {
            bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
            bind "Enter" { SwitchToMode "Locked"; }
        }
        renamepane {
            bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
            bind "Enter" { SwitchToMode "Locked"; }
        }

        // Ctrl q exists only while unlocked, so it can never reach a program by accident.
        shared_except "locked" {
            bind "Ctrl g" { SwitchToMode "Locked"; }
            bind "Ctrl q" { Quit; }
        }
        // "normal" is excluded on purpose: there the bare letter already does it, and a
        // duplicate makes the status bar advertise the Ctrl form instead of the real key.
        shared_except "locked" "normal" "pane" "entersearch" "renametab" "renamepane" {
            bind "Ctrl p" { SwitchToMode "Pane"; }
        }
        shared_except "locked" "normal" "tab" "entersearch" "renametab" "renamepane" {
            bind "Ctrl t" { SwitchToMode "Tab"; }
        }
        shared_except "locked" "normal" "resize" "entersearch" "renametab" "renamepane" {
            bind "Ctrl r" { SwitchToMode "Resize"; }
        }
        shared_except "locked" "normal" "move" "entersearch" "renametab" "renamepane" {
            bind "Ctrl m" { SwitchToMode "Move"; }
        }
        shared_except "locked" "normal" "scroll" "search" "entersearch" "renametab" "renamepane" {
            bind "Ctrl s" { SwitchToMode "Scroll"; }
        }
        shared_except "locked" "normal" "session" "entersearch" "renametab" "renamepane" {
            bind "Ctrl o" { SwitchToMode "Session"; }
        }
        shared_except "locked" "entersearch" "renametab" "renamepane" {
            bind "Esc" "Enter" { SwitchToMode "Locked"; }
        }
    }
  '';

  # SSH panes use `ssh -t <host> "<cmd>; exec $SHELL -l"`: -t forces a remote TTY so TUIs
  # render, and `exec $SHELL` leaves a usable login shell when you quit the app instead of a
  # dead "press Enter to rerun" pane. All panes to one host share a single SSH ControlMaster
  # socket (hm-modules/ssh.nix), so these are one connection, not N.
  #
  # A layout runs only on session create; `zj`/`zjr` attach to a running server and
  # re-execute nothing.
  layouts = {
    # Local project work: `cd ~/proj && zj proj dev`. Panes inherit the cwd you launched from.
    dev = ''
      layout {
          ${uiTemplate}
          tab name="dev" focus=true {
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

    # Long-running agent work: `zj myjob agent`, or `zjr Bereitserver myjob` on the server.
    agent = ''
      layout {
          ${uiTemplate}
          tab name="agent" focus=true {
              pane split_direction="vertical" {
                  pane size="65%" name="agent"
                  pane size="35%" name="inspect"
              }
          }
          tab name="review" split_direction="vertical" {
              pane name="git"
              pane name="tests"
          }
      }
    '';

    # Bereitserver/alucard from a workstation: `zellij -l bereit`.
    # The lazydocker pane goes through the `media-admin` alias, whose ssh config carries the
    # *arr-stack LocalForwards, so opening this layout also binds those ports. It is the only
    # pane with forwards, which avoids duplicate-bind races. TERM is forced there because
    # media-admin otherwise sends TERM=xterm (8-colour), which washes lazydocker out.
    bereit = ''
      layout {
          ${uiTemplate}
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

    # Work host: `zellij -l work`. Requires an `acGPT` Host entry in ssh.nix, which is
    # currently a commented stub.
    work = ''
      layout {
          ${uiTemplate}
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

  # Layouts that only make sense on the server itself (alucard). Kept to binaries guaranteed
  # present there, so the layout cannot come up with dead panes.
  serverLayouts = {
    # `zjr Bereitserver ops` after `zellij --session ops --layout sys` once.
    sys = ''
      layout {
          ${uiTemplate}
          tab name="sys" focus=true {
              pane split_direction="vertical" {
                  pane size="60%" name="journal" command="journalctl" {
                      args "-f" "-n" "200"
                  }
                  pane size="40%" split_direction="horizontal" {
                      pane name="units" command="watch" {
                          args "-n" "10" "systemctl --failed --no-legend"
                      }
                      pane name="shell"
                  }
              }
          }
      }
    '';
  };

  # These live here rather than in default.nix because alucard has fish too and does not use
  # `programs.zellij`: `zj` on the server starts the same session `zjr` reattaches to.
  fishFunctions = {
    zj = {
      description = "Attach to (or create) a persistent local zellij session";
      body = ''
        set -l name $argv[1]
        test -z "$name"; and set name (basename $PWD)
        set -l layout $argv[2]

        # list-sessions includes EXITED sessions, and attaching to one
        # resurrects it — which is exactly what we want here.
        if contains -- $name (zellij list-sessions --short --no-formatting 2>/dev/null)
            zellij attach $name
        else if test -n "$layout"
            # -n, not --layout: with --session, --layout means "add these tabs to a session
            # that already exists" and errors out when it does not.
            zellij --session $name --new-session-with-layout $layout
        else
            zellij --session $name
        end
      '';
    };

    zjr = {
      description = "Attach to (or create) a persistent zellij session on a remote host";
      body = ''
        if test (count $argv) -lt 1
            echo "usage: zjr <ssh-host> [session]" >&2
            return 2
        end
        set -l host $argv[1]
        set -l name $argv[2]
        test -z "$name"; and set name main

        # -t forces a remote TTY; the keepalives make a dead link fail fast instead of
        # hanging on a half-open socket.
        ssh -t -o ServerAliveInterval=30 -o ServerAliveCountMax=3 $host -- \
            zellij attach --create $name
      '';
    };

    zjls = {
      description = "List zellij sessions on a remote host";
      body = ''
        if test (count $argv) -lt 1
            echo "usage: zjls <ssh-host>" >&2
            return 2
        end
        ssh $argv[1] -- zellij list-sessions --no-formatting
      '';
    };
  };
}
