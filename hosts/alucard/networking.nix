{ lib, ... }:
{
  networking = {
    hostName = "alucard";
    useDHCP = lib.mkDefault true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        25
        53
        80
        110
        143
        443
        465
        587
        873
        993
        995
        4190
        11445
        11335
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
