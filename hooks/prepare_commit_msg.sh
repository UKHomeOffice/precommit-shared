#!/usr/bin/env bash
# prepare_commit_msg.sh — injects a commit template only when Git's commit.template isn't set.
# Compatible with macOS bash 3.2+.
set -euo pipefail

MSG_FILE="$1"
KIND="${2:-}"          # "merge" | "squash" | "" (normal)

# 1) Skip merge/squash (git provides its own message)
if [[ "$KIND" == "merge" || "$KIND" == "squash" ]]; then
  exit 0
fi

# 2) If git commit.template is configured, let Git/IDE handle it (works in IntelliJ)
if git config --get commit.template >/dev/null 2>&1; then
  exit 0
fi

# 3) Only act if the message is empty/whitespace
if [[ -s "$MSG_FILE" && -n "$(tr -d ' \t\r\n' < "$MSG_FILE")" ]]; then
  exit 0
fi

# 4) Resolve repo root and candidate template locations
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CANDIDATES=(
  "$ROOT/templates/commit-template.txt"  # tracked (recommended)
  "$ROOT/template/commit-template.txt"   # your current path, kept as fallback
  "$ROOT/.git/commit-template.txt"       # legacy fallback
)

# 5) Insert the first existing template, if any
for TPL in "${CANDIDATES[@]}"; do
  if [[ -f "$TPL" ]]; then
    {
      cat "$TPL"
      echo
      echo "# Fill fields; lines starting with # are ignored."
    } > "$MSG_FILE"
    exit 0
  fi
done

# No template found → do nothing (don’t block commit)
exit 0
