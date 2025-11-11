#!/usr/bin/env bash
set -euo pipefail
if ! command -v xmllint >/dev/null 2>&1; then
  # Don't fail devs without libxml2; rely on CI for strict enforcement
  exit 0
fi
status=0
for f in "$@"; do
  xmllint --noent --noout "$f" || status=1
done
exit $status
