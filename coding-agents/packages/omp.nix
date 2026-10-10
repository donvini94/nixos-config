# Nix supplies the runtime environment; OMP owns its writable, latest-release installation.
{
  bun,
  lib,
  stdenv,
  writeShellApplication,
}:

writeShellApplication {
  name = "omp";
  runtimeInputs = [ bun ];
  text = ''
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ''}
    if [[ ! -x "$HOME/.bun/bin/omp" ]]; then
      bun install --global @oh-my-pi/pi-coding-agent@latest
    fi
    exec "$HOME/.bun/bin/omp" "$@"
  '';
  meta.mainProgram = "omp";
}
