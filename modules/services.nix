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
