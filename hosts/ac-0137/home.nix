{ pkgs, username, ... }:

{
  imports = [
    ../../hm-modules/base.nix
    ../../hm-modules/ssh.nix
    ../../hm-modules/mpv.nix
    ../../hm-modules/zellij
    ../../hm-modules/zed.nix
    ../../hm-modules/doom.nix
    ../../ai/home/claude.nix
    ../../hm-modules/zotero-cli.nix
    ./fish.nix
    ./apps.nix
  ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    # The home-manager release at the locked input.
    stateVersion = "26.11";
  };


  # Private host blocks stay outside Git; earlier SSH options win.
  programs.ssh.includes = [
    "~/.orbstack/ssh/config"
    "config.local"
  ];

  # The system baseline that dracula gets from configuration.nix / modules/packages.nix.
  home.packages = with pkgs; [
    (callPackage ../../packages/linear-cli.nix { })
    # Replica sync uses Homebrew's notmuch CLI.
    muchsync
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
