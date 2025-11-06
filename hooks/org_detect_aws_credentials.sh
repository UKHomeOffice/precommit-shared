#!/usr/bin/env bash
# Wrapper to run detect-aws-credentials from pre-commit-hooks,
# excluding test files, SQL, properties, feature files, migrations, etc.
set -euo pipefail
IFS=$'\n\t'

PKG="pre-commit-hooks"
VER="${PRE_COMMIT_HOOKS_VERSION:-4.6.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/${PKG}-${VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

# --- Ensure venv and install pre-commit-hooks if missing ---------------------
if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PY" -m venv "$VENV_DIR"
  "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install "${PKG}==${VER}"
fi

# --- Global exclude regex ----------------------------------------------------
# Skips .feature, .properties, .sql, .properties.md, test dirs, migration dirs, and node_modules.
EXCLUDE_REGEX='(^|.*/)(test|tests|__tests__|src/test|cwfa-functional-test|node_modules|db/migration)/|(\.feature$)|(\.sql$)|(\.properties$)|(\.properties\.md$)|(^|.*/)?test_.*|_test\.'

FILTERED_FILES=()
for f in "$@"; do
  if [[ ! "$f" =~ $EXCLUDE_REGEX ]]; then
    FILTERED_FILES+=("$f")
  fi
done

if [ ${#FILTERED_FILES[@]} -eq 0 ]; then
  echo "[org-detect-aws-credentials] No eligible files to scan (all excluded)." >&2
  exit 0
fi

exec "${VENV_DIR}/bin/python" -m pre_commit_hooks.detect_aws_credentials "${FILTERED_FILES[@]}"
