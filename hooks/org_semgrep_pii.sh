#!/usr/bin/env bash
# Runs semgrep with org PII rules, filtering out noisy paths/types first.
set -euo pipefail
IFS=$'\n\t'

SG_VER="${SEMGREP_VERSION:-1.92.0}"   # pin a known-good
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/semgrep-${SG_VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

# Where to load rules from (raw URL or file path). Default to this repo's rules/.
RULES_URL="${ORG_SEMGREP_RULES_URL:-}"
if [ -z "$RULES_URL" ]; then
  # Resolve to the checked-out repo's rules/pii.yml when running via pre-commit
  # (pre-commit clones the shared repo; entry path is relative to repo root)
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RULES_URL="${SCRIPT_DIR%/hooks}/rules/pii.yml"
fi

# Create venv if needed
if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PY" -m venv "$VENV_DIR"
  "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install "semgrep==${SG_VER}"
fi

# Centralized exclude (paths + extensions)
# - tests, node_modules, migrations, functional tests
# - SQL, .properties, .properties.md, .feature
EXCLUDE_RE='(^|.*/)(test|tests|__tests__|src/test|node_modules|db/migration|cwfa-functional-test)/|(\.sql$)|(\.properties$)|(\.properties\.md$)|(\.feature$)'

# Filter filenames passed by pre-commit
FILES=()
for f in "$@"; do
  [[ -e "$f" ]] || continue
  if [[ ! "$f" =~ $EXCLUDE_RE ]]; then
    FILES+=("$f")
  fi
done

# If nothing remains, exit success quickly
if [ ${#FILES[@]} -eq 0 ]; then
  echo "[org-semgrep-pii] No eligible files to scan (all excluded)." >&2
  exit 0
fi

# Run semgrep (error on findings >= WARNING when --error used)
# Use --config pointing to our rules file path/URL
exec "${VENV_DIR}/bin/semgrep" \
  --config "$RULES_URL" \
  --error \
  --skip-unknown-extensions \
  --json \
  "${FILES[@]}"
