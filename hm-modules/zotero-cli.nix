{
  lib,
  pkgs,
  ...
}:

# `zotero-cli` (shipped by the zotero-mcp-server package) reaches the local Zotero library, so it
# belongs only on hosts that run the Zotero desktop app. The skill that teaches agents to use it
# is vendored in skills/shared/zotero-cli and reaches every host through agent-skills.nix.
#
# The package is a `uv tool`, not a nix package, so the pinned version is installed idempotently.
#
# Per-host step Home Manager cannot do: approve the CLI once in the Zotero app with
# `zotero-mcp authorize-local`. The granted key is stored in ~/.config/zotero-mcp and is never copied
# between hosts.
let
  version = (builtins.fromJSON (builtins.readFile ../skills/sources.json)).skills.zotero-cli.version;
in
{
  home.activation.zoteroCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.uv
        pkgs.gnused
        pkgs.coreutils
      ]
    }:$HOME/.local/bin:$PATH
    if [ -z "''${DRY_RUN:-}" ]; then
      current="$(uv tool list 2>/dev/null | sed -n 's/^zotero-mcp-server v//p')"
      if [ "$current" != "${version}" ]; then
        uv tool install --force "zotero-mcp-server==${version}" \
          || echo "zoteroCli: installing zotero-mcp-server ${version} failed (offline?)" >&2
      fi
    fi
  '';
}
