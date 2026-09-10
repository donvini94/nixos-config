{ lib, pkgs, ... }:
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
      # Same derivation as the emacs-pgtk in modules/programming.nix, so the daemon and
      # the emacsclient on PATH are one build. The option default is pkgs.emacs (X11/GTK).
      package = pkgs.emacs-pgtk;
      startWithGraphical = true;
    };
    printing.enable = true;
    power-profiles-daemon.enable = lib.mkDefault true;
    mullvad-vpn.enable = true;
    ratbagd.enable = true;
    usbmuxd.enable = true;
    ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
  };
}
