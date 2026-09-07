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
#
# The KDL and fish live in files next to this one so an editor can highlight them; this
# module only substitutes the four @tokens@ that differ between a workstation and the server.
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
  # Every custom layout must open with layouts/ui-template.kdl, or the session comes up with
  # no tab bar and no hint bar at all; `@uiTemplate@` is where a layout pulls it in.
  uiTemplate = builtins.readFile ./layouts/ui-template.kdl;
  layout = file: builtins.replaceStrings [ "@uiTemplate@" ] [ uiTemplate ] (builtins.readFile file);
in
{
  # config.kdl carries the whole config, keybinds included. Its `themes` block is mirrored
  # from the kitty themeFile (kitty-themes/Modus_Vivendi_Tinted.conf); the bg is the tinted
  # #0d0e1c, not pure black.
  configText =
    builtins.replaceStrings
      [
        "@copyCommand@"
        "@scrollbackEditor@"
        "@glow@"
        "@cheatsheet@"
      ]
      [
        (
          if copyCommand == null then
            "// no copy_command: selections travel out over OSC 52"
          else
            ''copy_command "${copyCommand}"''
        )
        scrollbackEditor
        "${pkgs.glow}"
        "${./cheatsheet.md}"
      ]
      (builtins.readFile ./config.kdl);

  # SSH panes use `ssh -t <host> "<cmd>; exec $SHELL -l"`: -t forces a remote TTY so TUIs
  # render, and `exec $SHELL` leaves a usable login shell when you quit the app instead of a
  # dead "press Enter to rerun" pane. All panes to one host share a single SSH ControlMaster
  # socket (hm-modules/ssh.nix), so these are one connection, not N.
  #
  # A layout runs only on session create; `zj`/`zjr` attach to a running server and
  # re-execute nothing.
  layouts = {
    # Local project work: `cd ~/proj && zj proj dev`. Panes inherit the cwd you launched from.
    dev = layout ./layouts/dev.kdl;

    # Long-running agent work: `zj myjob agent`, or `zjr Bereitserver myjob` on the server.
    agent = layout ./layouts/agent.kdl;

    # Bereitserver/alucard from a workstation: `zellij -l bereit`.
    # The lazydocker pane goes through the `media-admin` alias, whose ssh config carries the
    # *arr-stack LocalForwards, so opening this layout also binds those ports. It is the only
    # pane with forwards, which avoids duplicate-bind races. TERM is forced there because
    # media-admin otherwise sends TERM=xterm (8-colour), which washes lazydocker out.
    bereit = layout ./layouts/bereit.kdl;

    # Work host: `zellij -l work`. Requires an `acGPT` Host entry in ssh.nix, which is
    # currently a commented stub.
    work = layout ./layouts/work.kdl;
  };

  # Layouts that only make sense on the server itself (alucard). Kept to binaries guaranteed
  # present there, so the layout cannot come up with dead panes.
  serverLayouts = {
    # `zjr Bereitserver ops` after `zellij --session ops --layout sys` once.
    sys = layout ./layouts/sys.kdl;
  };

  # These live here rather than in default.nix because alucard has fish too and does not use
  # `programs.zellij`: `zj` on the server starts the same session `zjr` reattaches to.
  fishFunctions = {
    zj = {
      description = "Attach to (or create) a persistent local zellij session";
      body = builtins.readFile ./fish/zj.fish;
    };

    zjr = {
      description = "Attach to (or create) a persistent zellij session on a remote host";
      body = builtins.readFile ./fish/zjr.fish;
    };

    zjls = {
      description = "List zellij sessions on a remote host";
      body = builtins.readFile ./fish/zjls.fish;
    };
  };
}
