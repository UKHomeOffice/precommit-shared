#!/usr/bin/env bash
# Runs Checkstyle with org profiles, auto-downloading jar & configs into pre-commit cache.
# Profile resolution order:
#   1) --profile=<name> or --profile <name>
#   2) $ORG_CHECKSTYLE_PROFILE
#   3) "base"
#
# Optional env:
#   CHECKSTYLE_VERSION (default: 12.1.1)
#   ORG_CHECKSTYLE_BASEURL (default: https://raw.githubusercontent.com/UKHomeOffice/code-standards/main/profiles)
#   ORG_CHECKSTYLE_URL / ORG_SUPPRESSIONS_URL (override profile URLs)
#   PRE_COMMIT_HOME

set -euo pipefail
IFS=$'\n\t'

# --- Parse custom hook args (strip them before passing to Checkstyle) ----------
PROFILE_FROM_ARG=""
REMAINING_ARGS=()
while (($#)); do
  case "$1" in
    --profile=*)
      PROFILE_FROM_ARG="${1#*=}"; shift ;;
    --profile)
      shift
      if [ $# -gt 0 ]; then PROFILE_FROM_ARG="$1"; shift; fi ;;
    *)
      REMAINING_ARGS+=("$1"); shift ;;
  esac
done

# --- Profile & endpoints -------------------------------------------------------
CS_VERSION="${CHECKSTYLE_VERSION:-12.1.1}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/java-tools"
JAR="${CACHE_DIR}/checkstyle-${CS_VERSION}-all.jar"
JAR_URL="https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CS_VERSION}/checkstyle-${CS_VERSION}-all.jar"

PROFILE="${PROFILE_FROM_ARG:-${ORG_CHECKSTYLE_PROFILE:-base}}"
BASEURL_DEFAULT="https://raw.githubusercontent.com/UKHomeOffice/code-standards/main/profiles"
BASEURL="${ORG_CHECKSTYLE_BASEURL:-$BASEURL_DEFAULT}"

# If explicit URLs are provided, they win; otherwise use profile URLs.
CFG_URL="${ORG_CHECKSTYLE_URL:-${BASEURL}/${PROFILE}/checkstyle.xml}"
SUP_URL="${ORG_SUPPRESSIONS_URL:-${BASEURL}/${PROFILE}/suppressions.xml}"

# Cache per profile
CFG_CACHE="${CACHE_DIR}/checkstyle-${PROFILE}.xml"
SUP_CACHE="${CACHE_DIR}/suppressions-${PROFILE}.xml"

# --- Helpers ------------------------------------------------------------------
dl() {
  local url="$1" out="$2"
  local tmp="${out}.tmp.$$"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp" "$url"
  else
    echo "ERROR: Neither curl nor wget found." >&2
    exit 1
  fi
  # basic sanity
  if [ ! -s "$tmp" ]; then
    echo "ERROR: Downloaded empty file from $url" >&2
    rm -f "$tmp"; exit 1
  fi
  mv "$tmp" "$out"
}

abspath() { # make absolute path (POSIX-safe)
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s\n' "$(pwd)/$1" ;;
  esac
}

# --- Ensure tools -------------------------------------------------------------
mkdir -p "$CACHE_DIR"
if [ ! -f "$JAR" ]; then
  echo "Downloading Checkstyle ${CS_VERSION} …"
  dl "$JAR_URL" "$JAR"
fi
if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: Java runtime not found on PATH." >&2
  exit 1
fi

# --- Resolve config & suppressions (local overrides win) ----------------------
CFG_PATH=""
SUP_PATH=""

# local overrides (repo root)
[ -f "./checkstyle.xml" ]   && CFG_PATH="$(abspath ./checkstyle.xml)"
[ -f "./suppressions.xml" ] && SUP_PATH="$(abspath ./suppressions.xml)"

# fall back to cached remote/profile files
if [ -z "$CFG_PATH" ]; then
  if [ ! -f "$CFG_CACHE" ]; then
    echo "Fetching Checkstyle config (${PROFILE}) from: $CFG_URL"
    dl "$CFG_URL" "$CFG_CACHE"
  fi
  CFG_PATH="$(abspath "$CFG_CACHE")"
fi

if [ -z "$SUP_PATH" ]; then
  if [ ! -f "$SUP_CACHE" ]; then
    echo "Fetching suppressions (${PROFILE}) from: $SUP_URL"
    dl "$SUP_URL" "$SUP_CACHE"
  fi
  SUP_PATH="$(abspath "$SUP_CACHE")"
fi

# --- Run Checkstyle -----------------------------------------------------------
# IMPORTANT: your config must reference ${checkstyle.suppression.file}
# Example:
#   <module name="SuppressionFilter">
#     <property name="file" value="${checkstyle.suppression.file}"/>
#   </module>
exec java -Dcheckstyle.suppression.file="$SUP_PATH" \
     -jar "$JAR" -c "$CFG_PATH" "${REMAINING_ARGS[@]}"
