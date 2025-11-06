#!/usr/bin/env bash
# Wrapper to run detect-aws-credentials from pre-commit-hooks,
# excluding .feature files and any test folders/files.
set -euo pipefail
IFS=$'\n\t'

PKG="pre-commit-hooks"
VER="${PRE_COMMIT_HOOKS_VERSION:-4.6.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/${PKG}-${VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

# --- ensure venv exists and has pre-commit-hooks installed --------------------
if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PY" -m venv "$VENV_DIR"
  "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install "${PKG}==${VER}"
fi

# --- Exclude patterns ---------------------------------------------------------
# Skip .feature files, and any paths under test folders or named like test_*.*
EXCLUDE_REGEX='(^|.*/)(test|tests|__tests__|src/test)/|(\.feature$)|(^|.*/)?test_.*|_test\.'

FILTERED_FILES=()
for f in "$@"; do
  if [[ ! "$f" =~ $EXCLUDE_REGEX ]]; then
    FILTERED_FILES+=("$f")
  fi
done

# --- Run detect_aws_credentials only on remaining files -----------------------
if [ ${#FILTERED_FILES[@]} -eq 0 ]; then
  echo "[org-detect-aws-credentials] No eligible files to scan (all excluded)." >&2
  exit 0
fi

exec "${VENV_DIR}/bin/python" -m pre_commit_hooks.detect_aws_credentials "${FILTERED_FILES[@]}"
