#!/usr/bin/env bash
# Reject repository-owned mutations of nixpkgs packages.
#
# Local patches are invisible maintenance debt: they silently rot against
# upstream, break unrelated rebuilds, and hide the fact that the real fix
# belongs in nixpkgs. Every mutation this repository once carried is now
# either fixed upstream or expressed through supported package arguments.
#
# Allowed:
#   * named overlays coming from a pinned flake input (e.g.
#     `emacs-overlay.overlay`) — reviewed upstream code, not a local diff;
#   * files listed in EXCEPTIONS below, each of which must carry an
#     `# UPSTREAM DEFECT` comment naming the live failure it works around and
#     the condition for removing it. A mutation anywhere else fails, and a
#     reviewed file that loses its justification comment fails too.
set -euo pipefail

root=${1:-.}
status=0

# path -> one-line justification. Keep this list empty whenever upstream allows.
declare -A EXCEPTIONS=(
  [hosts/alucard/security.nix]='nixpkgs pcre2 --enable-jit-sealloc is not fork-safe; stock libmodsecurity segfaults on every nginx worker exit'
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

# Partition `grep -nH` hits into unreviewed violations and reviewed exceptions.
# Runs in the current shell so `fail` can set the exit status.
check() {
  local description=$1 pattern=$2
  local line file rel violations=()

  while IFS= read -r line; do
    file=${line%%:*}
    rel=${file#"$root"/}
    if [[ -v EXCEPTIONS[$rel] ]]; then
      grep -q 'UPSTREAM DEFECT' "$file" ||
        fail "reviewed exception $rel lost its '# UPSTREAM DEFECT' justification"
    else
      violations+=("$line")
    fi
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
