# zellij on the workstations (AC-0137, dracula): home-manager plumbing plus the shell entry
# points. The keymap, options and layouts come from ./lib.nix, which alucard also consumes
# through hosts/alucard/zellij.nix.
{ pkgs, ... }:
let
  zellij = import ./lib.nix {
    inherit pkgs;
    scrollbackEditor = "emacsclient -a '' -c";
    copyCommand = if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "wl-copy";
  };
in
{
  programs.zellij = {
    enable = true;
    # Never auto-start in a shell: auto-attach would fight nested sessions.
    enableFishIntegration = false;
    # Raw KDL rather than `settings`: the keybind block is a tree of multi-action binds the
    # attrset-to-KDL generator cannot express, and alucard needs the identical bytes.
    extraConfig = zellij.configText;
    layouts = zellij.layouts;
  };

  # From lib.nix so alucard's fish gets the identical `zj`.
  programs.fish.functions = zellij.fishFunctions;

  programs.fish.shellAbbrs.zjl = "zellij list-sessions";

  # Same text the `Ctrl g ?` binding renders.
  xdg.configFile."zellij/CHEATSHEET.md".source = ./cheatsheet.md;
}
