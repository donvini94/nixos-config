{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wirken";
  version = "1.13.0";

  src = fetchurl {
    url = "https://github.com/gebruder/wirken/releases/download/v${finalAttrs.version}/wirken-x86_64-unknown-linux-musl";
    hash = "sha256-PyXR4jn8Uk+bPimkwTjij1ecDA+ngek6RlUvtWm2QUE=";
  };

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/wirken"
    runHook postInstall
  '';

  meta = {
    description = "Secure personal AI agent gateway";
    homepage = "https://github.com/gebruder/wirken";
    license = lib.licenses.mit;
    mainProgram = "wirken";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
