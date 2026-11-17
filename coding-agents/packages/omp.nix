# Nix supplies the runtime environment; OMP owns its writable, latest-release installation.
{
  bun,
  lib,
  python3,
  stdenv,
  writeShellApplication,
}:

writeShellApplication {
  name = "omp";
  runtimeInputs = [ bun ];
  text = ''
    # Appended, not prepended: a Python already on PATH (e.g. an active venv) wins; this
    # only keeps OMP's Python eval working on accounts without one.
    export PATH="$PATH:${python3}/bin"
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
