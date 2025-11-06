#!/usr/bin/env bash
# Runs Checkstyle with org profiles, auto-downloading jar & configs into pre-commit cache.
# Profile resolution order (highest → lowest):
#   1) --profile=<name> or --profile <name> (from .pre-commit-config.yaml args)
#   2) $ORG_CHECKSTYLE_PROFILE (env)
#   3) "base"
#
# Optional env:
#   CHECKSTYLE_VERSION (default: 12.1.1)
#   ORG_CHECKSTYLE_BASEURL (default: https://raw.githubusercontent.com/UKHomeOffice/code-standards/main/profiles)
#   ORG_CHECKSTYLE_URL / ORG_SUPPRESSIONS_URL (explicit URLs override profile paths)
#   PRE_COMMIT_HOME
set -euo pipefail

# --- Parse custom hook args (strip them before passing filenames to Checkstyle) ---
PROFILE_FROM_ARG=""
REMAINING_ARGS=()
while (( "$#" )); do
  case "$1" in
    --profile=*)
      PROFILE_FROM_ARG="${1#*=}"; shift ;;
    --profile)
      shift
      PROFILE_FROM_ARG="${1:-}"; shift || true ;;
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
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" "$url"
  else
    echo "ERROR: Neither curl nor wget found." >&2
    exit 1
  fi
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
CFG_PATH=""; SUP_PATH=""
if [ -f "./checkstyle.xml" ]; then CFG_PATH="$(pwd)/checkstyle.xml"; fi
if [ -f "./suppressions.xml" ]; then SUP_PATH="$(pwd)/suppressions.xml"; fi

if [ -z "$CFG_PATH" ]; then
  if [ ! -f "$CFG_CACHE" ]; then
    echo "Fetching Checkstyle config (${PROFILE}) from: $CFG_URL"
    dl "$CFG_URL" "$CFG_CACHE"
  fi
  CFG_PATH="$CFG_CACHE"
fi
if [ -z "$SUP_PATH" ]; then
  if [ ! -f "$SUP_CACHE" ]; then
    echo "Fetching suppressions (${PROFILE}) from: $SUP_URL"
    dl "$SUP_URL" "$SUP_CACHE"
  fi
  SUP_PATH="$SUP_CACHE"
fi

# --- Run Checkstyle -----------------------------------------------------------
exec java -jar "$JAR" -c "$CFG_PATH" -p "checkstyle.suppression.file=${SUP_PATH}" "${REMAINING_ARGS[@]}"
