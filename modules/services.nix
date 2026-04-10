{ ... }:
{
  security.rtkit.enable = true;

  services = {
    pipewire = {
      enable = true;
      wireplumber.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    emacs = {
      enable = true;
      startWithGraphical = true;
    };
    printing.enable = true;
    power-profiles-daemon.enable = true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
  };
}
