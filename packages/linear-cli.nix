# Deno's standalone bundle is appended to the executable: stripping or patchelf
# corrupts it. Linux needs nix-ld; keep the installed bytes unchanged.
{
  fetchurl,
  lib,
  stdenv,
}:

let
  source =
    {
      x86_64-linux = {
        target = "x86_64-unknown-linux-gnu";
        hash = "sha256-u8udNlMIvDcooeyZE60YgPiMDOaHZzgyl+NIwFfzW40=";
      };
      aarch64-darwin = {
        target = "aarch64-apple-darwin";
        hash = "sha256-uavdS1rsFEWeQ0oomSA3V96K6EfwVerk8frue7H7wHg=";
      };
    }
    .${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "linear-cli";
  version = "2.6.0";
  src = fetchurl {
    url = "https://github.com/schpet/linear-cli/releases/download/v${finalAttrs.version}/linear-${source.target}.tar.xz";
    inherit (source) hash;
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
    description = "Linear issue tracker CLI";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.isc;
    mainProgram = "linear";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
