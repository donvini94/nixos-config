{
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "oh-my-pi";
  version = "18.1.10";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${finalAttrs.version}/omp-linux-x64";
    hash = "sha256-6R1VmO5H4dQJn9hobcn2HJt1Xy6gd9Xxd0q6EHIyH54=";
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
