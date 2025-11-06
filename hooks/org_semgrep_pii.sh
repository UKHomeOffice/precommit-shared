#!/usr/bin/env bash
# Semgrep PII scanner (org). Prefer Docker; venv fallback optional.
set -euo pipefail
IFS=$'\n\t'

SG_VER="${SEMGREP_VERSION:-1.92.0}"
TRANSPORT="${ORG_SEMGREP_TRANSPORT:-docker}"   # force docker by default

# Centralized excludes (keep in sync with org policy)
EXCLUDE_RE='(^|.*/)(test|tests|__tests__|src/test|node_modules|db/migration|cwfa-functional-test)/|(\.sql$)|(\.properties$)|(\.properties\.md$)|(\.feature$)'

# Resolve rules file (org-curated)
RULES_URL="${ORG_SEMGREP_RULES_URL:-}"
if [ -z "$RULES_URL" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  RULES_URL="${SCRIPT_DIR%/hooks}/rules/pii.yml"
fi

# Filter filenames passed by pre-commit
FILES=()
for f in "$@"; do
  [[ -e "$f" ]] || continue
  if [[ ! "$f" =~ $EXCLUDE_RE ]]; then FILES+=("$f"); fi
done
if [ ${#FILES[@]} -eq 0 ]; then
  echo "[org-semgrep-pii] No eligible files to scan (all excluded)." >&2
  exit 0
fi

run_docker() {
  command -v docker >/dev/null 2>&1 || return 1

  REPO_ROOT="$(pwd)"
  RULES_ABS="$RULES_URL"; case "$RULES_ABS" in /*) : ;; *) RULES_ABS="$REPO_ROOT/$RULES_ABS";; esac
  RULES_DIR="$(cd "$(dirname "$RULES_ABS")" && pwd)"
  RULES_BASENAME="$(basename "$RULES_ABS")"

  # create a temp list of files (mounted into container)
  TMPDIR="${TMPDIR:-/tmp}"
  LIST_FILE="$(mktemp "${TMPDIR%/}/semgrep-files.XXXXXX")"
  trap 'rm -f "$LIST_FILE"' EXIT
  printf '%s\n' "${FILES[@]}" > "$LIST_FILE"

  # inside run_docker()
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
        xargs semgrep scan \
          --config "/rules/'"$RULES_BASENAME"'" \
          --error --skip-unknown-extensions --json < /files.list
      else
        xargs semgrep \
          --config "/rules/'"$RULES_BASENAME"'" \
          --error --skip-unknown-extensions --json < /files.list
      fi
    '
}

run_venv() {
  echo "[org-semgrep-pii] venv mode disabled to avoid host packaging issues." >&2
  echo "Set ORG_SEMGREP_TRANSPORT=venv if you really need it." >&2
  return 1
}

case "$TRANSPORT" in
  docker) run_docker ;;
  auto)   run_docker || run_venv ;;
  venv)   run_venv ;;
  *) echo "[org-semgrep-pii] unknown ORG_SEMGREP_TRANSPORT=$TRANSPORT" >&2; exit 2 ;;
esac
