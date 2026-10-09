# Build artifacts in the synced code folders stay per machine: they are large, often
# platform-specific (a macOS .venv is useless on Linux) and every tool regenerates them.
# Syncthing reads .stignore per device, so every host writes the same file. A regular file,
# not a home.file symlink: Syncthing on macOS refuses to open a symlinked .stignore (ELOOP).
{ lib, pkgs, ... }:
let
  devIgnores = pkgs.writeText "stignore-dev" ''
    (?d).venv
    (?d)venv
    (?d)node_modules
    (?d)__pycache__
    (?d).pytest_cache
    (?d).ruff_cache
    (?d).mypy_cache
    (?d).direnv
    (?d)target
    (?d)result
    (?d)result-*
    (?d).DS_Store
  '';
in
{
  home.activation.syncthingDevIgnores = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for folder in code amiconsult; do
      if [ -d "$HOME/$folder" ]; then
        run rm -f "$HOME/$folder/.stignore"
        run install -m 0644 ${devIgnores} "$HOME/$folder/.stignore"
      fi
    done
  '';
}
