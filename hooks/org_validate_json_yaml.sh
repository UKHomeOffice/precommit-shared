#!/usr/bin/env bash
set -euo pipefail
status=0
for f in "$@"; do
  case "$f" in
    *.json)
      python3 - <<'PY' "$f" || status=1
import json, sys
with open(sys.argv[1], 'rb') as fh:
    json.load(fh)
PY
      ;;
    *.yml|*.yaml)
      python3 - <<'PY' "$f" || status=1
import sys
try:
    import yaml  # type: ignore
except Exception:
    print("WARNING: PyYAML not available; skipping strict YAML check.", file=sys.stderr); sys.exit(0)
with open(sys.argv[1], 'rb') as fh:
    yaml.safe_load(fh)
PY
      ;;
  esac
done
exit $status
