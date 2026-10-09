# Build artifacts in the synced code folders stay per machine: they are large, often
# platform-specific (a macOS .venv is useless on Linux) and every tool regenerates them.
# Syncthing reads .stignore per device, so every host writes the same file.
{ ... }:
let
  devIgnores = ''
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
  home.file = {
    "code/.stignore".text = devIgnores;
    "amiconsult/.stignore".text = devIgnores;
  };
}
