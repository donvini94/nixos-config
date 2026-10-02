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

    # Linear's Deno bundle cannot be patchelf'd; see packages/linear-cli.nix.
    nix-ld.enable = true;
  };

  # Desktop tower has no battery; power-profiles-daemon's EPP handling is dead weight here.
  services.power-profiles-daemon.enable = false;

  # No battery to report, but caelestia-shell queries UPower for AC/idle-inhibitor state.
  services.upower.enable = true;

  # The P1102w needs HP's proprietary plugin despite models.dat's plugin=0.
  services.printing.drivers = [ pkgs.hplipWithPlugin ];
  hardware.printers = {
    ensurePrinters = [
      {
        name = "LaserJet_P1102w";
        description = "HP LaserJet Professional P1102w";
        deviceUri = "usb://HP/LaserJet%20Professional%20P%201102w?serial=000000000W46A7Z3PR1a";
        model = "HP/hp-laserjet_professional_p_1102w.ppd.gz";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "LaserJet_P1102w";
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings.features.cdi = true;
  };

  environment.systemPackages = with pkgs; [
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
