#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
DERIVED_DATA_DIR="$ROOT_DIR/.deriveddata"
mkdir -p "$DERIVED_DATA_DIR"
STRICT_IOS_TESTS="${STRICT_IOS_TESTS:-1}"
ALLOW_SKIP_IOS_TESTS="${ALLOW_SKIP_IOS_TESTS:-0}"

build_status="pending"
ios_tests_status="pending"
backend_status="pending"

print_summary() {
  echo "== Preflight summary =="
  echo "iOS build:        $build_status"
  echo "iOS tests:        $ios_tests_status"
  echo "Backend tests:    $backend_status"
}

echo "== iOS build =="
xcodebuild -scheme readytoorder -derivedDataPath "$DERIVED_DATA_DIR" -destination 'generic/platform=iOS Simulator' build > "$ROOT_DIR/build.log" 2>&1
build_status="passed"
if command -v rg >/dev/null 2>&1; then
  rg -n "error:|warning:" "$ROOT_DIR/build.log" || true
fi

echo "== iOS tests =="
: > "$ROOT_DIR/build_ios_tests.log"
SIM_ID="$({ xcrun simctl list devices available 2>/dev/null || true; } | awk -F '[()]' '/^[[:space:]]*iPhone/ { print $2; exit }')"
if [[ -z "$SIM_ID" ]]; then
  ios_tests_status="skipped(no-simulator)"
  echo "No available iPhone simulator found; skipping iOS tests." >&2
  if [[ "$STRICT_IOS_TESTS" == "1" && "$ALLOW_SKIP_IOS_TESTS" != "1" ]]; then
    echo "Strict mode enabled: set ALLOW_SKIP_IOS_TESTS=1 to bypass on this machine." >&2
    print_summary
    exit 1
  fi
else
  xcodebuild -scheme readytoorder -derivedDataPath "$DERIVED_DATA_DIR" -destination "id=$SIM_ID" test -only-testing:readytoorderTests/ReadytoorderCoreTests > "$ROOT_DIR/build_ios_tests.log" 2>&1
  ios_tests_status="passed"
fi
if command -v rg >/dev/null 2>&1; then
  rg -n "error:|warning:" "$ROOT_DIR/build_ios_tests.log" || true
fi

echo "== Backend tests =="
PY_BIN="$BACKEND_DIR/.venv/bin/python"
if [[ ! -x "$PY_BIN" ]]; then
  PY_BIN="python3"
fi

"$PY_BIN" -c "import pytest" 2>/dev/null || {
  echo "pytest is not installed for $PY_BIN. Install with: pip install -r backend/requirements-dev.txt" >&2
  exit 1
}

cd "$BACKEND_DIR"
"$PY_BIN" -m pytest tests -q
backend_status="passed"

print_summary
echo "Preflight completed."
