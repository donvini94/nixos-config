{ lib, ... }:
let
  mining = import ./mining-pools.nix;
in
{
  networking = {
    hostName = "alucard";
    useDHCP = lib.mkDefault true;
    # DHCP-only DNS left tailscaled forwarding to an empty upstream set after
    # activation, so public lookups returned SERVFAIL until reboot.
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        25
        80
        110
        143
        443
        465
        587
        993
        995
        4190
      ];
      allowedUDPPorts = [
        15637 # Enshrouded
        9876 # Bereit Rising (V Rising)
        9877 # Bereit Rising (V Rising)
      ];
      extraCommands =
        lib.concatMapStrings (port: "iptables -A OUTPUT -p tcp --dport ${toString port} -j DROP\n") mining.ports
        + lib.concatMapStrings (host: "iptables -A OUTPUT -d ${host} -j DROP\n") mining.hosts;
    };
  };

  services = {
    # resolved gives Tailscale a supported split-DNS manager: MagicDNS handles
    # the tailnet domain while ordinary names retain explicit fallbacks.
    resolved = {
      enable = true;
      settings.Resolve.FallbackDNS = [
        "1.1.1.1"
        "9.9.9.9"
      ];
    };
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    fail2ban.enable = true;
    qemuGuest.enable = true;
  };
}
