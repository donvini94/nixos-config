# Everything a customer's Hetzner Cloud server needs besides the stack: disk layout for
# nixos-anywhere, boot and network setup, root SSH over the tailnet only, a tagged
# Tailscale join and the customer-side monitoring. The operator's own hosts do not
# import this.
{
  config,
  lib,
  modulesPath,
  ...
}:

let
  cfg = config.services.aiStack.host;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./default.nix
  ];

  options.services.aiStack.host = {
    operatorSshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Public keys allowed to log in as root over the tailnet.";
    };

    ipv6Address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "2a01:4f8:c012:3456::1/64";
      description = "The server's IPv6 address from Hetzner; IPv4 comes from DHCP.";
    };

    disk = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "System disk nixos-anywhere partitions.";
    };

    publicSsh = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also accept SSH on the public interface, e.g. while the tailnet join is debugged.";
    };
  };

  config = {
    services.aiStack.enable = true;

    disko.devices.disk.main = {
      device = cfg.disk;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Hetzner Cloud boots x86 servers with legacy BIOS; the ESP keeps UEFI possible.
          bios = {
            size = "1M";
            type = "EF02";
          };
          esp = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };

    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    networking = {
      useDHCP = false;
      useNetworkd = true;
    };
    systemd.network.networks."10-uplink" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "ipv4";
      address = lib.optional (cfg.ipv6Address != null) cfg.ipv6Address;
      routes = lib.optional (cfg.ipv6Address != null) { Gateway = "fe80::1"; };
    };

    time.timeZone = "Europe/Berlin";
    zramSwap.enable = true;

    users.mutableUsers = false;
    users.users.root.openssh.authorizedKeys.keys = cfg.operatorSshKeys;
    services.openssh = {
      enable = true;
      openFirewall = cfg.publicSsh;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    # A pre-authorized key whose ACL owner may assign tag:customer.
    sops.secrets."tailscale/auth_key" = {
      sopsFile = config.services.aiStack.secretsFile;
      mode = "0400";
    };
    services.tailscale = {
      authKeyFile = config.sops.secrets."tailscale/auth_key".path;
      extraUpFlags = [ "--advertise-tags=tag:customer" ];
    };

    # sops-nix decrypts with the age key derived from this host key, which the operator
    # generates before installation and hands to nixos-anywhere.
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # n8n runs as UID 1000 in its container; on customer servers no person has that UID.
    services.aiStack.egress.uids = [ 1000 ];

    services.observability.exporters = {
      enable = true;
      scrapeInterface = "tailscale0";
    };
    services.containerVulnerabilityScan.enable = true;
    services.hostVulnerabilityScan.enable = true;

    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };

    services.journald.settings.Journal.SystemMaxUse = "2G";
  };
}
