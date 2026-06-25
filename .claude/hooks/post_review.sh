#!/bin/bash
# Stop hook — runs flutter analyze on changed lib/ files; reverts on new errors.
APP=/Users/hamidebrahimi/Desktop/SwipeTrip/App
TRACKING="$APP/.claude/.turn_changes"

[ ! -f "$TRACKING" ] && exit 0

CHANGED=$(sort -u "$TRACKING")
rm -f "$TRACKING"
[ -z "$CHANGED" ] && exit 0

DART_CHANGED=$(echo "$CHANGED" | grep "^$APP/lib/.*\.dart$")
[ -z "$DART_CHANGED" ] && {
  echo "[SwipeTrip Review] Non-Dart changes only — skipping analysis."
  exit 0
}

echo ""
echo "=== SwipeTrip Auto Review ==="
echo "Dart files changed this turn:"
echo "$DART_CHANGED" | sed "s|$APP/||" | sed 's/^/  -> /'
echo ""

cd "$APP" || exit 1

# Analyze only lib/ and exclude build/ artifacts
ERRORS=$(flutter analyze 2>&1 | grep "error •" | grep -v " build/")
ERROR_COUNT=$(echo "$ERRORS" | grep -c "error •" || true)

if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "[PASS] flutter analyze clean (0 errors in lib/)"
  echo ""

  # Highlight known code smells in changed files
  ISSUES=""
  while IFS= read -r f; do
    [ ! -f "$f" ] && continue
    SHORT="${f#$APP/}"
    HIT=$(grep -nE "Image\.network\(|\.like\(\)|TODO|FIXME|Fehler|Zurück|Überspringen|Einstellungen|Datenschutz" "$f" 2>/dev/null)
    [ -n "$HIT" ] && ISSUES="${ISSUES}  ${SHORT}:\n$(echo "$HIT" | sed 's/^/    /')\n"
  done <<< "$DART_CHANGED"

  if [ -n "$ISSUES" ]; then
    echo "[WARNINGS] Review these manually:"
    printf "%b" "$ISSUES"
  else
    echo "[OK] No known code smells detected."
  fi

else
  echo "[FAIL] $ERROR_COUNT new error(s) in lib/:"
  echo "$ERRORS" | sed "s|$APP/||" | sed 's/^/  /'
  echo ""
  echo "Reverting changed Dart files..."

  while IFS= read -r f; do
    [ ! -f "$f" ] && continue
    if git -C "$APP" ls-files --error-unmatch "$f" > /dev/null 2>&1; then
      git -C "$APP" checkout HEAD -- "$f" 2>/dev/null && echo "  [REVERTED] ${f#$APP/}"
    else
      rm -f "$f" && echo "  [REMOVED new file] ${f#$APP/}"
    fi
  done <<< "$DART_CHANGED"

  echo ""
  echo "Fix the errors above and retry."
  exit 1
fi
