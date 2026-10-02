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

    # packages/linear-cli.nix installs a `deno compile` standalone binary verbatim
    # (dontStrip, dontPatchELF): it locates its own bundled JS via /proc/self/exe plus a
    # trailer appended past the ELF image, and both patchelf (has to grow the file to fit
    # a /nix/store interpreter path, which shifts the trailer) and a hand-rolled
    # `ld-linux --library-path` wrapper (makes ld.so, not the target, the kernel's execve
    # target, so /proc/self/exe is wrong) corrupt that self-location. nix-ld symlinks
    # /lib64/ld-linux-x86-64.so.2 — the exact path the binary's own PT_INTERP already
    # names — to a shim, so the kernel's normal ELF-interpreter loading exec's the binary
    # directly, unmodified, with /proc/self/exe intact. The default library set already
    # includes stdenv.cc.cc (libgcc_s.so.1, the one non-glibc .so this binary needs).
    nix-ld.enable = true;
  };

  # Desktop tower has no battery; power-profiles-daemon's EPP handling is dead weight here.
  services.power-profiles-daemon.enable = false;

  # No battery to report, but caelestia-shell queries UPower for AC/idle-inhibitor state.
  services.upower.enable = true;

  # HP LaserJet Professional P1102w on USB. hplip ships the PPD, but its hpcups filter
  # stops ZJS jobs with `hplip.plugin-error` (HPCupsFilter error 48) unless HP's
  # proprietary plugin is installed, even though models.dat lists plugin=0 for this
  # model — hence hplipWithPlugin (unfree) rather than hplip.
  # The URI pins the serial, so the queue survives moving the cable to another port.
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
