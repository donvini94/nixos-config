{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  openstackServerId = "d94fd33f-6907-4d47-9929-ea785a78676d";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./networking.nix
    ./services.nix
    ./media.nix
    ./users.nix
    ./syncthing.nix
    ../../modules/packages.nix
    ../../configuration.nix
    ../../secrets/secrets.nix
  ];

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
    openssl
    apacheHttpd
    filebot
    cifs-utils
    docker-compose
    keycloak
    ffmpeg
    yt-dlp
    openstackclient
    inetutils
    claude-code
    nodejs_22
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

  # Scheduled tasks: OpenStack shelve/unshelve
  systemd.services.unshelve-server = {
    description = "Unshelve OpenStack server";
    serviceConfig = {
      Type = "oneshot";
      User = "vincenzo";
      ExecStart = pkgs.writeShellScript "unshelve-server.sh" ''
        source /home/vincenzo/.leafcloud_rc.sh
        ${pkgs.openstackclient}/bin/openstack server unshelve ${openstackServerId}
      '';
    };
  };

  systemd.timers.unshelve-server = {
    description = "Timer for unshelving OpenStack server";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon-Fri *-*-* 07:00:00";
      Persistent = true;
      Unit = "unshelve-server.service";
    };
  };

  systemd.services.shelve-server = {
    description = "Shelve OpenStack server";
    serviceConfig = {
      Type = "oneshot";
      User = "vincenzo";
      ExecStart = pkgs.writeShellScript "shelve-server.sh" ''
        source /home/vincenzo/.leafcloud_rc.sh
        ${pkgs.openstackclient}/bin/openstack server shelve ${openstackServerId}
      '';
    };
  };

  systemd.timers.shelve-server = {
    description = "Timer for shelving OpenStack server";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon-Fri *-*-* 19:00:00";
      Persistent = true;
      Unit = "shelve-server.service";
    };
  };

  system.stateVersion = "23.05";
}
