{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../hm-modules/ai-clients.nix
    # The harness context must be identical on every machine an agent runs on.
    # alucard is a server host and does not import the root home.nix, so omp.nix
    # has to be named here explicitly or this box silently has no AGENTS.md,
    # no RULES.md and none of the language rules.
    ../../hm-modules/omp.nix
    # Same reasoning for the language servers: without this the `lsp` tool is
    # inert on alucard for every language, because the servers otherwise arrive
    # only through the desktop package set in the root home.nix.
    ../../hm-modules/lsp.nix
    # The zellij keymap has to match the workstations byte for byte: `zjr` drives
    # a session running here, so this host's config.kdl is what interprets the
    # keys typed on the Mac.
    ./zellij.nix

    # --- Interactive shell and dev tooling -----------------------------------
    # This host is now a place work actually happens (agent sessions driven over
    # SSH), not just a place services run. These are the same modules the
    # workstations import, so the command line does not change under you when
    # the prompt is on the far end of an SSH link.
    #
    # fish.nix and shell.nix are a pair: fish.nix abbreviates `cd` to `z`, and
    # `z` is zoxide, which shell.nix enables. Importing one without the other
    # gives a shell whose `cd` does not exist.
    ../../hm-modules/fish.nix
    ../../hm-modules/shell.nix
    ../../hm-modules/starship.nix
    # NixOS host, so no fisher/fzf.fish contending for Ctrl-R — see the header
    # of atuin.nix for why the Mac is the exception rather than this box.
    ../../hm-modules/atuin.nix
    ../../hm-modules/git.nix
    ../../hm-modules/cli-tools.nix
    ../../hm-modules/helix.nix
    # yazi is also in environment.systemPackages for the other accounts on this
    # host. Same nixpkgs, so it is the same store path twice in two profiles,
    # not a second build; what this adds for vincenzo is the config, the `y`
    # wrapper and the shell integration.
    ../../hm-modules/yazi.nix
  ];

  # Deliberately NOT imported:
  #   ssh.nix        — every alias in it (Bereitserver, ai-admin, media-admin,
  #                    bereit) resolves to dumusstbereitsein.de, which is THIS
  #                    host; on alucard they are self-loops. It also replaces
  #                    ~/.ssh/config wholesale, and this box's file is the one
  #                    used by root-adjacent automation.
  #   claude.nix     — the ~/.claude pointer and .stignore belong on the machines
  #                    that author context; here OMP is driven, not configured.
  #   packages.nix, gtk.nix, hyprland.nix, caelestia.nix, kitty.nix, zathura.nix,
  #   mpv.nix, services.nix, email.nix, zed.nix, doom.nix, pokemmo.nix
  #                  — GUI, Wayland/GTK, or user-session desktop services.

  nixpkgs.config.allowUnfree = true;
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };
  programs.home-manager.enable = true;
}
