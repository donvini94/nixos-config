{ pkgs, username, ... }:

{
  imports = [
    ../../hm-modules/git.nix
    ../../hm-modules/ssh.nix
    ../../hm-modules/fish.nix
    ../../hm-modules/shell.nix
    ../../hm-modules/helix.nix
    ../../hm-modules/mpv.nix
    ../../hm-modules/yazi.nix
    ../../hm-modules/zellij.nix
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

  # Deliberately NOT imported:
  #   kitty.nix      — the Mac terminal is Ghostty (./apps.nix)
  #   starship.nix   — tide owns the prompt here, via fisher
  #   atuin.nix      — Ctrl-R already belongs to fisher's fzf.fish (see hm-modules/atuin.nix)
  #   packages.nix   — Linux GUI apps
  #   zathura.nix, gtk.nix, hyprland.nix, caelestia.nix, services.nix, pokemmo.nix,
  #   email.nix      — Wayland/GTK/systemd, or the mail stack that stays on Homebrew
  #   ai-clients.nix — reads osConfig.networking.hostName and osConfig.services.remoteOpenAI,
  #                    which are NixOS options and do not exist on a darwin osConfig

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    # home-manager release at the locked input (7834e825).
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;

  # hm-modules/ssh.nix replaces ~/.ssh/config wholesale, and this machine's current file
  # carries host blocks that must never be committed: alucard, dracula, acGPT and
  # probeaufgabe are named by bare IP, plus OrbStack's generated include. The Include
  # directive is emitted ahead of every managed Host block
  # (home-manager/modules/programs/ssh.nix:879-889) and ssh_config is first-match-wins,
  # so a local file can both restore and override. `config.local` is resolved relative to
  # ~/.ssh. A missing include target is not an error for OpenSSH, so this is safe before
  # the file exists.
  programs.ssh.includes = [
    "~/.orbstack/ssh/config"
    "config.local"
  ];

  # The system baseline that dracula gets from configuration.nix / modules/packages.nix.
  # Everything here replaces a Homebrew formula of the same name.
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
    lazygit
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
