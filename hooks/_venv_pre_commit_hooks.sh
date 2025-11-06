#!/usr/bin/env bash
# Ensures a cached venv with pre-commit-hooks installed, then execs a python -m command.
set -euo pipefail
IFS=$'\n\t'

PKG="pre-commit-hooks"
VER="${PRE_COMMIT_HOOKS_VERSION:-4.6.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/${PKG}-${VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

ensure_pip() {
  local pybin="$1"
  # Try pip; if missing, bootstrap via ensurepip (some distros disable pip in venv by default)
  if ! "$pybin" -m pip --version >/dev/null 2>&1; then
    "$pybin" -m ensurepip --upgrade >/dev/null 2>&1 || true
  fi
  # After ensurepip, try to upgrade pip/setuptools/wheel; ignore network errors gracefully
  "$pybin" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
}

create_venv_if_needed() {
  if [ ! -x "${VENV_DIR}/bin/python" ]; then
    mkdir -p "$CACHE_DIR"
    "$PY" -m venv "$VENV_DIR"
  fi
  if [ ! -x "${VENV_DIR}/bin/python" ]; then
    echo "ERROR: failed to create venv at ${VENV_DIR}" >&2
    exit 1
  fi
}

install_pkg_if_needed() {
  local pybin="${VENV_DIR}/bin/python"
  ensure_pip "$pybin"
  # install package if not present (or wrong version)
  if ! "$pybin" -c "import pkg_resources, sys; \
      import pre_commit_hooks as _; \
      assert pkg_resources.get_distribution('pre-commit-hooks').version == '${VER}'" >/dev/null 2>&1; then
    "$pybin" -m pip install "${PKG}==${VER}"
  fi
}

# --- main ---
create_venv_if_needed
install_pkg_if_needed

# $1 is the pre_commit_hooks.<module> to run
MOD="$1"; shift
exec "${VENV_DIR}/bin/python" -m "pre_commit_hooks.${MOD}" "$@"
