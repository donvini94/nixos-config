{
  config,
  pkgs,
  username,
  ...
}:

{
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

  # NOPASSWD is scoped to these exact commands and host; a switch from a user-writable
  # checkout is still root-equivalent, so this is no boundary against repository code.
  #
  # The two scan units are here so a scan can be run and verified on demand rather than
  # only when its timer fires. Both are oneshot units that read images and publish
  # metrics; `start --wait` cannot pass them arguments.
  #
  # crowdsec-admin (alucard only) is itself a hardened wrapper -- it re-execs `cscli`
  # under systemd-run with DynamicUser, NoNewPrivileges, PrivateTmp/Users and
  # ProtectSystem=strict (hosts/alucard/security.nix), not a raw shell -- so NOPASSWD
  # on the whole wrapper doesn't hand out general root, only CrowdSec's own admin
  # surface (decisions/bouncers/alerts/etc). Needed to check ban/decision state (e.g.
  # after a WAF change causes a burst of blocked requests) without a TTY for sudo.
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
