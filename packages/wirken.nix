{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wirken";
  version = "1.17.0";

  src = fetchurl {
    url = "https://github.com/gebruder/wirken/releases/download/v${finalAttrs.version}/wirken-x86_64-unknown-linux-musl";
    hash = "sha256-AJrLPzUzARMWaCa8TiS+TwG/uxi/mpdewQgh8VlXKfI=";
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
