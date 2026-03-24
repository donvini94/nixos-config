{ ... }:
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
    emacs = {
      enable = true;
      startWithGraphical = true;  # wait for graphical session (needed for pgtk)
    };
    printing.enable = true;
    power-profiles-daemon.enable = true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
  };
}
