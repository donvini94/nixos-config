{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "llama-swap";
  # renovate: datasource=github-releases depName=mostlygeek/llama-swap
  version = "247";

  src = fetchurl {
    url = "https://github.com/mostlygeek/llama-swap/releases/download/v${finalAttrs.version}/llama-swap_${finalAttrs.version}_linux_amd64.tar.gz";
    hash = "sha256-QAGgaNwd0VRRORmjHMAJ1PVEQm0gQL0C+/M9kCQMF98=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 llama-swap "$out/bin/llama-swap"
    runHook postInstall
  '';

  meta = {
    description = "Model swapping proxy for OpenAI-compatible inference servers";
    homepage = "https://github.com/mostlygeek/llama-swap";
    license = lib.licenses.mit;
    mainProgram = "llama-swap";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
