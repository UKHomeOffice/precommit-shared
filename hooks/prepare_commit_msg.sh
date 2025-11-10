#!/usr/bin/env bash
set -euo pipefail

MSG_FILE="$1"
KIND="${2:-}"         # "merge" | "squash" | "" (normal)
TEMPLATE=".git/commit-template.txt"

# Skip merge/squash messages
if [[ "$KIND" == "merge" || "$KIND" == "squash" ]]; then
  exit 0
fi

# If git commit.template is set, let Git/IDEA handle it
if git config --get commit.template >/dev/null 2>&1; then
  exit 0
fi

# Only apply if the message is empty/whitespace
if [[ ! -s "$MSG_FILE" || -z "$(tr -d ' \t\r\n' < "$MSG_FILE")" ]]; then
  [[ -f "$TEMPLATE" ]] && {
    { cat "$TEMPLATE"; echo; echo "# Fill fields; lines starting with # are ignored."; } > "$MSG_FILE"
  }
fi
