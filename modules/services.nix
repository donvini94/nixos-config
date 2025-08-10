{
  config,
  lib,
  pkgs,
  ...
}:
{
  services = {
    logind.lidSwitchExternalPower = "ignore";
    logind.lidSwitch = "suspend";
    pipewire.wireplumber.enable = true;
    emacs.enable = true;
    printing.enable = true;
    xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.options = "caps:escape, grp:alt_shift_toggle";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    power-profiles-daemon.enable = true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
    #resolved = {
    #  enable = true;
    #  extraConfig = ''
    #    DNS=45.90.28.0#463172.dns.nextdns.io
    #    DNS=2a07:a8c0::#463172.dns.nextdns.io
    #    DNS=45.90.30.0#463172.dns.nextdns.io
    #    DNS=2a07:a8c1::#463172.dns.nextdns.io
    #    DNSOverTLS=yes
    #  '';
    #};
    #nextdns.enable = true;
  };
}
