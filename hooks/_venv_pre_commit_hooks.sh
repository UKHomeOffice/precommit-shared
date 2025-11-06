#!/usr/bin/env bash
# Ensures a cached venv with pre-commit-hooks installed, then execs a python -m command.
set -euo pipefail

PKG="pre-commit-hooks"
VER="${PRE_COMMIT_HOOKS_VERSION:-4.6.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/${PKG}-${VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

if [ ! -x "${VENV_DIR}/bin/python" ]; then
  mkdir -p "$CACHE_DIR"
  "$PY" -m venv "$VENV_DIR"
  "${VENV_DIR}/bin/pip" install --upgrade pip
  "${VENV_DIR}/bin/pip" install "${PKG}==${VER}"
fi

# $1 must be the module name after 'pre_commit_hooks.'; remaining are args/filenames.
MOD="$1"; shift
exec "${VENV_DIR}/bin/python" -m "pre_commit_hooks.${MOD}" "$@"
