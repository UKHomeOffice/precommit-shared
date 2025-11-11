#!/usr/bin/env bash
set -euo pipefail
status=0
for f in "$@"; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.sh) if [[ ! -x "$f" ]]; then echo "Script not executable: $f"; status=1; fi ;;
    *.java|*.xhtml|*.xml|*.yml|*.yaml|*.json|*.md|*.properties)
      if [[ -x "$f" ]]; then echo "Source should not be executable: $f"; status=1; fi ;;
  esac
done
exit $status