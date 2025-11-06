#!/usr/bin/env bash
# Semgrep PII scanner (org). Docker-first; clean pass/fail output by default.
set -euo pipefail
IFS=$'\n\t'

# ---- versions / transport ----------------------------------------------------
SG_VER="${SEMGREP_VERSION:-1.92.0}"
TRANSPORT="${ORG_SEMGREP_TRANSPORT:-docker}"   # docker | auto | venv
VERBOSE="${ORG_SEMGREP_VERBOSE:-}"             # set to: true/1/on to show findings
QUIET_FLAG="--quiet"
case "${VERBOSE,,}" in true|1|on|yes) QUIET_FLAG="";; esac

# ---- centralized excludes ----------------------------------------------------
EXCLUDE_RE='(^|.*/)(test|tests|__tests__|src/test|node_modules|db/migration|cwfa-functional-test)/|(\.sql$)|(\.properties$)|(\.properties\.md$)|(\.feature$)'

# ---- resolve rules file ------------------------------------------------------
RULES_URL="${ORG_SEMGREP_RULES_URL:-}"
if [ -z "$RULES_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RULES_URL="${SCRIPT_DIR%/hooks}/rules/pii.yml"
fi

# ---- filter incoming filenames (only regular files; honor excludes) ----------
FILES=()
for f in "$@"; do
  [[ -f "$f" ]] || continue
  if [[ ! "$f" =~ $EXCLUDE_RE ]]; then
    FILES+=("$f")
  fi
done
if [ ${#FILES[@]} -eq 0 ]; then
  echo "[org-semgrep-pii] No eligible files to scan (all excluded)." >&2
  exit 0
fi

# ---- docker runner -----------------------------------------------------------
run_docker() {
  command -v docker >/dev/null 2>&1 || return 1

  REPO_ROOT="$(pwd)"
  RULES_ABS="$RULES_URL"; case "$RULES_ABS" in /*) : ;; *) RULES_ABS="$REPO_ROOT/$RULES_ABS";; esac
  RULES_DIR="$(cd "$(dirname "$RULES_ABS")" && pwd)"
  RULES_BASENAME="$(basename "$RULES_ABS")"

  # NUL-delimited list (handles spaces/newlines in paths)
  TMPDIR="${TMPDIR:-/tmp}"
  LIST_FILE="$(mktemp "${TMPDIR%/}/semgrep-files.XXXXXX")"
  trap 'rm -f "$LIST_FILE"' EXIT
  : > "$LIST_FILE"
  for f in "${FILES[@]}"; do printf '%s\0' "$f" >> "$LIST_FILE"; done

  docker run --rm \
    -e SEMGREP_SEND_METRICS=off \
    -e SEMGREP_ENABLE_VERSION_CHECK=false \
    -v "$REPO_ROOT:/work:ro" \
    -v "$RULES_DIR:/rules:ro" \
    -v "$LIST_FILE:/files.list:ro" \
    -w /work \
    "semgrep/semgrep:${SG_VER}" \
    sh -c '
      set -e
      if semgrep scan --help >/dev/null 2>&1; then
        # modern CLI
        if [ -n "'"$QUIET_FLAG"'" ]; then
          xargs -0 semgrep scan \
            --config "/rules/'"$RULES_BASENAME"'" \
            --error --skip-unknown-extensions --metrics=off '"$QUIET_FLAG"' < /files.list
        else
          # verbose: human-friendly output (no JSON)
          xargs -0 semgrep scan \
            --config "/rules/'"$RULES_BASENAME"'" \
            --error --skip-unknown-extensions --metrics=off < /files.list
        fi
      else
        # legacy CLI fallback
        if [ -n "'"$QUIET_FLAG"'" ]; then
          xargs -0 semgrep \
            --config "/rules/'"$RULES_BASENAME"'" \
            --error --skip-unknown-extensions '"$QUIET_FLAG"' < /files.list
        else
          xargs -0 semgrep \
            --config "/rules/'"$RULES_BASENAME"'" \
            --error --skip-unknown-extensions < /files.list
        fi
      fi
    '
}

# ---- venv fallback (disabled by default) -------------------------------------
run_venv() {
  echo "[org-semgrep-pii] venv mode disabled; set ORG_SEMGREP_TRANSPORT=auto or venv to enable." >&2
  return 1
}

# ---- dispatch ----------------------------------------------------------------
case "$TRANSPORT" in
  docker) run_docker ;;
  auto)   run_docker || run_venv ;;
  venv)   run_venv ;;
  *) echo "[org-semgrep-pii] Unknown ORG_SEMGREP_TRANSPORT=$TRANSPORT (use docker|auto|venv)" >&2; exit 2 ;;
esac
