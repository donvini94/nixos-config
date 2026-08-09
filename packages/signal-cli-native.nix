{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
  zlib,
}:

stdenvNoCC.mkDerivation {
  pname = "signal-cli-native";
  version = "0.14.7";

  src = fetchurl {
    url = "https://github.com/AsamK/signal-cli/releases/download/v0.14.7/signal-cli-0.14.7-Linux-native.tar.gz";
    hash = "sha256-D+BlKUrc8130wkm2NdDOV953ZdT+xmC/+qLn8FSdTl8=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ zlib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 signal-cli "$out/bin/signal-cli"
    runHook postInstall
  '';

  meta = {
    description = "Unofficial Signal command-line client, official native release";
    homepage = "https://github.com/AsamK/signal-cli";
    license = lib.licenses.gpl3Only;
    mainProgram = "signal-cli";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
