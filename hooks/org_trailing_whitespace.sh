#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/_venv_pre_commit_hooks.sh" trailing_whitespace_fixer "$@"
