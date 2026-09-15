# A CUDA-enabled `torch` sourced from PyPI's official prebuilt wheel
# (`torch-bin`) instead of nixpkgs' from-source `torch`, which avoids
# compiling torch/magma/opencv/openvino from source (the packages that made
# a global `cudaSupport = true` unworkable — see hosts/dracula/default.nix).
# Confirmed via `nix derivation show`: torch/torchvision/triton/cuda-bindings
# unpack a prebuilt wheel (`dist` input, no compiler), and most cudaPackages
# components (cudnn, cublas, cufft, curand, cusolver, cusparse, cupti, nvrtc,
# nvtx, nvml, cufile, the cuda_nvcc toolchain itself) unpack NVIDIA's own CDN
# archives via a `stdenv-linux-no-cc` (no compiler) input.
#
# Two exceptions, both real from-source compiles because nixpkgs has no
# prebuilt/wheel alternative for them: `nccl` and `libnvshmem`. Both are
# open source (unlike cudnn/cublas/etc., which are NVIDIA-proprietary
# binaries nixpkgs only ever unpacks) and are pulled in unconditionally by
# torch-bin's own `buildInputs` (autoPatchelf needs them to resolve torch's
# shared libraries' DT_NEEDED entries, even though this is a single-GPU
# deployment that never exercises NCCL's multi-GPU collectives).
# `cudaCapabilities` below constrains both to this host's one GPU
# architecture instead of nixpkgs' default ~8-architecture list, which cut a
# real build (confirmed by timing an actual `nixos-rebuild build`) from
# compiling for sm_75 through sm_121 down to sm_86 only — the difference
# between an unbounded multi-hour build and a single ~15-20 minute one on top
# of an otherwise all-cache/all-wheel closure.
#
# Deliberately a *second*, independent `import <nixpkgs> { ... }` rather than
# a host-wide `nixpkgs.overlays` entry: the latter would rewrite `cudaPackages`
# and the default Python interpreter for every consumer on the host (Emacs'
# Python, modules/programming.nix, anything else touching
# `pkgs.python3Packages`), forcing exactly the kind of unrelated rebuild
# cascade this exists to avoid. Callers get back their own scoped `pkgs` and a
# `pythonFor` helper instead.
#
# cache.nixos-cuda.org is NOT used here even though it answers for some of
# these hashes: per the CUDA team itself (NixOS/nixpkgs#561684, comment from
# @GaetanLepage, 2026-09-11), that cache is "not for public consumption ...
# meant for the team's internal development activities" — it hasn't been
# cleared to redistribute patched NVIDIA binaries. cuda-maintainers.cachix.org
# is confirmed deprecated in the same thread. cache.flox.dev is a real,
# publicly-authorized redistributor, but a narinfo check against its cache
# shows it does not carry this nixpkgs revision's hashes (different glibc/gcc/
# python — it's built from Flox's own nixpkgs fork, not this flake's pin), so
# it cannot substitute into this closure either. Neither would eliminate the
# nccl/libnvshmem compiles regardless: those come from torch-bin's own
# `buildInputs`, not from which torch build supplies the wheel.
{
  nixpkgsFlake,
  system,
  cudaCapabilities ? [ "8.6" ], # RTX 3090 (Dracula)
}:
let
  pkgs = import nixpkgsFlake {
    inherit system;
    config = {
      allowUnfree = true;
      # nixpkgs' cudaPackages defaults to a broad multi-GPU-generation gencode
      # list for anything it compiles itself (notably `nccl`, which — unlike
      # cudnn/cublas/etc. — is open source and has no prebuilt nixpkgs
      # package, so it *is* compiled here). Without this, that one compile
      # targets sm_75 through sm_121 instead of just this host's GPU.
      inherit cudaCapabilities;
    };
    overlays = [
      (_final: prev: {
        # torch-bin's wheel is built against CUDA >=13.0; this nixpkgs
        # revision's default cudaPackages is still 12.9.
        cudaPackages = prev.cudaPackages_13;
      })
    ];
  };

  # `pythonPackages` is the *original* (pre-override) package set passed to
  # `python3.override { packageOverrides }`, so this must not read back
  # through the new fixpoint for anything other than itself.
  cudaTorch =
    pythonPackages:
    pythonPackages.torch-bin.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        cudaSupport = true;
        inherit cudaCapabilities;
        stdenv = pkgs.cudaPackages.cudaStdenv or pkgs.stdenv;
      };
    });
in
{
  inherit pkgs cudaTorch;

  # `pythonAttr` is e.g. "python313" or "python314". Returns that interpreter
  # with `torch` swapped for the CUDA wheel everywhere within its own package
  # set (so anything depending on `torch` inside that scope, like
  # `exllamav3`, resolves the CUDA-enabled one automatically). `torchvision`/
  # `torchaudio` are redirected to their own `-bin` wheel builds too — the
  # from-source `torchvision` needs `torch.cxxdev`, a dev-output split that
  # only the from-source `torch` has, and would otherwise drag in a real
  # C++/CUDA compile the moment anything (e.g. `accelerate`'s build inputs)
  # pulls it in transitively.
  pythonFor =
    pythonAttr:
    pkgs.${pythonAttr}.override {
      packageOverrides = _pyFinal: pyPrev: {
        torch = cudaTorch pyPrev;
        torchvision = pyPrev.torchvision-bin;
        torchaudio = pyPrev.torchaudio-bin;
      };
    };
}
