#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'Usage: update-skills {check|apply} [SKILL...]'
  echo 'Refresh vendored skills from ai/skills/sources.json; package versions and client state are untouched.'
}

mode=${1:-check}
if [ "$#" -gt 0 ]; then shift; fi
case "$mode" in
  check|apply) ;;
  -h|--help|help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

repo=${SKILLS_REPO:-$HOME/nixos-config}
manifest="$repo/ai/skills/sources.json"
jq -e '.skills | type == "object"' "$manifest" >/dev/null
if [ "$#" -gt 0 ]; then
  names=("$@")
else
  mapfile -t names < <(jq -r '.skills | keys[]' "$manifest")
fi
for name in "${names[@]}"; do
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "Invalid skill: $name" >&2; exit 2; }
  jq -e --arg name "$name" '.skills | has($name)' "$manifest" >/dev/null \
    || { echo "Unknown vendored skill: $name" >&2; exit 2; }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
changed=()
for name in "${names[@]}"; do
  source=$(jq -c --arg name "$name" '.skills[$name]' "$manifest")
  path=$(jq -r '.path' <<< "$source")
  case "$path" in
    ''|/*|..|../*|*/../*|*/..) echo "Invalid source path: $path" >&2; exit 2 ;;
  esac
  fresh="$tmp/fresh/$name"
  mkdir -p "$fresh"
  case "$(jq -r '.type' <<< "$source")" in
    git)
      url=$(jq -r '.repo' <<< "$source")
      ref=$(jq -r '.ref // empty' <<< "$source")
      attribute=$(jq -r '.packageAttribute // empty' <<< "$source")
      if [ -n "$attribute" ]; then
        system=$(nix eval --impure --raw --expr builtins.currentSystem)
        version=$(nix eval --raw "$repo#packages.$system.$attribute.version")
        ref="v$version"
      fi
      args=()
      if [ -n "$ref" ]; then args=(--branch "$ref"); fi
      git -c advice.detachedHead=false clone --quiet --depth 1 "${args[@]}" "$url" "$tmp/clone-$name"
      rsync -a --exclude .git "$tmp/clone-$name/$path/" "$fresh/"
      ;;
    pypi)
      package=$(jq -r '.package' <<< "$source")
      version=$(jq -r '.version' <<< "$source")
      metadata=$(curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 \
        "https://pypi.org/pypi/$package/$version/json")
      wheel=$(jq -ce '[.urls[] | select(.packagetype == "bdist_wheel")][0] // error("No wheel published")' <<< "$metadata")
      url=$(jq -r '.url' <<< "$wheel")
      hash=$(jq -er '.digests.sha256' <<< "$wheel")
      curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 \
        --output "$tmp/$name.whl" "$url"
      printf '%s  %s\n' "$hash" "$tmp/$name.whl" | sha256sum --check --status
      unzip -q "$tmp/$name.whl" "$path/*" -d "$tmp/wheel-$name"
      rsync -a "$tmp/wheel-$name/$path/" "$fresh/"
      ;;
    *) echo "Unsupported source type for $name" >&2; exit 2 ;;
  esac
  destination="$repo/ai/skills/shared/$name"
  if [ -L "$destination" ]; then
    echo "Refusing to replace a symlink: $destination" >&2
    exit 1
  fi
  if [ ! -d "$destination" ]; then
    changed+=("$name")
    echo "$name: missing"
  elif diff -rq "$fresh/" "$destination/" >/dev/null; then
    echo "$name: current"
  else
    result=$?
    if [ "$result" -ne 1 ]; then exit "$result"; fi
    changed+=("$name")
    echo "$name: differs from declared source"
  fi
done

# Fetch and verify every source before writing to the checkout.
if [ "$mode" = apply ]; then
  for name in "${changed[@]}"; do
    mkdir -p "$repo/ai/skills/shared/$name"
    rsync -a --checksum --delete "$tmp/fresh/$name/" "$repo/ai/skills/shared/$name/"
  done
fi
