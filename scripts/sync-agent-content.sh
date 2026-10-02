#!/usr/bin/env bash
set -euo pipefail

root=$1
shift
mkdir -p "$root"

for source in "$@"; do
  name=${source%%=*}
  url=${source#*=}
  dir="$root/$name"
  if [ ! -e "$dir" ]; then
    git clone --quiet "$url" "$dir" || { echo "Cannot clone $name" >&2; continue; }
  elif [ ! -d "$dir/.git" ]; then
    echo "Not a Git checkout: $dir" >&2
    continue
  elif [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "Local changes in $dir; leaving it untouched" >&2
    continue
  else
    branch=$(git -C "$dir" symbolic-ref --short HEAD) || { echo "Detached HEAD in $dir" >&2; continue; }
    git -C "$dir" pull --quiet --ff-only "$url" "$branch" \
      || { echo "Cannot fast-forward $name (offline or diverged)" >&2; continue; }
  fi
  if [ -f "$dir/bun.lock" ]; then
    (cd "$dir" && bun install --frozen-lockfile --silent) \
      || echo "Cannot install dependencies for $name" >&2
  fi
done
