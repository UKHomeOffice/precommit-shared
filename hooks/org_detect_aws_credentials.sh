#!/usr/bin/env bash
# Wrapper to run detect-aws-credentials from pre-commit-hooks with centralized exclusions.
set -euo pipefail

PKG="pre-commit-hooks"
VER="${PRE_COMMIT_HOOKS_VERSION:-4.6.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/${PKG}-${VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

# --- venv bootstrap ----------------------------------------------------------
if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PY" -m venv "$VENV_DIR"
  # ensure pip exists (some distributions build venvs without it)
  "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  "${VENV_DIR}/bin/python" -m pip install "${PKG}==${VER}"
fi

# --- global exclusions -------------------------------------------------------
# skip .feature files, test folders, and test-related filenames
GLOBAL_EXCLUDE='(^|.*/)(test|tests|__tests__|src/test)/|(\.feature$)|(^|.*/)?test_.*|_test\.'

# --- execute hook ------------------------------------------------------------
exec "${VENV_DIR}/bin/python" -m pre_commit_hooks.detect_aws_credentials \
  --exclude-files "$GLOBAL_EXCLUDE" \
  "$@"
