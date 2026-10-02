#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
agent-update - keep skills, plugins and pins for Pi and OMP current on every host

  agent-update check [AREA...]    report what is out of date; changes nothing
  agent-update apply [AREA...]    refresh files in the repo (and upgrade local plugins)

AREA: skills   vendored skills in skills/shared (see skills/sources.json)
      plugins  OMP marketplace plugins on this machine
      pins     Pi binary, HazAT subagents, Amos extensions
      omp      the OMP release pinned in packages/omp.nix
No AREA means all of them.

Review changes, commit, and rebuild each intended host explicitly.
EOF
}

repo="${AGENT_UPDATE_REPO:-$HOME/nixos-config}"
pi_nix="$repo/hm-modules/pi.nix"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

note() { printf '%s\n' "$*"; }
warn() { printf 'agent-update: %s\n' "$*" >&2; }

api() {
  local auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then auth=(-H "Authorization: Bearer $GITHUB_TOKEN"); fi
  curl -fsSL "${auth[@]}" "https://api.github.com/$1"
}

# nix_value FILE KEY - the first `KEY = "value";` in a nix file.
nix_value() { sed -n "s/^ *$2 = \"\\(.*\\)\";.*/\\1/p" "$1" | head -n 1; }

# set_nix_value FILE KEY VALUE - rewrite that first assignment in place.
set_nix_value() { sed -i "0,/^\\( *$2 = \"\\)[^\"]*\";/s||\\1$3\";|" "$1"; }

# set_nix_hash FILE PATTERN HASH - rewrite the hash on the line that mentions PATTERN.
set_nix_hash() { sed -i "\\|$2|s|sha256-[A-Za-z0-9+/=]*|$3|" "$1"; }

prefetch_hash() { nix store prefetch-file --json "$1" | jq -r .hash; }

report() { # report NAME CURRENT LATEST
  if [ "$2" = "$3" ]; then note "  ok       $1 $2"; else note "  update   $1 $2 -> $3"; fi
}

# ---- skills ----------------------------------------------------------------------------------

skill_source_ref() { # NAME -> git ref, empty for the default branch
  local ref
  ref="$(jq -r --arg n "$1" '.skills[$n].ref // ""' "$repo/skills/sources.json")"
  case "$ref" in
    nix:*) printf 'v%s' "$(nix_value "$repo/${ref#nix:}" version)" ;;
    *) printf '%s' "$ref" ;;
  esac
}

fetch_git_skill() { # NAME DEST - clone the upstream folder into DEST
  local name="$1" dest="$2" url path ref clone
  url="$(jq -r --arg n "$name" '.skills[$n].repo' "$repo/skills/sources.json")"
  path="$(jq -r --arg n "$name" '.skills[$n].path' "$repo/skills/sources.json")"
  ref="$(skill_source_ref "$name")"
  clone="$tmp/clone-$name"
  git -c advice.detachedHead=false clone --quiet --depth 1 ${ref:+--branch "$ref"} "$url" "$clone"
  mkdir -p "$dest"
  rsync -a --delete --exclude .git "$clone/$path/" "$dest/"
}

pypi_latest() { curl -fsSL "https://pypi.org/pypi/$1/json" | jq -r .info.version; }

fetch_pypi_skill() { # NAME DEST VERSION - extract the skill folder from the wheel
  local name="$1" dest="$2" version="$3" package path url
  package="$(jq -r --arg n "$name" '.skills[$n].package' "$repo/skills/sources.json")"
  path="$(jq -r --arg n "$name" '.skills[$n].path' "$repo/skills/sources.json")"
  url="$(curl -fsSL "https://pypi.org/pypi/$package/$version/json" \
    | jq -r '[.urls[] | select(.packagetype == "bdist_wheel")][0].url')"
  curl -fsSL -o "$tmp/$name.whl" "$url"
  unzip -q -o "$tmp/$name.whl" "$path/*" -d "$tmp/wheel-$name"
  mkdir -p "$dest"
  rsync -a --delete "$tmp/wheel-$name/$path/" "$dest/"
}

skills() { # MODE
  local mode="$1" name type pin latest current fresh
  note "skills"
  for name in $(jq -r '.skills | keys[]' "$repo/skills/sources.json"); do
    type="$(jq -r --arg n "$name" '.skills[$n].type' "$repo/skills/sources.json")"
    fresh="$tmp/fresh-$name"
    case "$type" in
      git) fetch_git_skill "$name" "$fresh" ;;
      pypi)
        pin="$repo/$(jq -r --arg n "$name" '.skills[$n].pin' "$repo/skills/sources.json")"
        current="$(nix_value "$pin" version)"
        latest="$(pypi_latest "$(jq -r --arg n "$name" '.skills[$n].package' "$repo/skills/sources.json")")"
        report "$name (package)" "$current" "$latest"
        fetch_pypi_skill "$name" "$fresh" "$latest"
        ;;
      *) warn "unknown source type '$type' for $name"; continue ;;
    esac
    if diff -rq "$fresh" "$repo/skills/shared/$name" >/dev/null; then
      note "  ok       $name"
    else
      note "  update   $name differs from upstream"
      if [ "$mode" = apply ]; then
        rsync -a --delete "$fresh/" "$repo/skills/shared/$name/"
        if [ "$type" = pypi ]; then set_nix_value "$pin" version "$latest"; fi
      fi
    fi
  done
}

# ---- plugins ---------------------------------------------------------------------------------

plugins() { # MODE
  local mode="$1"
  note "plugins"
  if ! command -v omp >/dev/null 2>&1; then
    note "  skipped  omp is not installed here"
    return
  fi
  if [ "$mode" = apply ]; then
    omp plugin upgrade omp-learn-org@omp-learn || warn "upgrading omp-learn-org failed"
  else
    omp plugin list || warn "listing plugins failed"
    note "  (marketplace plugins also update themselves on startup; apply upgrades now)"
  fi
}

# ---- pins ------------------------------------------------------------------------------------

pins() { # MODE
  local mode="$1" current latest old new file hash
  note "pins"

  current="$(nix_value "$pi_nix" piVersion)"
  latest="$(npm view @earendil-works/pi-coding-agent version)"
  report "pi" "$current" "$latest"
  if [ "$mode" = apply ] && [ "$current" != "$latest" ]; then set_nix_value "$pi_nix" piVersion "$latest"; fi

  old="$(grep -o 'HazAT/pi-interactive-subagents@[0-9a-f]\{40\}' "$pi_nix" | head -n 1 | cut -d@ -f2)"
  latest="$(api repos/HazAT/pi-interactive-subagents/tags | jq -r '.[0].commit.sha')"
  report "pi-interactive-subagents" "${old:0:8}" "${latest:0:8}"
  if [ "$mode" = apply ] && [ "$old" != "$latest" ]; then
    sed -i "s/$old/$latest/g" "$pi_nix"
  fi

  old="$(nix_value "$pi_nix" upstreamRevision)"
  new="$(api repos/amosblomqvist/pi-config/commits/main | jq -r .sha)"
  report "amosblomqvist/pi-config" "${old:0:8}" "${new:0:8}"
  if [ "$mode" = apply ] && [ "$old" != "$new" ]; then
    for file in extensions/ask-user-question.ts extensions/web-fetch/index.ts \
      extensions/web-fetch/package.json extensions/web-fetch/package-lock.json; do
      hash="$(prefetch_hash "https://raw.githubusercontent.com/amosblomqvist/pi-config/$new/$file")"
      set_nix_hash "$pi_nix" "\"$file\"" "$hash"
    done
    set_nix_value "$pi_nix" upstreamRevision "$new"
  fi
}

# ---- omp -------------------------------------------------------------------------------------

omp_release() { # MODE
  local mode="$1" current latest hash
  note "omp"
  current="$(nix_value "$repo/packages/omp.nix" version)"
  latest="$(api repos/can1357/oh-my-pi/releases/latest | jq -r .tag_name | sed 's/^v//')"
  report "omp (pinned for dracula and alucard)" "$current" "$latest"
  if [ "$mode" = apply ] && [ "$current" != "$latest" ]; then
    hash="$(prefetch_hash "https://github.com/can1357/oh-my-pi/releases/download/v$latest/omp-linux-x64")"
    set_nix_value "$repo/packages/omp.nix" version "$latest"
    set_nix_hash "$repo/packages/omp.nix" 'hash = ' "$hash"
  fi
}

# ---- main ------------------------------------------------------------------------------------

areas() { # AREA... -> the areas to run, all by default
  if [ "$#" -eq 0 ]; then printf '%s\n' skills plugins pins omp; else printf '%s\n' "$@"; fi
}

run_areas() { # MODE AREA...
  local mode="$1" area
  shift
  for area in $(areas "$@"); do
    case "$area" in
      skills) skills "$mode" ;;
      plugins) plugins "$mode" ;;
      pins) pins "$mode" ;;
      omp) omp_release "$mode" ;;
      *) warn "unknown area '$area'"; usage; exit 2 ;;
    esac
  done
}

command="${1:-check}"
if [ "$#" -gt 0 ]; then shift; fi
case "$command" in
  check) run_areas check "$@" ;;
  apply) run_areas apply "$@" ;;
  -h | --help | help) usage ;;
  *) usage; exit 2 ;;
esac
