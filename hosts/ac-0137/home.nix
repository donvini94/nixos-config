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
    ../../hm-modules/pi.nix
    ../../hm-modules/agent-skills.nix
    ../../hm-modules/zotero-cli.nix
    ./fish.nix
    ./apps.nix
    ./omp.nix
  ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    # The home-manager release at the locked input.
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;

  # Private host blocks stay outside Git; earlier SSH options win.
  programs.ssh.includes = [
    "~/.orbstack/ssh/config"
    "config.local"
  ];

  # The system baseline that dracula gets from configuration.nix / modules/packages.nix.
  home.packages = with pkgs; [
    (callPackage ../../packages/linear-cli.nix { })
    # notmuch replica sync with the alucard mail hub (mail/bin/mail-replica-sync).
    # No Homebrew formula exists; it runs the Homebrew notmuch CLI, same 0.40 as nix.
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
