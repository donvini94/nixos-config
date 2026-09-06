# Atuin — synced shell history, imported by the NixOS hosts only.
#
# Split out of shell.nix because atuin's fish integration rebinds Ctrl-R, and the Mac's
# imperative fisher plugin set already gives that key to `patrickf1/fzf.fish`. Two
# bindings racing for Ctrl-R is a worse outcome than not having atuin there, and the
# alternative — importing this on the Mac with `lib.mkForce` on the keybinding — would
# make dracula's behaviour depend on a Mac workaround. Migrating the Mac means moving
# fisher's plugins into `programs.fish.plugins` first; `fishPlugins.fzf-fish` is
# `broken = true` at the locked nixpkgs, so that is not today.
#
# The server is `services.atuin` on alucard (hosts/alucard/services/hosted-applications.nix),
# reached over the tailnet: it binds 127.0.0.1:8888 there and is published as
# tailnet port 28888 by hosts/alucard/private-access.nix. This address is
# deliberately NOT the public `https://dumusstbereitsein.de` it used to be —
# that vhost answers 404 to everything and never ran a sync server, so sync had
# silently failed since the setting was written. Shell history is a keystroke
# log of every host it touches; the tailnet is the right blast radius for it,
# and MagicDNS resolves the name on both machines because both run tailscaled.
#
# Plain http is intentional: the hop is inside WireGuard, and terminating TLS at
# `tailscale serve --https` would buy nothing for a non-browser client.
{ ... }:

{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = true;
      sync_address = "http://alucard.tailf117a1.ts.net:28888";
      search_mode = "prefix";
    };
  };
}
