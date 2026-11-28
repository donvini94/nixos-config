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
    # The provider's DHCP search domain (goodsrv.de) made bare names like "staging"
    # resolve to unrelated public hosts before MagicDNS; tailnet names must win.
    dhcpcd.extraConfig = "nooption domain_name domain_search";
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
      # Rootful Docker bridge egress bypasses OUTPUT; Docker keeps DOCKER-USER's rules and
      # evaluates them before its own accepts. CrowdSec's bouncer also hooks that chain, so
      # it is never flushed here.
      extraCommands = ''
        iptables -w -N mining-egress 2>/dev/null || iptables -w -F mining-egress
        ${lib.concatMapStrings (
          port: "iptables -w -A mining-egress -p tcp --dport ${toString port} -j DROP\n"
        ) mining.ports}
        ${lib.concatMapStrings (host: "iptables -w -A mining-egress -d ${host} -j DROP\n") mining.hosts}
        iptables -w -N DOCKER-USER 2>/dev/null || true
        for chain in OUTPUT DOCKER-USER; do
          iptables -w -C "$chain" -j mining-egress 2>/dev/null \
            || iptables -w -I "$chain" -j mining-egress
        done
        # Egress-less Docker networks (masquerade off) reach mailcow's submission and IMAPS
        # ports through the published DNAT, but mailcow's reply to a foreign container address
        # is dropped by Docker's raw-table direct-routing guard. Masquerade only that hop, only
        # for local bridge sources: masquerading internet clients would put them in mailcow's
        # mynetworks. CalDAV needs nothing: SOGo sits behind the host's own nginx.
        iptables -w -t nat -C POSTROUTING -s 172.16.0.0/12 -o br-mailcow -p tcp -m multiport --dports 587,993 -m conntrack --ctstate DNAT -j MASQUERADE 2>/dev/null \
          || iptables -w -t nat -I POSTROUTING -s 172.16.0.0/12 -o br-mailcow -p tcp -m multiport --dports 587,993 -m conntrack --ctstate DNAT -j MASQUERADE
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
