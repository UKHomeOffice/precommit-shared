#!/usr/bin/env bash
set -euo pipefail
status=0
for f in "$@"; do
  [[ -f "$f" ]] || continue
  if LC_ALL=C grep -Iq . "$f"; then
    : # looks texty
  else
    echo "Binary file detected: $f"
    status=1
  fi
done
exit $status
