{
  config,
  lib,
  pkgs,
  ...
}:
{
  services = {
    pipewire = {
      enable = true;
      wireplumber.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    emacs.enable = true;
    printing.enable = true;
    xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.options = "caps:escape, grp:alt_shift_toggle";
    };
    power-profiles-daemon.enable = true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
  };
}
