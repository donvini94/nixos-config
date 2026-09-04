#!/usr/bin/env bash
# Mirror the nix-managed OMP layout onto a host home-manager does not manage.
#
# dracula and alucard get ~/.omp/agent wired declaratively by hm-modules/omp.nix. The Mac
# deliberately is not nix-managed, so the same links have to be made by hand — and doing
# that by hand is what let the tree drift: rules added to this repo simply never appeared
# there, and nothing reported it.
#
# Run this after pulling changes to omp/. It is idempotent, it prunes links whose target
# has been deleted or renamed, and it refuses to create the one shape that breaks
# discovery: a symlink to the rules DIRECTORY. OMP enumerates <agent-dir>/rules/*.md with a
# glob, and a glob does not traverse a symlinked directory, so a directory link makes every
# rule silently invisible.
set -euo pipefail

repo="${OMP_REPO:-${HOME}/nixos-config/omp}"
agent="${PI_CODING_AGENT_DIR:-${HOME}/.omp/agent}"

[[ -d $repo ]] || { echo "no such directory: $repo" >&2; exit 1; }
mkdir -p "$agent" "$agent/rules" "$agent/agents"

changed=0

link_file() {
  local src=$1 dest=$2
  if [[ -L $dest ]]; then
    [[ $(readlink "$dest") == "$src" ]] && return 0
  elif [[ -e $dest ]]; then
    echo "  SKIP  $dest exists and is not a symlink — resolve by hand" >&2
    return 0
  fi
  ln -sfn "$src" "$dest"
  echo "  link  ${dest#"$agent"/} -> $src"
  changed=1
}

# A directory symlink here would hide every rule; catch a previous bad fix.
for dir in rules agents; do
  if [[ -L "$agent/$dir" ]]; then
    echo "FATAL: $agent/$dir is a symlink to a directory." >&2
    echo "       OMP's rules glob will not traverse it and every rule goes silently" >&2
    echo "       missing. Remove it and re-run: rm '$agent/$dir'" >&2
    exit 1
  fi
done

echo "context files:"
for f in AGENTS.md RULES.md; do
  [[ -f "$repo/$f" ]] && link_file "$repo/$f" "$agent/$f"
done

for dir in rules agents; do
  echo "$dir:"
  shopt -s nullglob
  for src in "$repo/$dir"/*.md; do
    link_file "$src" "$agent/$dir/$(basename "$src")"
  done
  # Prune links this script previously made whose source is gone.
  for dest in "$agent/$dir"/*.md; do
    [[ -L $dest ]] || continue
    target=$(readlink "$dest")
    case $target in
      "$repo"/*) [[ -e $target ]] || { rm -f "$dest"; echo "  prune ${dest#"$agent"/} (target gone)"; changed=1; } ;;
    esac
  done
  shopt -u nullglob
done

# mcp.json is derived, not authored. hm-modules/omp.nix points the command at a nix store
# path; an unmanaged host has no such path, so resolve the launcher from PATH instead.
echo "mcp.json:"
if launcher=$(command -v uvx 2>/dev/null); then
  tmp=$(mktemp)
  cat >"$tmp" <<JSON
{
  "\$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  "mcpServers": {
    "nixos": {
      "type": "stdio",
      "command": "$launcher",
      "args": ["mcp-nixos"]
    }
  }
}
JSON
  if [[ -L "$agent/mcp.json" ]]; then
    echo "  SKIP  $agent/mcp.json is a symlink — resolve by hand" >&2
    rm -f "$tmp"
  elif cmp -s "$tmp" "$agent/mcp.json"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$agent/mcp.json"
    echo "  write mcp.json (nixos via $launcher)"
    changed=1
  fi
else
  echo "  SKIP  uvx not on PATH; install uv to get the nixos MCP server" >&2
fi

# The universal settings live in omp/config-common.nix, which packages/omp-harness.nix
# merges into the generated overlay on the nix hosts. Render the same attrset to JSON so
# this host reads identical values instead of a hand-typed copy that drifts. OMP's config
# loader accepts .json, so nix -> JSON needs no YAML tooling here.
echo "managed config:"
managed="$agent/nixos-managed.json"
if command -v nix >/dev/null 2>&1; then
  tmp=$(mktemp)
  if nix eval --json --file "$repo/config-common.nix" >"$tmp" 2>/dev/null; then
    if cmp -s "$tmp" "$managed"; then
      rm -f "$tmp"
    else
      mv "$tmp" "$managed"
      echo "  write ${managed#"$agent"/} from config-common.nix"
      changed=1
    fi
  else
    rm -f "$tmp"
    echo "  FAIL  could not evaluate $repo/config-common.nix" >&2
    exit 1
  fi
else
  echo "  SKIP  nix not on PATH; cannot render config-common.nix" >&2
fi

# The rendered file only takes effect if OMP is told to load it. This is the one piece
# that cannot be made self-applying from here, so verify rather than assume.
case ":${PI_CONFIG_FILES-}:" in
  *":$managed:"*) ;;
  *)
    echo "  WARN  PI_CONFIG_FILES does not include $managed" >&2
    echo "        add to ~/.config/fish/config.fish:" >&2
    echo "        set -gx PI_CONFIG_FILES $managed" >&2
    ;;
esac

if (( changed )); then
  echo
  echo "Changed. Restart omp: rules, agents and MCP servers are read at startup."
else
  echo
  echo "Already in sync."
fi
