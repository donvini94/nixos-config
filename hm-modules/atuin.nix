# Atuin — synced shell history, imported by every host.
#
# Split out of shell.nix because `atuin init fish` claims two keys: Up-arrow and
# Ctrl-R. Up-arrow is the one actually used here; Ctrl-R on the Mac already
# belongs to `patrickf1/fzf.fish`, which fisher installs imperatively (see
# hosts/ac-0137/fish.nix for why that plugin set is not declared). Rather than
# let two bindings race — fisher binds in conf.d, home-manager binds later in
# config.fish, so the winner is an ordering accident — atuin is told not to take
# Ctrl-R there at all. The NixOS hosts have no fzf.fish and keep both keys.
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
{ lib, pkgs, ... }:

{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    # Appended to `atuin init fish`; see the Ctrl-R note above.
    flags = lib.optional pkgs.stdenv.hostPlatform.isDarwin "--disable-ctrl-r";
    settings = {
      auto_sync = true;
      sync_address = "http://alucard.tailf117a1.ts.net:28888";
      search_mode = "prefix";
    };
  };
}
