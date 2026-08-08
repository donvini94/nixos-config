{
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "17.2.11";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
    hash = "sha256-uGTV7FkTN2G5Wzh60oN3pU2lRZtaqn5aNOgrBZU1C6M=";
  };

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/libexec/omp"
    makeWrapper ${stdenv.cc.bintools.dynamicLinker} "$out/bin/omp" \
      --add-flags "--library-path ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      --add-flags "$out/libexec/omp"
    runHook postInstall
  '';

  meta = {
    description = "Terminal coding agent with hash-anchored edits and tool integrations";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
