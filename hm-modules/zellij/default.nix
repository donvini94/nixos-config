# zellij on the workstations (AC-0137, dracula).
#
# The keymap, options and layouts come from ./lib.nix, which alucard also
# consumes through hosts/alucard/zellij.nix — read that file for why the keymap
# is shaped the way it is. This module is only the home-manager plumbing plus
# the shell entry points.
{ pkgs, ... }:
let
  zellij = import ./lib.nix {
    inherit pkgs;
    # GUI Emacs: `EditScrollback` pops a frame, and magit/doom are where the
    # editing actually happens on these two machines.
    scrollbackEditor = "emacsclient -a '' -c";
    copyCommand = if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "wl-copy";
  };
in
{
  programs.zellij = {
    enable = true;
    # Never auto-start in a shell: the point of `zj`/`zjr` is that you choose
    # which session you are joining, and auto-attach would fight nested sessions.
    enableFishIntegration = false;
    # Raw KDL rather than `settings`, because the keybind block is a tree of
    # multi-action binds that the attrset-to-KDL generator cannot express, and
    # because alucard needs the identical bytes without home-manager.
    extraConfig = zellij.configText;
    layouts = zellij.layouts;
  };

  # A session is a server process that outlives the terminal, the SSH link and
  # (via serialisation) the machine. These two entry points make "resume where I
  # was" the default and "start something fresh" the explicit case.
  programs.fish.functions = {
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

  programs.fish.shellAbbrs.zjl = "zellij list-sessions";

  # Same text the `Ctrl g ?` binding renders, put where you would look for it.
  xdg.configFile."zellij/CHEATSHEET.md".source = ./cheatsheet.md;
}
