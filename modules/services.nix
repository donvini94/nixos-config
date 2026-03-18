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
    # Emacs daemon disabled — Doom Emacs manages its own server.
    # emacsclient --alternate-editor="" auto-starts when needed.
    # emacs.enable = true;
    printing.enable = true;
    power-profiles-daemon.enable = true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
  };
}
