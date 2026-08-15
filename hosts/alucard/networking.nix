{ lib, ... }:
{
  networking = {
    hostName = "alucard";
    useDHCP = lib.mkDefault true;
    # Tailscale's MagicDNS resolver still needs stable upstream resolvers for
    # public names.  DHCP-only DNS left tailscaled forwarding to an empty
    # upstream set after activation, so public lookups returned SERVFAIL until
    # the machine was rebooted.
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
        9876 # V Rising
        9877 # V Rising
        9878 # Giacomo V Rising
        9879 # Giacomo V Rising
      ];
      # Block outbound connections to known mining pools (SECURITY FIX)
      extraCommands = ''
        iptables -A OUTPUT -p tcp --dport 3333 -j DROP
        iptables -A OUTPUT -p tcp --dport 4444 -j DROP
        iptables -A OUTPUT -p tcp --dport 5555 -j DROP
        iptables -A OUTPUT -p tcp --dport 7777 -j DROP
        iptables -A OUTPUT -p tcp --dport 8333 -j DROP
        iptables -A OUTPUT -p tcp --dport 9333 -j DROP
        iptables -A OUTPUT -d 141.95.72.61 -j DROP
        iptables -A OUTPUT -d 141.95.72.59 -j DROP
      '';
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
