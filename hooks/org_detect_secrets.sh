#!/usr/bin/env bash
# Bootstraps a private venv under pre-commit cache and runs detect-secrets-hook
set -euo pipefail

DS_VERSION="${DS_VERSION:-1.5.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/detect-secrets"
VENV_DIR="${CACHE_DIR}/venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"

# Create venv once
if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
  "${VENV_DIR}/bin/pip" install --upgrade pip
  "${VENV_DIR}/bin/pip" install "detect-secrets==${DS_VERSION}"
fi

# --- Centralized exclusion regex ---
GLOBAL_EXCLUDE='(^|.*/)(terraform|tools|packer|cwfa-performance-tests|cwfa-jenkins|cwfa-functional-test|cwfa-docs|cwfa-dev-env|build|dist|out|target|node_modules|vendor|generated|\.cache|test|tests|__tests__|src/test)/|(\.properties$)|(^|.*/)docker-compose.*\.ya?ml$'


# Run detect-secrets-hook with consistent baseline + exclude
exec "${VENV_DIR}/bin/detect-secrets-hook" \
  --baseline .secrets.baseline \
  --exclude-files "$GLOBAL_EXCLUDE" \
  "$@"
