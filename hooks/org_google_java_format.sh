#!/usr/bin/env bash
# Runs google-java-format, auto-downloading the jar into pre-commit cache.
# Env overrides:
#   GJF_VERSION         (default: 1.22.0)
#   PRE_COMMIT_HOME     (pre-commit sets this; falls back to ~/.cache/pre-commit)
set -euo pipefail

GJF_VERSION="${GJF_VERSION:-1.22.0}"
CACHE_DIR="${PRE_COMMIT_HOME:-$HOME/.cache/pre-commit}/opt/java-tools"
JAR="${CACHE_DIR}/google-java-format-${GJF_VERSION}-all-deps.jar"
URL="https://github.com/google/google-java-format/releases/download/v${GJF_VERSION}/google-java-format-${GJF_VERSION}-all-deps.jar"

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
  echo "Downloading google-java-format ${GJF_VERSION} ..."
  dl "$URL" "$JAR"
fi

# Ensure Java exists
if ! command -v java >/dev/null 2>&1; then
  echo "Java runtime not found on PATH." >&2
  exit 1
fi

# Pass through filenames from pre-commit
exec java -jar "$JAR" --replace "$@"
