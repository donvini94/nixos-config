{ pkgs, ... }:

{
  programs = {
    ausweisapp = {
      enable = true;
      openFirewall = true;
    };
    noisetorch.enable = true;
    obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
      ];
    };
  };

  # Desktop tower has no battery; power-profiles-daemon's EPP handling is dead weight here.
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "performance";

  # No battery to report, but caelestia-shell queries UPower for AC/idle-inhibitor state.
  services.upower.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings.features.cdi = true;
  };

  environment.systemPackages = with pkgs; [
    cudatoolkit
    mesa
    libva
    nvitop
    nvidia-container-toolkit
    calibre
    filebot
    transmission_4-gtk
    android-tools
    lmstudio
    droidcam

    piper
    lact
    undervolt
    s-tui
    stress
  ];
}
