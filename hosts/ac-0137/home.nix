{ pkgs, inputs, username, ... }:

{
  imports = [
    ../../hm-modules/base.nix
    ../../hm-modules/ssh.nix
    ../../hm-modules/mpv.nix
    ../../hm-modules/zellij
    ../../hm-modules/zed.nix
    ../../hm-modules/doom.nix
    ../../coding-agents/home/claude.nix
    ../../hm-modules/zotero-cli.nix
    ./fish.nix
    ./apps.nix
    ./syncthing.nix
  ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    # The home-manager release at the locked input.
    stateVersion = "26.11";
  };


  nixpkgs.config.allowUnfree = true;

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

    # Toolchains dracula gets from modules/desktop/programming.nix; cmake comes from
    # Homebrew, the debuggers and sqlite from Xcode.
    python313
    rustup
    uv
    cargo-watch
    nodejs_22
    jdk21
    editorconfig-core-c
    inputs.nil.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-code
    codex

    magic-wormhole
    resvg
    timg
    cheat
    fastfetch
  ];
}
