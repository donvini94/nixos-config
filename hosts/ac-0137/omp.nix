# OMP's managed configuration overlay on this host.
#
# This replaces the `managed config` and `.env` half of the retired
# scripts/omp-link-unmanaged.sh. The other half — the file-by-file rules/ and agents/
# links, AGENTS.md, RULES.md and the derived mcp.json — is hm-modules/omp.nix, which
# ./home.nix imports; that module is what the script was imitating.
#
# The harness BINARY stays the self-updating bun install on this host. packages/omp.nix
# is `platforms = [ "x86_64-linux" ]` (it unpacks a linux-x64 tarball), and
# omp/config-common.nix documents `startup.checkUpdate` as deliberately host-specific for
# exactly this reason: nix owns the binary on dracula and alucard, `omp update` owns it
# here. So only the config overlay is declared, not a wrapper.
#
# YAML rather than the JSON the script wrote: OMP's loader takes either, and this way the
# rendering matches packages/omp-harness.nix instead of being a second format to reason
# about.
{ pkgs, ... }:

let
  managed = (pkgs.formats.yaml { }).generate "omp-managed-config.yml" (
    import ../../omp/config-common.nix
  );
in
{
  home.sessionVariables.PI_CONFIG_FILES = "${managed}";
}
