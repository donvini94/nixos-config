# The config overlay only: the harness binary stays the self-updating bun install here,
# because packages/omp.nix unpacks a linux-x64 tarball and is `platforms = [
# "x86_64-linux" ]`.
{ pkgs, ... }:

let
  managed = (pkgs.formats.yaml { }).generate "omp-managed-config.yml" (
    import ../../omp/config-common.nix
  );
in
{
  home.sessionVariables.PI_CONFIG_FILES = "${managed}";
}
