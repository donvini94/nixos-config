# The keymap must stay byte-identical to the workstations': `zjr Bereitserver
# <name>` runs the session here, so this config.kdl interprets the keys typed
# there. Not `programs.zellij` — the binary is in environment.systemPackages
# because `ssh host -- zellij ...` never sources the home-manager profile.
{ lib, pkgs, ... }:
let
  zellij = import ../../hm-modules/zellij/lib.nix {
    inherit pkgs;
    # Headless: there is no Emacs frame to pop.
    scrollbackEditor = "nvim";
    # copyCommand deliberately unset: OSC 52 carries the selection back out
    # through the SSH link to whichever terminal you are actually sitting at.
  };

  # The `bereit` and `work` layouts SSH into this box; they belong on a
  # workstation only.
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

  # Only the local entry point: `zjr`/`zjls` drive a session on another host and
  # this box is the far end.
  programs.fish.functions = { inherit (zellij.fishFunctions) zj; };
}
