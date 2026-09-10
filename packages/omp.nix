# Upstream's pinned single-file release binary.
#
# The interpreter is patched into the binary with autoPatchelfHook rather than launched
# through a `ld-linux --library-path … $out/libexec/omp` wrapper. OMP is a Bun standalone
# executable and its own worker host: every worker (mnemopi embeddings, stats activity,
# tiny inference, js eval) re-enters the CLI entrypoint by spawning `Bun.main` with a
# hidden `__omp_worker_*` argv selector. Under a loader wrapper `Bun.main` is the loader's
# argv[0], so every spawn died with "cannot open shared object file" and memory,
# statistics and local inference silently degraded. A patched ELF makes the binary its own
# valid re-entry point; `omp --smoke-test` is upstream's probe for exactly this contract.
{
  fetchurl,
  autoPatchelfHook,
  lib,
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
  dontStrip = true;
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
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
