#!/usr/bin/env bash
# Runs Checkstyle, auto-downloading the jar and a config into pre-commit cache.
# Env overrides:
#   CHECKSTYLE_VERSION  (default: 12.1.1)
#   ORG_CHECKSTYLE_URL  (HTTP(S) URL to your org-wide checkstyle.xml)
#   PRE_COMMIT_HOME     (pre-commit sets this; falls back to ~/.cache/pre-commit)
set -euo pipefail

CS_VERSION="${CHECKSTYLE_VERSION:-12.1.1}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/java-tools"
JAR="${CACHE_DIR}/checkstyle-${CS_VERSION}-all.jar"
CFG="${CACHE_DIR}/checkstyle.xml"
JAR_URL="https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CS_VERSION}/checkstyle-${CS_VERSION}-all.jar"
# Fallback config if ORG_CHECKSTYLE_URL not provided
DEFAULT_CFG_URL="https://raw.githubusercontent.com/checkstyle/checkstyle/master/src/main/resources/google_checks.xml"

mkdir -p "${CACHE_DIR}"

dl() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url"
  else
    echo "Neither curl nor wget found." >&2
    exit 1
  fi
}

if [ ! -f "$JAR" ]; then
  echo "Downloading Checkstyle ${CS_VERSION} ..."
  dl "$JAR_URL" "$JAR"
fi

if [ -n "${ORG_CHECKSTYLE_URL:-}" ]; then
  if [ ! -f "$CFG" ]; then
    echo "Fetching org Checkstyle config from ${ORG_CHECKSTYLE_URL} ..."
    dl "$ORG_CHECKSTYLE_URL" "$CFG"
  fi
else
  if [ ! -f "$CFG" ]; then
    echo "ORG_CHECKSTYLE_URL not set; using Google checks as default."
    dl "$DEFAULT_CFG_URL" "$CFG"
  fi
fi

# Ensure Java exists
if ! command -v java >/dev/null 2>&1; then
  echo "Java runtime not found on PATH." >&2
  exit 1
fi

# Pass through filenames from pre-commit
exec java -jar "$JAR" -c "$CFG" "$@"
