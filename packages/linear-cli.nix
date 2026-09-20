# Not in nixpkgs (checked: nixpkgs' `linear` attribute is the Linear.app Electron client,
# a different package). Upstream ships prebuilt, statically-versioned per-target tarballs
# from `dist-workspace.toml` releases.
#
# This installs the raw `deno compile` standalone binary byte-for-byte: no strip, no ELF
# patching. Deno resolves its own file via /proc/self/exe and reads an embedded bundle
# trailer from it, and both of the usual ways to make a foreign ELF runnable on NixOS
# corrupt that trailer or point /proc/self/exe at the wrong file (verified against this
# exact binary):
#   - patchelf (autoPatchelfHook, or a bare `--set-interpreter`) has to grow the file to
#     fit a `/nix/store/...` interpreter path in place of upstream's 28-byte
#     `/lib64/ld-linux-x86-64.so.2`, which shifts the trailer and produces "Could not
#     find standalone binary section." on every invocation, with or without a strip pass;
#   - stdenv's default strip pass has nothing left to remove (upstream already ships
#     symbol-stripped) so it just truncates the file at the ELF's declared end, dropping
#     the ~70 MiB trailer outright — this is why dontStrip is load-bearing, not cosmetic;
#   - invoking the unpatched binary through the dynamic linker by hand
#     (`ld-linux-x86-64.so.2 --library-path ... ./linear`) leaves the trailer intact but
#     makes ld.so, not `linear`, the kernel's execve target, so /proc/self/exe resolves to
#     the loader instead of the binary.
# The only way to run this unmodified is if `/lib64/ld-linux-x86-64.so.2` — the exact
# path already baked into the binary's own PT_INTERP — genuinely resolves to a working
# loader, so the kernel's normal ELF-interpreter loading kernel-exec's `linear` directly
# with its bytes and self-location untouched. hosts/dracula/services.nix enables nix-ld
# for exactly this: it symlinks that path to a shim, with no wrapper needed at the
# consuming end (hm-modules/packages.nix just callPackages this file directly).
#
# installCheckPhase can't execute the binary here — the build sandbox has no
# `/lib64/ld-linux-x86-64.so.2`, nix-ld or otherwise — so it instead proves fixup left
# the bytes untouched, which is the actual failure mode above (a `nix build` that
# silently ships a truncated binary).
#
# x86_64-linux only for now — that's every host that imports hm-modules/packages.nix
# (dracula). Upstream also ships aarch64-darwin/x86_64-darwin/aarch64-linux tarballs at
# the same URL shape if this ever needs to follow the Mac, where none of the above
# applies (macOS binaries don't go through an ELF interpreter).
{
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "linear-cli";
  # Bumped by .github/workflows/package-update.yml (nix-update), not Renovate: this
  # version is one of two pins, alongside src.hash.
  version = "2.6.0";

  src = fetchurl {
    url = "https://github.com/schpet/linear-cli/releases/download/v${finalAttrs.version}/linear-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-u8udNlMIvDcooeyZE60YgPiMDOaHZzgyl+NIwFfzW40=";
  };

  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 linear "$out/bin/linear"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cmp linear "$out/bin/linear"
    runHook postInstallCheck
  '';

  meta = {
    description = "List, start, and create PRs for Linear issues without leaving the command line";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.isc;
    mainProgram = "linear";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
