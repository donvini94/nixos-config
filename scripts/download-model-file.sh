#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: download-model-file DESTINATION SHA256 URL" >&2
  exit 2
fi

destination=$1
expected_sha256=$2
source_url=$3
partial="$destination.partial"

mkdir -p "$(dirname "$destination")"
if [ -f "$destination" ] && printf '%s  %s\n' "$expected_sha256" "$destination" \
  | sha256sum --check --status; then
  exit 0
fi

curl --fail --location --retry 5 --continue-at - --output "$partial" "$source_url"
# A corrupt partial would otherwise be resumed, and rejected, on every later run.
printf '%s  %s\n' "$expected_sha256" "$partial" | sha256sum --check || {
  rm -f "$partial"
  exit 1
}
mv "$partial" "$destination"
