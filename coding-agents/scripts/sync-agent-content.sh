#!/usr/bin/env bash
set -euo pipefail

root=$1
shift
mkdir -p "$root"

# Each source is name=rev=url. The checkout is moved forward to the pinned rev, never
# past it, so an upstream push reaches activation only through a reviewed pin bump.
for source in "$@"; do
  name=${source%%=*}
  rest=${source#*=}
  rev=${rest%%=*}
  url=${rest#*=}
  dir="$root/$name"
  if [ ! -e "$dir" ]; then
    git clone --quiet "$url" "$dir" || { echo "Cannot clone $name" >&2; continue; }
    git -C "$dir" reset --quiet --hard "$rev" || { echo "Pinned $rev missing from $name" >&2; continue; }
  elif [ ! -d "$dir/.git" ]; then
    echo "Not a Git checkout: $dir" >&2
    continue
  elif [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "Local changes in $dir; leaving it untouched" >&2
    continue
  elif git -C "$dir" merge-base --is-ancestor "$rev" HEAD 2>/dev/null; then
    : # At the pin, or ahead of it with local commits.
  else
    { git -C "$dir" fetch --quiet "$url" "$rev" && git -C "$dir" merge --quiet --ff-only "$rev"; } \
      || { echo "Cannot fast-forward $name to $rev (offline or diverged)" >&2; continue; }
  fi
  if [ -f "$dir/bun.lock" ]; then
    (cd "$dir" && bun install --frozen-lockfile --ignore-scripts --silent) \
      || echo "Cannot install dependencies for $name" >&2
  fi
done
