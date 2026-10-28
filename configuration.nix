{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:

{
  # Tailworm (TS-2026-014..017) is fixed in 1.104.4, which is on nixpkgs master but not yet
  # on nixos-unstable. Build master's expression against this nixpkgs until the channel catches up.
  services.tailscale.package = lib.mkIf (lib.versionOlder pkgs.tailscale.version "1.104.4") (
    pkgs.callPackage "${inputs.nixpkgs-tailscale}/pkgs/by-name/ta/tailscale/package.nix" { }
  );

  environment.shells = with pkgs; [
    bash
    fish
  ];
  environment.variables.EDITOR = "nvim";

  programs.bash.interactiveShellInit = ''
    export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.config/emacs/bin/doom"
  '';
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  nixpkgs.config.allowUnfree = true;

  # Exact command/argument matches only. Rebuilding a writable checkout is root-equivalent.
  security.sudo.extraRules = [
    {
      users = [ username ];
      runAs = "root";
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch --flake /home/${username}/nixos-config\\#${config.networking.hostName}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --wait container-vulnerability-scan.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --wait host-vulnerability-scan.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/crowdsec-admin *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      download-buffer-size = 524288000;
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
}
