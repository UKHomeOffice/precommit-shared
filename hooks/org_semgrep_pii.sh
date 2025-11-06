#!/usr/bin/env bash
# Runs Semgrep with org PII rules and centralized excludes.
# Self-heals broken venvs and pins pip/setuptools/wheel to avoid pkg_resources issues.
set -euo pipefail
IFS=$'\n\t'

# ---- versions (adjust if you need) ------------------------------------------
SG_VER="${SEMGREP_VERSION:-1.92.0}"       # Semgrep version you want
PIP_VER="${PIP_VERSION:-24.2}"            # safe pip
SETUPTOOLS_VER="${SETUPTOOLS_VERSION:-69.5.1}"  # avoid >=70 breakages
WHEEL_VER="${WHEEL_VERSION:-0.44.0}"

# ---- venv paths --------------------------------------------------------------
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/semgrep-${SG_VER}"
VENV_DIR="${CACHE_DIR}/venv"
PY="${PYTHON_BIN:-python3}"

# ---- rules path --------------------------------------------------------------
RULES_URL="${ORG_SEMGREP_RULES_URL:-}"
if [ -z "$RULES_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RULES_URL="${SCRIPT_DIR%/hooks}/rules/pii.yml"
fi

# ---- helpers -----------------------------------------------------------------
nuke_broken_venv() {
  rm -rf "$VENV_DIR"
}

ensure_venv() {
  if [ ! -x "${VENV_DIR}/bin/python" ]; then
    mkdir -p "$CACHE_DIR"
    "$PY" -m venv "$VENV_DIR"
  fi

  # ensure pip
  if ! "${VENV_DIR}/bin/python" -m pip --version >/dev/null 2>&1; then
    "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
  fi

  # upgrade toolchain to safe versions
  "${VENV_DIR}/bin/python" -m pip install --upgrade \
    "pip==${PIP_VER}" \
    "setuptools==${SETUPTOOLS_VER}" \
    "wheel==${WHEEL_VER}"
}

install_semgrep() {
  if ! "${VENV_DIR}/bin/python" -c "import semgrep, sys; assert semgrep.__version__=='${SG_VER}'" >/dev/null 2>&1; then
    "${VENV_DIR}/bin/python" -m pip install "semgrep==${SG_VER}"
  fi
}

health_check_or_rebuild() {
  # basic import chain exercise that previously failed (pkg_resources / OTEL)
  if ! "${VENV_DIR}/bin/python" - <<'PY'
try:
    import pkg_resources  # from setuptools
    import semgrep
except Exception as e:
    raise SystemExit(1)
PY
  then
    echo "[org-semgrep-pii] Detected broken venv; rebuilding…" >&2
    nuke_broken_venv
    ensure_venv
    install_semgrep
  fi
}

# ---- build venv --------------------------------------------------------------
ensure_venv
install_semgrep
health_check_or_rebuild

# ---- centralized excludes ----------------------------------------------------
EXCLUDE_RE='(^|.*/)(test|tests|__tests__|src/test|node_modules|db/migration|cwfa-functional-test)/|(\.sql$)|(\.properties$)|(\.properties\.md$)|(\.feature$)'

FILES=()
for f in "$@"; do
  [[ -e "$f" ]] || continue
  if [[ ! "$f" =~ $EXCLUDE_RE ]]; then
    FILES+=("$f")
  fi
done

if [ ${#FILES[@]} -eq 0 ]; then
  echo "[org-semgrep-pii] No eligible files to scan (all excluded)." >&2
  exit 0
fi

# ---- run semgrep -------------------------------------------------------------
# Disable telemetry to reduce deps surface during import
export SEMGREP_SEND_METRICS=0
export SEMGREP_ENABLE_VERSION_CHECK=0

exec "${VENV_DIR}/bin/semgrep" \
  --config "$RULES_URL" \
  --error \
  --skip-unknown-extensions \
  --json \
  "${FILES[@]}"
