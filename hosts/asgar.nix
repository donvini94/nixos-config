{ config, lib, pkgs, ... }:

{
  networking.hostName = "asgar";
   hardware.opengl.extraPackages = with pkgs; [
    intel-media-driver # LIBVA_DRIVER_NAME=iHD
    vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
    vaapiVdpau
    libvdpau-va-gl
  ];

 
  system.stateVersion = "23.05";

}










