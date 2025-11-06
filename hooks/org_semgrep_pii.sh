#!/usr/bin/env bash
# Semgrep PII scanner (org). Prefers Docker; falls back to self-healing venv.
set -euo pipefail
IFS=$'\n\t'

# ---- versions / config -------------------------------------------------------
SG_VER="${SEMGREP_VERSION:-1.92.0}"             # semgrep image / pip pkg version
TRANSPORT="${ORG_SEMGREP_TRANSPORT:-auto}"      # auto|docker|venv

# Centralized excludes: tests, node_modules, migrations, functional tests, SQL/properties/feature
EXCLUDE_RE='(^|.*/)(test|tests|__tests__|src/test|node_modules|db/migration|cwfa-functional-test)/|(\.sql$)|(\.properties$)|(\.properties\.md$)|(\.feature$)'

# Resolve rules file (default to shared repo's rules/pii.yml)
RULES_URL="${ORG_SEMGREP_RULES_URL:-}"
if [ -z "$RULES_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RULES_URL="${SCRIPT_DIR%/hooks}/rules/pii.yml"
fi

# Filter the filenames pre-commit passes
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

# ---- mode 1: Docker (preferred) ----------------------------------------------
run_docker() {
  command -v docker >/dev/null 2>&1 || return 1

  REPO_ROOT="$(pwd)"

  # Resolve rules to absolute path and split dir/name
  RULES_ABS="$RULES_URL"
  case "$RULES_ABS" in /*) : ;; *) RULES_ABS="$REPO_ROOT/$RULES_ABS" ;; esac
  RULES_DIR="$(cd "$(dirname "$RULES_ABS")" && pwd)"
  RULES_BASENAME="$(basename "$RULES_ABS")"

  # Generate relative file list for clarity
  TMPDIR="${TMPDIR:-/tmp}"
  ARGS_FILE="$(mktemp "${TMPDIR%/}/semgrep-files.XXXXXX")"
  trap 'rm -f "$ARGS_FILE"' EXIT
  printf '%s\n' "${FILES[@]}" > "$ARGS_FILE"

  # Run semgrep (v1.89+ syntax) explicitly with `semgrep scan`
  docker run --rm \
    -e SEMGREP_SEND_METRICS=0 \
    -e SEMGREP_ENABLE_VERSION_CHECK=0 \
    -v "$REPO_ROOT:/work:ro" \
    -v "$RULES_DIR:/rules:ro" \
    -v "$ARGS_FILE:/files.list:ro" \
    -w /work \
    "semgrep/semgrep:${SG_VER}" \
    sh -c '
      # shell inside container
      set -e
      if semgrep scan --help | grep -q -- "--include"; then
        # modern CLI
        xargs semgrep scan \
          --config "/rules/'"${RULES_BASENAME}"'" \
          --error --skip-unknown-extensions --json < /files.list
      else
        # older CLI fallback
        xargs semgrep \
          --config "/rules/'"${RULES_BASENAME}"'" \
          --error --skip-unknown-extensions --json < /files.list
      fi
    '
}


# ---- mode 2: venv (fallback) -------------------------------------------------
run_venv() {
  PY="${PYTHON_BIN:-python3}"
  CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/semgrep-${SG_VER}"
  VENV_DIR="${CACHE_DIR}/venv"

  nuke_broken() { rm -rf "$VENV_DIR"; }

  ensure_env() {
    mkdir -p "$CACHE_DIR"
    if [ ! -x "${VENV_DIR}/bin/python" ]; then
      "$PY" -m venv "$VENV_DIR"
    fi
    # Ensure pip inside the venv (some venvs start without it)
    "${VENV_DIR}/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
    # Pin safe toolchain to dodge pkg_resources/import issues
    "${VENV_DIR}/bin/python" -m pip install -q --upgrade \
      "pip==24.2" "setuptools==69.5.1" "wheel==0.44.0" || true
  }

  install_semgrep() {
    if ! "${VENV_DIR}/bin/python" - <<'PY'
try:
  import semgrep, sys
  assert semgrep.__version__  # just import check
except Exception:
  raise SystemExit(1)
PY
    then
      "${VENV_DIR}/bin/python" -m pip install -q "semgrep==${SG_VER}" || return 1
    fi
  }

  health_check() {
    "${VENV_DIR}/bin/python" - <<'PY'
try:
  import pkg_resources
  import semgrep
except Exception:
  raise SystemExit(1)
PY
  }

  # build / repair
  ensure_env || { nuke_broken; ensure_env; }
  install_semgrep || { nuke_broken; ensure_env; install_semgrep || exit 2; }
  health_check || { nuke_broken; ensure_env; install_semgrep || exit 3; }

  export SEMGREP_SEND_METRICS=0
  export SEMGREP_ENABLE_VERSION_CHECK=0

  # feed files via argv list to avoid lengthy command lines
  TMPDIR="${TMPDIR:-/tmp}"
  ARGS_FILE="$(mktemp "${TMPDIR%/}/semgrep-files.XXXXXX")"
  trap 'rm -f "$ARGS_FILE"' EXIT
  printf '%s\n' "${FILES[@]}" > "$ARGS_FILE"

  exec "${VENV_DIR}/bin/semgrep" \
    --config "$RULES_URL" \
    --error \
    --skip-unknown-extensions \
    --json \
    --include-from "$ARGS_FILE"
}

# ---- dispatcher --------------------------------------------------------------
case "$TRANSPORT" in
  docker)
    run_docker || { echo "[org-semgrep-pii] Docker requested but failed." >&2; exit 1; }
    ;;
  venv)
    run_venv
    ;;
  auto)
    if run_docker; then exit 0; fi
    run_venv
    ;;
  *)
    echo "[org-semgrep-pii] Unknown ORG_SEMGREP_TRANSPORT='$TRANSPORT' (use auto|docker|venv)" >&2
    exit 2
    ;;
esac
