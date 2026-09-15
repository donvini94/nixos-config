{
  config,
  lib,
  pkgs,
  ...
}:

{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau-va-gl
        nvidia-vaapi-driver
      ];
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = true;
      open = false;
    };
    nvidia-container-toolkit.enable = true;
  };

  services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # Triton (and anything else that JIT-links a `.so` against `-lcuda` at
  # runtime, e.g. torch.compile) invokes `gcc`/`ld` directly. `ld` only
  # consults `LIBRARY_PATH` for `-l` flags — RPATH and `addDriverRunpath`
  # (which is how the *dynamic loader* finds the driver at import time) don't
  # help here. Without this, `torch.cuda.is_available()` and eager CUDA ops
  # work but any Triton kernel fails with `cannot find -l:libcuda.so.1`.
  environment.variables.LIBRARY_PATH = "/run/opengl-driver/lib";
}
