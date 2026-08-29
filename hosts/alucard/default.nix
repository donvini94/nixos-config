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
    ./services.nix
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
    ../../modules/openbao.nix
    ../../modules/teleport.nix
    ../../secrets/secrets.nix
  ];

  services.containerUpdates = {
    enable = true;
    units = [ "media-stack.service" ];
  };

  services.containerVulnerabilityScan = {
    enable = true;
    rootlessDockerUser = username;
  };

  # DRILL (temporary): run the repaired scanner during activation to prove it
  # now enumerates both Docker engines.
  systemd.services.container-vulnerability-scan.wantedBy = [ "multi-user.target" ];

  # Secrets platform. Reachable only over the tailnet (see private-access.nix);
  # sealed after every boot until an operator supplies the Shamir shares.
  services.localOpenBao.enable = true;

  # Access plane. Raw SSH on port 22 stays as the break-glass path until
  # Teleport has proven itself through a real recovery.
  services.localTeleport = {
    enable = true;
    publicHost = "alucard.tailf117a1.ts.net";
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
    # Multiplexer for SSH-disconnect persistence: `ssh Bereitserver`, then
    # `zellij a` resumes work intact after a dropped connection. zellij defaults
    # already detach-on-close and serialize sessions, so the package is enough.
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
