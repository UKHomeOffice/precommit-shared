#!/usr/bin/env bash
# Prints comma-separated Gradle project paths (e.g., :apps:admin) that changed vs BASE.
set -euo pipefail
BASE="${BASE_REF:-origin/main}"
git rev-parse --verify --quiet "$BASE" >/dev/null || BASE="$(git rev-list --max-parents=0 HEAD | tail -n1)"
CHANGED="$(git diff --name-only "$BASE"...HEAD || true)"
[ -z "$CHANGED" ] && exit 0

declare -A P=()
for f in $CHANGED; do
  d="$f"
  while [ "$d" != "." ] && [ "$d" != "/" ]; do
    dir="${d%/*}"; [ -z "$dir" ] && dir="."
    if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ]; then
      P[":${dir//\//:}"]=1; break
    fi
    d="$dir"
  done
done

[ ${#P[@]} -eq 0 ] && exit 0
printf "%s" "$(printf "%s," "${!P[@]}" | sed 's/,$//')"