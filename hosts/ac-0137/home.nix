{ pkgs, username, ... }:

{
  imports = [
    ../../hm-modules/git.nix
    ../../hm-modules/ssh.nix
    ../../hm-modules/fish.nix
    ../../hm-modules/shell.nix
    ../../hm-modules/atuin.nix
    ../../hm-modules/helix.nix
    ../../hm-modules/mpv.nix
    ../../hm-modules/yazi.nix
    ../../hm-modules/zellij
    ../../hm-modules/zed.nix
    ../../hm-modules/doom.nix
    ../../hm-modules/claude.nix
    ../../hm-modules/omp.nix
    ../../hm-modules/lsp.nix
    ../../hm-modules/cli-tools.nix
    ./fish.nix
    ./apps.nix
    ./omp.nix
  ];

  # Deliberately NOT imported: kitty.nix, starship.nix, packages.nix, zathura.nix,
  # gtk.nix, hyprland.nix, caelestia.nix, services.nix, pokemmo.nix and email.nix are
  # Wayland/GTK/systemd or superseded on this host. ai-clients.nix reads
  # osConfig.networking.hostName and osConfig.services.remoteOpenAI, NixOS options that
  # do not exist on a darwin osConfig.

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    # The home-manager release at the locked input.
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;

  # hm-modules/ssh.nix replaces ~/.ssh/config wholesale, and this machine's file carries
  # host blocks that must never be committed. The Include directive is emitted ahead of
  # every managed Host block (home-manager/modules/programs/ssh.nix:879-889) and
  # ssh_config is first-match-wins, so a local file can both restore and override.
  # `config.local` resolves relative to ~/.ssh; a missing include target is not an error
  # for OpenSSH.
  programs.ssh.includes = [
    "~/.orbstack/ssh/config"
    "config.local"
  ];

  # The system baseline that dracula gets from configuration.nix / modules/packages.nix.
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    eza
    fzf

    btop
    bottom
    dust

    neovim
    lazydocker

    age
    sops

    shellcheck
    shfmt

    magic-wormhole
    resvg
    timg
    cheat
    fastfetch
  ];
}
