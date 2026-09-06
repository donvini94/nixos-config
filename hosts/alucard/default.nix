{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./networking.nix
    ./private-access.nix
    ./security.nix
    ./services/default.nix
    ./media.nix
    ./users.nix
    ./syncthing.nix
    ./ai.nix
    ../../modules/packages.nix
    ../../modules/paperless.nix
    ../../modules/mailcow-tls.nix
    ../../modules/observability.nix
    ../../modules/container-updates.nix
    ../../modules/vulnerability-scan.nix
    ../../modules/offsite-backup.nix
    ../../secrets/secrets.nix
  ];

  # The flake wires home-manager for the primary user only. Kyrill drives this
  # box from his own account, so his home configuration is named here.
  home-manager.users.kyrill = import ./home-kyrill.nix;

  services.containerUpdates = {
    enable = true;
    units = [ "media-stack.service" ];
  };

  services.containerVulnerabilityScan = {
    enable = true;
    rootlessDockerUser = username;
  };

  # Boot
  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "cifs" ];
  };

  # Nix settings (shared base in configuration.nix)
  nix = {
    settings = {
      sandbox = true;
      max-jobs = 10;
    };
    gc.dates = "23:00";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Packages
  environment.systemPackages = with pkgs; [
    yazi
    # Multiplexer for SSH-disconnect persistence and for long-running agent
    # sessions driven from the Mac/dracula (`zjr Bereitserver <name>`). It is a
    # system package, not a home-manager one, because `ssh host -- zellij ...`
    # runs a non-interactive shell that never sources the per-user profile.
    # Its configuration lives in hosts/alucard/zellij.nix.
    # (tmux below is the incumbent — kept until the zellij workflow is proven.)
    zellij
    openssl
    apacheHttpd
    filebot
    cifs-utils
    docker-compose
    # Required by Mailcow's official update.sh migration path.
    jq
    keycloak
    ffmpeg
    yt-dlp
    openstackclient
    inetutils
    claude-code
    nodejs_22
    cargo
    gcc
    lnav
  ];

  # System-level fish, on top of the home-manager one. This is what generates
  # completions from `environment.systemPackages` into /etc/fish and what makes
  # the shell a valid entry in /etc/shells, which is the precondition for
  # users.users.vincenzo.shell (hosts/alucard/users.nix).
  programs.fish.enable = true;

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    terminal = "screen-256color";
  };

  # Hetzner storage mount
  fileSystems."/mnt/hetzner" = {
    device = "//u487137.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.templates."smb-hetzner".path}"
      "vers=3.1.1"
      "sec=ntlmssp"
      "seal"
      "iocharset=utf8"
      "file_mode=0644"
      "dir_mode=0755"
      "uid=jellyfin"
      "gid=jellyfin"
      "_netdev"
      "x-systemd.automount"
      "noauto"
      "nofail"
      "serverino"
    ];
  };

  system.stateVersion = "23.05";
}
