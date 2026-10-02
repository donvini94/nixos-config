#!/usr/bin/env bash
# Reject unreviewed package mutations. Match the reviewed declaration, not comment wording.
# Pinned upstream overlays are allowed. This is a text guard, not a Nix parser.
set -euo pipefail

root=${1:-.}
status=0

# path -> one-line justification. Keep this list empty whenever upstream allows.
declare -A EXCEPTIONS=(
  ["hm-modules/packages.nix"]="mattermost-desktop's koffi.node has no runpath to libstdc++"
)

fail() {
  status=1
  printf 'error: %s\n' "$*" >&2
}

mapfile -t nix_files < <(find "$root" -name '*.nix' -type f -not -path '*/.git/*' | sort)
if ((${#nix_files[@]} == 0)); then
  printf 'error: no .nix files found under %s\n' "$root" >&2
  exit 1
fi

reviewed() {
  [[ $1 == hm-modules/packages.nix &&
     $2 == *"mattermost-desktop = pkgs.mattermost-desktop.overrideAttrs (old: {" ]]
}

check() {
  local description=$1 pattern=$2
  local line file rest rel violations=()

  while IFS= read -r line; do
    file=${line%%:*}
    rest=${line#*:}
    rel=${file#"$root"/}
    if [[ -v EXCEPTIONS[$rel] ]] && reviewed "$rel" "${rest#*:}"; then
      continue
    fi
    violations+=("$line")
  done < <(grep -nHE "$pattern" "${nix_files[@]}" || true)

  if ((${#violations[@]})); then
    fail "$description"
    printf '%s\n' "${violations[@]}" >&2
  fi
}

# `[^-...]` keeps identifiers such as `no-package-patches` from matching the
# `patches = ` attribute form.
check 'repository-owned nixpkgs package mutation found; fix it upstream or use supported package arguments' \
  'overrideAttrs|postPatch|applyPatches|(^|[^-[:alnum:]_])patches[[:space:]]*='

# An overlay lambda is `final: prev:` / `self: super:` (underscore-prefixed
# when unused). A pinned input overlay is a bare attribute reference and has
# no lambda here, so it passes.
check 'locally defined nixpkgs overlay lambda found; only named overlays from pinned inputs are allowed' \
  '(_?final|_?self)[[:space:]]*:[[:space:]]*(_?prev|_?super)[[:space:]]*:'

if ((status == 0)); then
  printf 'ok: %d nix files scanned, %d reviewed exception(s)\n' "${#nix_files[@]}" "${#EXCEPTIONS[@]}"
  for rel in "${!EXCEPTIONS[@]}"; do
    printf '  exception: %s — %s\n' "$rel" "${EXCEPTIONS[$rel]}"
  done
fi

exit "$status"
