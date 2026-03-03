# ReadyToOrder D9-D10 Preflight Checklist

## 1) One-command preflight

From repo root:

```bash
./scripts/preflight.sh
```

Default behavior:
- Runs iOS build (`xcodebuild`, Simulator target).
- Runs iOS unit tests (`readytoorderTests/ReadytoorderCoreTests`) if an available iPhone simulator exists.
- Runs backend smoke tests (`backend/tests` via pytest).
- Fails by default if iOS tests are skipped because no simulator is available.

Temporary override for simulator-less environments:

```bash
ALLOW_SKIP_IOS_TESTS=1 ./scripts/preflight.sh
```

Use the override only for non-release local checks. Release gate should keep strict mode.

## 2) Required pass conditions before TestFlight upload

1. `iOS build: passed`
2. `iOS tests: passed` (no skip for release gate)
3. `Backend tests: passed`
4. `build.log` contains no release-blocking errors

## 3) Manual regression sweep (minimum)

1. Cold start first-use flow works in three paths:
   - permission not requested
   - permission denied
   - permission granted then retry
2. Network degradation paths:
   - offline
   - weak network
   - backend `429`, `502`
3. Image upload stress:
   - continuous uploads
   - oversized image
   - duplicate image
4. Upgrade install:
   - profile/chat data restores, or degrades safely

## 4) Common failures

1. `No available iPhone simulator found`:
   - install an iOS simulator runtime in Xcode
   - rerun strict preflight without `ALLOW_SKIP_IOS_TESTS=1`
2. Backend test import errors:
   - use venv python explicitly:
   - `cd backend && .venv/bin/python -m pytest tests -q`
3. `CoreSimulatorService connection became invalid`:
   - restart CoreSimulator / Xcode
   - retry preflight

