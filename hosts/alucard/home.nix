{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../hm-modules/ai-clients.nix
    # alucard does not import the root home.nix, so omp.nix is named here
    # explicitly or this host silently has no AGENTS.md, RULES.md or language
    # rules.
    ../../hm-modules/omp.nix
    # Same for the language servers: without this the `lsp` tool is inert here,
    # since they otherwise arrive only via the desktop set in the root home.nix.
    ../../hm-modules/lsp.nix
    # `zjr` drives a session running here, so this host's config.kdl interprets
    # the keys typed on the workstations; the keymaps must match.
    ./zellij.nix

    # Interactive shell tooling for SSH-driven agent sessions: the same modules
    # the workstations import, so the command line does not change under you at
    # the far end of an SSH link.
    #
    # fish.nix and shell.nix are a pair: fish.nix abbreviates `cd` to `z`, and
    # `z` is zoxide, which shell.nix enables. Importing one without the other
    # gives a shell whose `cd` does not exist.
    ../../hm-modules/fish.nix
    ../../hm-modules/shell.nix
    ../../hm-modules/starship.nix
    # NixOS host, so no fisher/fzf.fish contending for Ctrl-R.
    ../../hm-modules/atuin.nix
    ../../hm-modules/git.nix
    ../../hm-modules/cli-tools.nix
    ../../hm-modules/helix.nix
    # Adds the config, the `y` wrapper and shell integration for vincenzo; yazi
    # itself is already in environment.systemPackages for the other accounts.
    ../../hm-modules/yazi.nix
  ];

  # Deliberately NOT imported:
  #   ssh.nix        — its aliases all resolve to this host, so they are
  #                    self-loops here; it also replaces ~/.ssh/config, and this
  #                    box's file is the one root-adjacent automation uses.
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
