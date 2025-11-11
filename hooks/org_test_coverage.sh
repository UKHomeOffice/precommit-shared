#!/usr/bin/env bash
# org_test_coverage.sh — enforce minimum test coverage at pre-push
# Supports: Gradle (JaCoCo), Maven (JaCoCo), Jest (coverage-summary.json)
# macOS-safe (no GNU-only options), bash 3.2+ compatible.
set -euo pipefail

MIN=80                # default minimum coverage %
ENGINE="auto"         # auto | gradle | maven | jest
ALLOW_MISSING=0       # 1=do not fail when no engine/report found

# --- Parse args ---
for a in "$@"; do
  case "$a" in
    --min=*)         MIN="${a#*=}";;
    --engine=*)      ENGINE="${a#*=}";;
    --allow-missing) ALLOW_MISSING=1;;
    *) echo "Unknown arg: $a" >&2; exit 2;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

note() { printf '%s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

pct_lt() {
  # returns 0 (true) if $1 < $2 using bc
  awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<b)}'
}

# --- Detect engine if auto ---
detect_engine() {
  if [[ -f "gradlew" || -f "build.gradle" || -f "build.gradle.kts" ]]; then
    echo "gradle"; return
  fi
  if [[ -f "pom.xml" ]]; then
    echo "maven"; return
  fi
  if [[ -f "package.json" ]]; then
    # prefer existing summary file to avoid running JS tests if not needed
    if [[ -f "coverage/coverage-summary.json" ]]; then
      echo "jest"; return
    fi
    # fall back to jest if present in dev deps (best-effort)
    if grep -q '"jest"' package.json 2>/dev/null; then
      echo "jest"; return
    fi
  fi
  echo "none"
}

run_gradle() {
  note "→ Running Gradle JaCoCo (jacocoTestReport)…"
  # Ensure XML report is generated (teams should enable this in build.gradle)
  ./gradlew --no-daemon --console=plain jacocoTestReport >/dev/null
  local xml
  # Common locations per-module or root
  xml=$(ls -1 **/build/reports/jacoco/test/jacocoTestReport.xml 2>/dev/null | head -1 || true)
  [[ -z "$xml" ]] && xml=$(ls -1 build/reports/jacoco/test/jacocoTestReport.xml 2>/dev/null | head -1 || true)
  [[ -z "$xml" ]] && die "JaCoCo XML report not found. Ensure 'jacocoTestReport { reports { xml.required = true } }' is configured."
  parse_jacoco_xml "$xml"
}

run_maven() {
  note "→ Running Maven tests + JaCoCo report…"
  mvn -q -DskipITs -Djacoco.skip=false test jacoco:report >/dev/null
  local xml="target/site/jacoco/jacoco.xml"
  [[ ! -f "$xml" ]] && die "JaCoCo XML report not found at $xml. Ensure jacoco-maven-plugin is configured to produce XML."
  parse_jacoco_xml "$xml"
}

parse_jacoco_xml() {
  local xml="$1"
  # Extract LINE counter (missed, covered)
  local missed covered total pct
  missed=$(sed -n 's/.*<counter type="LINE" missed="\([0-9]\+\)".*/\1/p' "$xml" | head -1)
  covered=$(sed -n 's/.*<counter type="LINE" missed="[0-9]\+" covered="\([0-9]\+\)".*/\1/p' "$xml" | head -1)
  [[ -z "$missed" || -z "$covered" ]] && die "Failed to parse JaCoCo XML: $xml"
  total=$((missed + covered))
  if [[ "$total" -eq 0 ]]; then
    pct="0"
  else
    # use awk for portable float division
    pct=$(awk -v c="$covered" -v t="$total" 'BEGIN{printf "%.2f", (c*100.0)/t}')
  fi
  echo "$pct"
}

run_jest() {
  local summary="coverage/coverage-summary.json"
  if [[ ! -f "$summary" ]]; then
    note "→ Generating Jest coverage summary…"
    # lightweight: only json-summary
    if command -v npx >/dev/null 2>&1; then
      npx --yes jest --coverage --coverageReporters=json-summary >/dev/null
    else
      die "npx not found and coverage/coverage-summary.json missing."
    fi
  fi
  [[ ! -f "$summary" ]] && die "Missing $summary"
  # Extract total lines pct from JSON without jq (best-effort)
  local pct
  pct=$(sed -n 's/.*"lines":[^{]*{[^}]*"pct":[[:space:]]*\([0-9.]\+\).*/\1/p' "$summary" | head -1)
  [[ -z "$pct" ]] && die "Failed to parse lines.pct from $summary"
  echo "$pct"
}

main() {
  local engine="$ENGINE"
  if [[ "$engine" == "auto" ]]; then
    engine=$(detect_engine)
  fi

  if [[ "$engine" == "none" ]]; then
    if [[ "$ALLOW_MISSING" -eq 1 ]]; then
      note "No supported test framework detected (Gradle/Maven/Jest). Skipping (allowed)."
      exit 0
    fi
    die "No supported test framework detected (Gradle/Maven/Jest)."
  fi

  local pct
  case "$engine" in
    gradle) pct="$(run_gradle)";;
    maven)  pct="$(run_maven)";;
    jest)   pct="$(run_jest)";;
    *)      die "Unsupported engine: $engine";;
  esac

  note "Coverage ($engine): ${pct}% (required ≥ ${MIN}%)"
  if pct_lt "$pct" "$MIN"; then
    die "Coverage below threshold."
  fi

  echo "OK: Coverage ${pct}% ≥ ${MIN}%"
}

main "$@"
