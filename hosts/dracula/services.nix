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

  # No battery to report, but caelestia-shell queries UPower for AC/idle-inhibitor state.
  services.upower.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings.features.cdi = true;
  };

  environment.systemPackages = with pkgs; [
    # Matches lib/cuda-torch.nix's cudaPackages_13 (torch-bin is cu130): a
    # user compiling a CUDA extension against that torch's headers here needs
    # nvcc from the same major version, not the ambient default (12.9).
    cudaPackages_13.cudatoolkit
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
