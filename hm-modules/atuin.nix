# Atuin — synced shell history, imported by the NixOS hosts only.
#
# Split out of shell.nix because atuin's fish integration rebinds Ctrl-R, and the Mac's
# imperative fisher plugin set already gives that key to `patrickf1/fzf.fish`. Two
# bindings racing for Ctrl-R is a worse outcome than not having atuin there, and the
# alternative — importing this on the Mac with `lib.mkForce` on the keybinding — would
# make dracula's behaviour depend on a Mac workaround. Migrating the Mac means moving
# fisher's plugins into `programs.fish.plugins` first; `fishPlugins.fzf-fish` is
# `broken = true` at the locked nixpkgs, so that is not today.
{ ... }:

{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = true;
      sync_address = "https://dumusstbereitsein.de";
      search_mode = "prefix";
    };
  };
}
