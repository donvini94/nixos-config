{
  lib,
  makeWrapper,
  pulseaudio,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "local-transcription-client";
  version = "0.1.0";

  src = ../local-transcription;
  cargoLock.lockFile = ../local-transcription/Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram $out/bin/local-transcription-client \
      --prefix PATH : ${lib.makeBinPath [ pulseaudio ]}
  '';

  meta = {
    description = "PipeWire capture client for the local Confucius4-R2T2 service";
    license = lib.licenses.mit;
    mainProgram = "local-transcription-client";
    platforms = [ "x86_64-linux" ];
  };
}
