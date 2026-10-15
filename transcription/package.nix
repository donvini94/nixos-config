{
  lib,
  stdenv,
  python313,
  fetchFromGitHub,
  fetchurl,
  autoPatchelfHook,
  autoAddDriverRunpath,
  cudaPackages_12,
  ffmpeg,
  pulseaudio,
}:
let
  # Use the CUDA-enabled wheel only for Whisper; keep the cached CPU PyTorch stack.
  python = python313.override {
    packageOverrides = final: prev: {
      ctranslate2 =
        if stdenv.hostPlatform.isx86_64 then
          final.buildPythonPackage {
            pname = "ctranslate2";
            version = "4.8.2";
            format = "wheel";
            src = fetchurl {
              url = "https://files.pythonhosted.org/packages/89/8b/051962470b8e9df1a43f0c9c7a03ce1c8a279db76be4e6a6fcb5171d1d29/ctranslate2-4.8.2-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
              hash = "sha256-Yz8Z0f+NBTqLF5ynQrJCACrHiCoqtE4xnG783ifVhqQ=";
            };
            nativeBuildInputs = [
              autoPatchelfHook
              autoAddDriverRunpath
            ];
            buildInputs = [ stdenv.cc.cc.lib ];
            # runtimeDependencies only affects executables, but CTranslate2 dlopens from a .so.
            appendRunpaths = map (p: "${lib.getLib p}/lib") [
              cudaPackages_12.libcublas
              cudaPackages_12.cudnn
            ];
            dependencies = [
              final.numpy
              final.pyyaml
              final.setuptools
            ];
            pythonImportsCheck = [ "ctranslate2" ];
            dontStrip = true;
          }
        else
          prev.ctranslate2;
    };
  };
  dependencies = with python.pkgs; [
    faster-whisper
    av
    pydantic-settings
    click
    dbus-next
    pyannote-audio
  ];
in
python.pkgs.buildPythonApplication (finalAttrs: {
  pname = "tapeback";
  version = "0.9.10";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "yastcher";
    repo = "tapeback";
    rev = "820911e3b17221e8c76a2bd8e7b37b449ab14ec1";
    hash = "sha256-daq4aIDhrwxQ6OOs1PsbmH1146unyBLRLV1CCA4+OSU=";
  };
  patches = [ ./cpu-diarization.patch ];
  # Tapeback hardcodes the older pipeline; community-1 matches pyannote 4.
  postPatch = ''
    substituteInPlace src/tapeback/const.py \
      --replace-fail 'pyannote/speaker-diarization-3.1' 'pyannote/speaker-diarization-community-1'
  '';
  build-system = [ python.pkgs.hatchling ];
  # nixpkgs faster-whisper already patches the removed av.open(metadata_errors=...).
  pythonRelaxDeps = [ "av" ];
  inherit dependencies;

  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        ffmpeg
        pulseaudio
      ]
    }"
  ];
  pythonImportsCheck = [
    "tapeback.cli"
    "tapeback.tray"
    "faster_whisper"
    "pyannote.audio"
  ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export HF_HUB_OFFLINE=1 PYANNOTE_METRICS_ENABLED=0
    export PYTHONPATH="$out/${python.sitePackages}:$PYTHONPATH"
    ${python.interpreter} ${./test-package.py}
    "$out/bin/tapeback" --help >/dev/null
    "$out/bin/tapeback" status
    runHook postInstallCheck
  '';

  passthru.pythonEnv = python.withPackages (_: [
    (python.pkgs.toPythonModule finalAttrs.finalPackage)
  ]);

  meta = {
    description = "Local meeting recorder with Whisper transcription and speaker diarization";
    homepage = "https://github.com/yastcher/tapeback";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "tapeback";
  };
})
