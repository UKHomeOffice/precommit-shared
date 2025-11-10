#!/usr/bin/env bash
set -euo pipefail

MSG_FILE="$1"
TEMPLATE="template/commit-template.txt"

# Do not overwrite merge or squash messages
if [[ "$2" == "merge" || "$2" == "squash" ]]; then
  exit 0
fi

# Only apply if the commit message is empty
if [[ ! -s "$MSG_FILE" ]]; then
  cat "$TEMPLATE" > "$MSG_FILE"
fi
