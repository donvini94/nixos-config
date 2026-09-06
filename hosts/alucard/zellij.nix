# zellij on alucard, for vincenzo.
#
# The keymap is the same bytes as the workstations (hm-modules/zellij/lib.nix)
# and that is the point: with `zjr Bereitserver <name>` the session runs *here*,
# so it is this file's config.kdl that interprets keystrokes typed on the Mac.
# A keymap that drifted between the two would be worse than no keymap.
#
# Unlike the workstations this does not use `programs.zellij`. The binary stays
# in `environment.systemPackages` (hosts/alucard/default.nix) because
# `ssh host -- zellij ...` runs a non-interactive shell that never sources the
# home-manager profile — /run/current-system/sw/bin is the only PATH entry
# guaranteed to be there. Installing it a second time would just shadow it.
{ lib, pkgs, ... }:
let
  zellij = import ../../hm-modules/zellij/lib.nix {
    inherit pkgs;
    # Headless: there is no Emacs frame to pop, and neovim is already here via
    # modules/packages.nix.
    scrollbackEditor = "nvim";
    # copyCommand deliberately unset: OSC 52 carries the selection back out
    # through the SSH link to whichever terminal you are actually sitting at.
  };

  # The `bereit` and `work` layouts SSH *into* this box and elsewhere; they only
  # belong on a workstation. What is useful here is local project/agent work
  # plus the host's own vitals.
  layouts = {
    inherit (zellij.layouts) dev agent;
  }
  // zellij.serverLayouts;
in
{
  xdg.configFile = {
    "zellij/config.kdl".text = zellij.configText;
    "zellij/CHEATSHEET.md".source = ../../hm-modules/zellij/cheatsheet.md;
  }
  // lib.mapAttrs' (
    name: text: lib.nameValuePair "zellij/layouts/${name}.kdl" { inherit text; }
  ) layouts;
}
