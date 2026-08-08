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

  # Desktop tower: no battery, so power-profiles-daemon's balance_performance EPP
  # is dead weight. Pin governor to performance instead.
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "performance";

  # UPower has no battery to report on, but caelestia-shell queries it for
  # AC/idle-inhibitor state and a few widgets. Cheap to keep available.
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

    # Hardware-specific tuning tools
    piper
    lact
    undervolt
    s-tui
    stress
  ];
}
