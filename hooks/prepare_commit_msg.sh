#!/usr/bin/env bash
# Injects the org commit template from the SHARED HOOK REPO.
# Does NOT use git's commit.template and does NOT require a template in consumer repos.
# macOS-safe (no readlink -f), bash 3.2+ compatible.
set -euo pipefail

MSG_FILE="$1"
KIND="${2:-}"    # "merge" | "squash" | "" (normal)

# 1) Skip merge/squash (git writes its own message)
if [[ "$KIND" == "merge" || "$KIND" == "squash" ]]; then
  exit 0
fi

# 2) Only inject if message is empty/whitespace
if [[ -s "$MSG_FILE" && -n "$(tr -d ' \t\r\n' < "$MSG_FILE")" ]]; then
  exit 0
fi

# 3) Resolve the real path of THIS script (follow symlinks in pre-commit cache)
SCRIPT="$0"
while [ -L "$SCRIPT" ]; do
  LINK="$(readlink "$SCRIPT")"
  case "$LINK" in
    /*) SCRIPT="$LINK" ;;
    *)  SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$LINK" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"

# 4) Template is shipped with the shared repo (relative to this script)
# Repo layout (shared):
#   templates/commit-template.txt
#   hooks/prepare_commit_msg.sh   <-- this file
TPL="${SCRIPT_DIR%/hooks}/templates/commit-template.txt"

# 5) Inject if template exists; otherwise do nothing (never block commits)
if [[ -f "$TPL" ]]; then
  {
    cat "$TPL"
    echo
    echo "# Fill fields; lines starting with # are ignored."
  } > "$MSG_FILE"
fi

exit 0
