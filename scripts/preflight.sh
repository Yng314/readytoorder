#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

echo "== iOS build =="
xcodebuild -scheme readytoorder -destination 'generic/platform=iOS Simulator' build > "$ROOT_DIR/build.log" 2>&1
if command -v rg >/dev/null 2>&1; then
  rg -n "error:|warning:" "$ROOT_DIR/build.log" || true
fi

echo "== iOS tests =="
: > "$ROOT_DIR/build_ios_tests.log"
SIM_ID="$({ xcrun simctl list devices available 2>/dev/null || true; } | sed -nE 's/^[[:space:]]*iPhone[^\\(]*\\(([0-9A-F-]+)\\).*/\\1/p' | head -n 1)"
if [[ -z "$SIM_ID" ]]; then
  echo "No available iPhone simulator found; skipping iOS tests." >&2
else
  xcodebuild -scheme readytoorder -destination "id=$SIM_ID" test -only-testing:readytoorderTests/ReadytoorderCoreTests > "$ROOT_DIR/build_ios_tests.log" 2>&1
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

echo "Preflight completed."
