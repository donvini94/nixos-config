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

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

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
