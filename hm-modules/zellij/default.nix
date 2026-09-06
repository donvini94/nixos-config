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

  # `zj`/`zjr`/`zjls` come from lib.nix so alucard's fish gets the identical
  # `zj`; see the comment there.
  programs.fish.functions = zellij.fishFunctions;

  programs.fish.shellAbbrs.zjl = "zellij list-sessions";

  # Same text the `Ctrl g ?` binding renders, put where you would look for it.
  xdg.configFile."zellij/CHEATSHEET.md".source = ./cheatsheet.md;
}
