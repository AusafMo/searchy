#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Use dev venv if it exists, otherwise bootstrap one
VENV="$PROJECT_ROOT/.venv"
if [ ! -f "$VENV/bin/python3" ]; then
    echo "→ Creating dev venv..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q ruff pytest
fi
PYTHON="$VENV/bin/python3"

FAILED=0
START=$(date +%s)

echo "═══ Pre-push checks ═══"

# 1. Syntax check
echo -n "• py_compile... "
for f in searchy/*.py; do
    $PYTHON -m py_compile "$f" || FAILED=1
done
[ $FAILED -eq 0 ] && echo "ok" || echo "FAIL"

# 2. Ruff lint
echo -n "• ruff... "
"$VENV/bin/ruff" check searchy/*.py --quiet || FAILED=1
[ $FAILED -eq 0 ] && echo "ok" || echo "FAIL"

# 3. Tests
echo -n "• pytest... "
$PYTHON -m pytest searchy/tests/ -x -q || FAILED=1

# 4. Swift build (skip with SKIP_SWIFT=1)
if [ "${SKIP_SWIFT:-0}" != "1" ]; then
    echo -n "• xcodebuild... "
    if xcodebuild -project searchy.xcodeproj -scheme searchy -configuration Debug build -quiet 2>&1; then
        echo "ok"
    else
        echo "FAIL"
        FAILED=1
    fi
else
    echo "• xcodebuild... skip (SKIP_SWIFT=1)"
fi

END=$(date +%s)
echo "═══ Done in $((END - START))s ═══"

exit $FAILED
