#!/usr/bin/env bash
set -euo pipefail
changed=$(git diff --cached --name-only -- gradle/wrapper/gradle-wrapper.jar || true)
if [[ -n "$changed" ]]; then
  props_changed=$(git diff --cached --name-only -- gradle/wrapper/gradle-wrapper.properties || true)
  if [[ -z "$props_changed" ]]; then
    echo "ERROR: gradle-wrapper.jar changed without gradle-wrapper.properties." >&2
    exit 1
  fi
fi
