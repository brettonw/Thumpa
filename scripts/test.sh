#!/usr/bin/env bash
set -euo pipefail

# Simple helper to build and run tests on a simulator.

WORKSPACE=${WORKSPACE:-Thumpa.xcworkspace}
SCHEME=${SCHEME:-Thumpa}
RESULT_BUNDLE=${RESULT_BUNDLE:-"TestResults-$(date +%Y%m%d-%H%M%S).xcresult"}

usage() {
  cat <<EOF
Usage: $0 [--show-dest] [--build-only] [--device "iPhone 16"] [--destination "..."]

Env vars:
  WORKSPACE       Xcode workspace path (default: Thumpa.xcworkspace)
  SCHEME          Scheme to test (default: Thumpa)
  RESULT_BUNDLE   Result bundle path (default: timestamped .xcresult)

Flags:
  --show-dest     Show available destinations for the scheme and exit
  --build-only    Only build-for-testing (no simulator tests)
  --device NAME   Preferred simulator name (e.g., "iPhone 16")
  --destination D Full xcodebuild -destination string (takes precedence)
EOF
}

DEVICE_NAME=""
DEST_OVERRIDE=""
BUILD_ONLY=0
SHOW_DEST=0
UNIT_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --show-dest) SHOW_DEST=1; shift ;;
    --build-only) BUILD_ONLY=1; shift ;;
    --device) DEVICE_NAME=${2:-}; shift 2 ;;
    --destination) DEST_OVERRIDE=${2:-}; shift 2 ;;
    --unit-only) UNIT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ $SHOW_DEST -eq 1 ]]; then
  exec xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showdestinations
fi

echo "[1/2] build-for-testing (generic iOS Simulator)" >&2
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -destination 'generic/platform=iOS Simulator' build-for-testing >/dev/null

if [[ $BUILD_ONLY -eq 1 ]]; then
  echo "Build-for-testing completed." >&2
  exit 0
fi

DESTINATION=""
if [[ -n "$DEST_OVERRIDE" ]]; then
  DESTINATION="$DEST_OVERRIDE"
elif [[ -n "${DESTINATION:-}" ]]; then
  : # use as-is
else
  # Default device preference: iPhone 16 unless explicitly provided
  if [[ -z "$DEVICE_NAME" ]]; then
    DEVICE_NAME="iPhone 16"
  fi
  # Try to find a concrete simulator id matching the preferred device name
  SIM_ID=$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showdestinations 2>/dev/null \
    | awk -v NAME="$DEVICE_NAME" '/platform:iOS Simulator/ && /id:/ && $0 !~ /placeholder/ && $0 ~ ("name:" NAME) {for(i=1;i<=NF;i++){if($i ~ /^id:/){gsub(/,/, "", $i); sub(/^id:/, "", $i); gsub(/[}]/, "", $i); print $i; exit}}}')
  if [[ -n "$SIM_ID" ]]; then
    DESTINATION="id=$SIM_ID"
  else
    DESTINATION="platform=iOS Simulator,OS=latest,name=$DEVICE_NAME"
  fi
fi

echo "[2/2] test on destination: $DESTINATION" >&2

set -o pipefail
TEST_ARGS=()
if [[ $UNIT_ONLY -eq 1 ]]; then
  TEST_ARGS+=("-only-testing:ThumpaTests")
fi

if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$RESULT_BUNDLE" test "${TEST_ARGS[@]}" | xcbeautify
elif command -v xcpretty >/dev/null 2>&1; then
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$RESULT_BUNDLE" test "${TEST_ARGS[@]}" | xcpretty
else
  xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -destination "$DESTINATION" -resultBundlePath "$RESULT_BUNDLE" test "${TEST_ARGS[@]}"
fi

echo "Results: $RESULT_BUNDLE" >&2
