# The single source of truth for the zellij setup on every machine.
#
# Three hosts, only two of which have home-manager:
#   * AC-0137 and dracula  -> hm-modules/zellij/default.nix (writes ~/.config/zellij)
#   * alucard              -> hosts/alucard/zellij.nix      (writes /etc/zellij)
# Both consume this file, so the keymap cannot drift between the machine you type
# on and the machine the long-running session actually lives on. That matters:
# with `zjr` you drive a zellij running *on the server*, and it is that server's
# config.kdl which interprets your keystrokes.
#
# ── Why the keymap looks like this ───────────────────────────────────────────
#
# Zellij's stock keymap owns Ctrl-p/n/h/s/b/o/g in every pane. Ctrl-h *is*
# Backspace on most terminals, Ctrl-p/Ctrl-n are fish history, Ctrl-o is the vim
# jumplist. Unusable here.
#
# The other obvious modifier is worse. On the Mac, Option is AeroSpace's WM
# modifier (hosts/ac-0137/aerospace.toml) and Ghostty leaves it as a compose key,
# which on a German layout is how you type @ | \ { } [ ]. On dracula, Hyprland
# takes CTRL+ALT. So: no Alt bindings anywhere. Everything is Ctrl, exactly as
# asked, and the keymap is byte-identical on both platforms.
#
# The resolution is zellij's own "Unlock-First (non-colliding)" model
# (https://zellij.dev/tutorials/colliding-keybindings/), pinned declaratively
# here rather than clicked into the Configuration screen:
#
#   * `default_mode "locked"` — a fresh pane passes every keystroke through.
#     Nothing you type in nvim, fish, an agent TUI or a nested zellij is
#     intercepted.
#   * `Ctrl g` unlocks into Normal mode. The status bar then shows the whole
#     keymap, and it changes as you move between modes — those are the
#     "evolving keybind hints" from the tutorial.
#   * From Normal: a mode letter (p/t/r/m/s/o) enters a *sticky* mode for
#     repeated work; anything else is a one-shot action that drops you straight
#     back to Locked so you can type again.
#   * Exception: h/j/k/l keep focus moving without relocking, because moving two
#     panes over is one gesture, not two.
#
# ── Why the hints were invisible before ──────────────────────────────────────
#
# Two independent reasons, both fixed here:
#   1. `default_layout "compact"` loads `compact-bar`, which is a single top line
#      with no hints. The hint bar is `status-bar`, in the "default" layout.
#   2. A custom layout replaces the UI entirely: if it does not declare the
#      tab-bar/status-bar plugin panes itself, the session has no bars at all.
#      Hence `uiTemplate` below, which every layout here starts with.
{
  pkgs,
  # Editor for `EditScrollback`. GUI Emacs on the workstations; on a server
  # there is no frame to open, so it has to be a terminal editor.
  scrollbackEditor,
  # Program the selection is piped to. null leaves zellij on OSC 52, which is
  # the right answer for a session you only ever reach over SSH: the escape
  # sequence travels back to whichever terminal you are sitting at.
  copyCommand ? null,
}:
let
  cheatsheet = ./cheatsheet.md;

  # Content surface -> Modus Vivendi TINTED, mirrored from the kitty themeFile
  # (kitty-themes/Modus_Vivendi_Tinted.conf) so zellij and kitty are
  # pixel-identical. Note the tinted bg #0d0e1c, not pure black.
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

    // The bars live in the "default" layout. "compact" swaps them for a single
    // top line with no keybind hints, which is the whole point of this setup.
    default_layout "default"

    // Start every pane pass-through; Ctrl g is the only key zellij owns.
    default_mode "locked"

    theme "modus-vivendi-tinted"
    ${theme}

    // Tell every pane that the surface it is drawn on is dark.
    //
    // A TUI that wants to pick readable colours asks the terminal for its
    // background with OSC 11 — and a program inside a multiplexer is talking to
    // the multiplexer, not to the terminal, so that answer is not trustworthy.
    // OMP knows this: packages/tui resolves the appearance as COLORFGBG first,
    // then the macOS system appearance, then "dark", and skips its own OSC 11
    // result entirely when $ZELLIJ is set. On a Mac left in Light mode that
    // second step wins and the whole TUI renders for a light background —
    // #000000 input text on zellij's #0d0e1c pane, which is what this fixes.
    // Every other guesser (vim's `background`, ncurses apps) reads the same
    // variable, so this is the one place to say it.
    //
    // "15;0" is xterm's own convention: white foreground on black background,
    // which is exactly what the theme above pins.
    env {
        COLORFGBG "15;0"
    }

    // "titles" is a one-line pane header rather than a full box: you keep the
    // pane names the layouts set, the focus indicator and the floating-pane PIN
    // control, without the chrome of a full frame. `Ctrl g p z` toggles it off
    // for the session; "none" here makes that permanent.
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

    // Work is hard to lose: closing the terminal (or dropping an SSH link)
    // detaches instead of killing, panes and their commands survive a zellij
    // server restart, and the visible screen comes back with them.
    on_force_close "detach"
    session_serialization true
    serialize_pane_viewport true
    scrollback_lines_to_serialize 10000

    // Driving a zellij on alucard from a zellij on the Mac is the normal case
    // here. Without this the outer session eats Ctrl g and the inner one is
    // unreachable; "descend" routes every key to the nested session while its
    // pane is focused, and `Ctrl g o ]` (FocusHostSession, below) climbs back
    // out to the host. Both ends run this same config, so both halves exist.
    nested_session_handling "descend"

    show_release_notes false

    // The model is vim's, not tmux's. `Ctrl g` is the only key zellij owns
    // while locked; it turns the zellij layer on, and `Esc` turns it off. While
    // the layer is on, keys act on the workspace and the status bar shows you
    // exactly which ones — that is the point of unlocking rather than firing a
    // one-shot prefix. The single exception: an action that hands the keyboard
    // to something else (a plugin, an editor, the cheatsheet, another session)
    // relocks, because you are about to type into it.
    keybinds clear-defaults=true {
        // ── locked ──────────────────────────────────────────────────────────
        // The default mode. Everything else reaches the program in the pane.
        locked {
            bind "Ctrl g" { SwitchToMode "Normal"; }
        }

        // ── normal ──────────────────────────────────────────────────────────
        // The unlocked layer. Read the status bar here: it lists all of this.
        // Single-action binds are also what the bar's tip line looks for, so
        // `n` and `=`/`-` must stay free of a trailing SwitchToMode or the tip
        // renders "UNBOUND => new pane".
        normal {
            // Sticky sub-modes.
            bind "p" { SwitchToMode "Pane"; }
            bind "t" { SwitchToMode "Tab"; }
            bind "r" { SwitchToMode "Resize"; }
            bind "m" { SwitchToMode "Move"; }
            bind "s" { SwitchToMode "Scroll"; }
            bind "o" { SwitchToMode "Session"; }

            // Focus.
            bind "h" "Left" { MoveFocusOrTab "Left"; }
            bind "l" "Right" { MoveFocusOrTab "Right"; }
            bind "j" "Down" { MoveFocus "Down"; }
            bind "k" "Up" { MoveFocus "Up"; }

            // Shift+hjkl throws the pane around, like a tiling WM.
            bind "H" { MovePane "Left"; }
            bind "J" { MovePane "Down"; }
            bind "K" { MovePane "Up"; }
            bind "L" { MovePane "Right"; }

            // Panes.
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

            // Tabs.
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

            // Scrollback.
            bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }
            bind "E" { EditScrollback; SwitchToMode "Locked"; }

            // Sessions and helpers. These relock: the thing they open wants
            // your keystrokes, not zellij.
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

            // The cheatsheet, in a floating pane, read straight from the store
            // — same text on every host, and it cannot go missing.
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

        // ── pane ────────────────────────────────────────────────────────────
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

        // ── tab ─────────────────────────────────────────────────────────────
        tab {
            bind "h" "Left" "Up" "k" { GoToPreviousTab; }
            bind "l" "Right" "Down" "j" { GoToNextTab; }
            bind "n" { NewTab; }
            bind "x" { CloseTab; }
            bind "b" { BreakPane; }
            // Type once, land in every pane of the tab — the same command on
            // four servers at a time.
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

        // ── resize ──────────────────────────────────────────────────────────
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

        // ── move ────────────────────────────────────────────────────────────
        move {
            bind "h" "Left" { MovePane "Left"; }
            bind "j" "Down" { MovePane "Down"; }
            bind "k" "Up" { MovePane "Up"; }
            bind "l" "Right" { MovePane "Right"; }
            bind "n" "Tab" { MovePane; }
            bind "p" { MovePaneBackwards; }
        }

        // ── scroll / search ─────────────────────────────────────────────────
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

        // ── session ─────────────────────────────────────────────────────────
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

            // Nested sessions (a zellij on alucard inside a zellij here).
            // `]` climbs out to the host session, `[` dives back into the
            // guest, `f` makes the guest's pane fill the host. These relock
            // because the keyboard is about to belong to the other session.
            bind "]" { FocusHostSession; SwitchToMode "Locked"; }
            bind "[" { FocusGuestSession; SwitchToMode "Locked"; }
            bind "f" { ToggleHostFullscreen; SwitchToMode "Locked"; }
        }

        // ── rename prompts ──────────────────────────────────────────────────
        renametab {
            bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
            bind "Enter" { SwitchToMode "Locked"; }
        }
        renamepane {
            bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
            bind "Enter" { SwitchToMode "Locked"; }
        }

        // ── shared ──────────────────────────────────────────────────────────
        // Ctrl g toggles: it unlocks from Locked (above) and relocks from
        // everywhere else. Ctrl q exists only while unlocked, so it can never
        // reach a program by accident.
        shared_except "locked" {
            bind "Ctrl g" { SwitchToMode "Locked"; }
            bind "Ctrl q" { Quit; }
        }
        // Hop straight between sub-modes once unlocked. "normal" is excluded on
        // purpose: there the bare letter already does it, and a duplicate makes
        // the status bar advertise the Ctrl form instead of the real key.
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
        // Esc/Enter always mean "done, let me type" — except where they are the
        // prompt's own submit/cancel.
        shared_except "locked" "entersearch" "renametab" "renamepane" {
            bind "Esc" "Enter" { SwitchToMode "Locked"; }
        }
    }
  '';

  # ── Layouts ────────────────────────────────────────────────────────────────
  #
  # SSH panes use `ssh -t <host> "<cmd>; exec $SHELL -l"`:
  #   -t           forces a remote TTY so TUIs (btop/yazi/lazydocker) render.
  #   exec $SHELL  leaves a usable login shell when you quit the app, instead of
  #                a dead "press Enter to rerun" pane.
  # All panes to one host share a single SSH ControlMaster socket (hm-modules/
  # ssh.nix), so these are one connection, not N.
  #
  # These are *starting points*, not the persistent thing. The persistence is the
  # session: `zj`/`zjr` attach to a running server, and a layout only runs on the
  # first create. Nothing is re-executed when you come back.
  layouts = {
    # Local project work: `cd ~/proj && zj proj dev`.
    # A shell to build/test/run in, a long-lived pane for a dev server or log
    # tail, and a scratch shell. Panes inherit the cwd you launched from.
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

    # Long-running agent work: `zj myjob agent`, or on the server via
    # `zjr Bereitserver myjob` once the session exists.
    #
    # The agent gets the big pane and keeps running while you are detached. The
    # side pane is for reading what it did; the second tab is for checking the
    # result without disturbing the agent's pane.
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
    # btop (left), yazi at the downloads share, lazydocker.
    # The lazydocker pane goes through the `media-admin` alias, whose ssh config
    # carries the *arr-stack LocalForwards — so opening this layout also binds
    # those ports. It is the only pane with forwards, which avoids duplicate-bind
    # races; the others use plain `Bereitserver` over the shared master. TERM is
    # forced for that pane because media-admin otherwise sends TERM=xterm
    # (8-colour), which washes lazydocker out.
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

    # Work host: `zellij -l work`. Requires an `acGPT` Host entry in ssh.nix
    # (currently a commented stub — mirror the Mac's ~/.ssh to enable this from
    # NixOS).
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

  # Layouts that only make sense on the server itself (alucard). Kept to
  # binaries that are guaranteed present there, so the layout cannot come up
  # with dead panes.
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

  # Shell entry points. A session is a server process that outlives the
  # terminal, the SSH link and (via serialisation) the machine, so these make
  # "resume where I was" the default and "start something fresh" the explicit
  # case.
  #
  # They live here rather than in default.nix because alucard has fish too and
  # does not use `programs.zellij`; `zj` on the server is how a session started
  # by hand there is the same session `zjr` reattaches to from a workstation.
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
            # -n, not --layout: with --session, --layout means "add these tabs
            # to a session that already exists" and errors out when it does
            # not. -n is the flag that creates.
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

        # The session lives on the far end, so it survives this laptop closing.
        # -t forces a remote TTY; the keepalives make a dead link fail fast
        # instead of hanging on a half-open socket.
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
