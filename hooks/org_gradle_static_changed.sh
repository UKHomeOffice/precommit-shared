#!/usr/bin/env bash
set -euo pipefail
DET="./tools/gradle_changed_projects.sh"
if [ ! -x "$DET" ]; then
  mkdir -p ./tools
  curl -fsSL "https://raw.githubusercontent.com/your-org/precommit-shared/main/hooks/gradle_changed_projects.sh" -o "$DET"
  chmod +x "$DET"
fi
MODS="$("$DET" || true)"
if [ -z "$MODS" ]; then
  echo "No Gradle subproject changes detected; skipping static analysis."
  exit 0
fi
TASKS=""
for p in $(echo "$MODS" | tr "," " "); do
  TASKS="$TASKS ${p}:checkstyleMain ${p}:checkstyleTest ${p}:spotbugsMain"
done
./gradlew --no-daemon --console=plain -x test $TASKS
