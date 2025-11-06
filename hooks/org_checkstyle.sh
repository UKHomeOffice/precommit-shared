#!/usr/bin/env bash
# Runs Checkstyle with org profiles, auto-downloading jar & configs into pre-commit cache.
# Env (all optional):
#   CHECKSTYLE_VERSION      default: 12.1.1
#   ORG_CHECKSTYLE_PROFILE  base | legacy   (default: base)
#   ORG_CHECKSTYLE_BASEURL  default: https://raw.githubusercontent.com/UKHomeOffice/code-standards/main/profiles
#   ORG_CHECKSTYLE_URL      explicit single-file config URL (overrides profile URLs)
#   ORG_SUPPRESSIONS_URL    explicit suppressions URL (overrides profile URLs)
#   PRE_COMMIT_HOME         pre-commit cache dir; falls back to ~/.cache/pre-commit
#
# Local overrides (if present in repo root, take precedence over remote/profile):
#   ./checkstyle.xml
#   ./suppressions.xml
set -euo pipefail

# --- Versions / paths ---------------------------------------------------------
CS_VERSION="${CHECKSTYLE_VERSION:-12.1.1}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/java-tools"
JAR="${CACHE_DIR}/checkstyle-${CS_VERSION}-all.jar"
JAR_URL="https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CS_VERSION}/checkstyle-${CS_VERSION}-all.jar"

# --- Profile wiring -----------------------------------------------------------
PROFILE="${ORG_CHECKSTYLE_PROFILE:-base}"
BASEURL_DEFAULT="https://raw.githubusercontent.com/UKHomeOffice/code-standards/main/profiles"
BASEURL="${ORG_CHECKSTYLE_BASEURL:-$BASEURL_DEFAULT}"

# If explicit URLs are provided, they win; otherwise use profile URLs.
CFG_URL="${ORG_CHECKSTYLE_URL:-${BASEURL}/${PROFILE}/checkstyle.xml}"
SUP_URL="${ORG_SUPPRESSIONS_URL:-${BASEURL}/${PROFILE}/suppressions.xml}"

# Cache per profile so teams can switch without clobbering
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

# --- Resolve config & suppressions (local > explicit URL > profile URL) -------
CFG_PATH=""
SUP_PATH=""

# 1) Local overrides (repo root)
if [ -f "./checkstyle.xml" ]; then CFG_PATH="$(pwd)/checkstyle.xml"; fi
if [ -f "./suppressions.xml" ]; then SUP_PATH="$(pwd)/suppressions.xml"; fi

# 2) Remote / profile (download to cache if not already)
if [ -z "${CFG_PATH}" ]; then
  if [ ! -f "$CFG_CACHE" ]; then
    echo "Fetching Checkstyle config (${PROFILE}) from: $CFG_URL"
    dl "$CFG_URL" "$CFG_CACHE"
  fi
  CFG_PATH="$CFG_CACHE"
fi
if [ -z "${SUP_PATH}" ]; then
  if [ ! -f "$SUP_CACHE" ]; then
    echo "Fetching suppressions (${PROFILE}) from: $SUP_URL"
    dl "$SUP_URL" "$SUP_CACHE"
  fi
  SUP_PATH="$SUP_CACHE"
fi

# --- Run Checkstyle -----------------------------------------------------------
# Pass suppressions via property so configs don't need hard-coded paths.
# Extra args from pre-commit/file list are forwarded transparently.
exec java -jar "$JAR" -c "$CFG_PATH" -p "checkstyle.suppression.file=${SUP_PATH}" "$@"
