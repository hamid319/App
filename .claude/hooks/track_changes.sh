#!/bin/bash
# PostToolUse hook — records files modified this turn.
TRACKING="$(cd "$(dirname "$0")/.." && pwd)/.turn_changes"
INPUT=$(cat)
FILE=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    fp = d.get('tool_input', {}).get('file_path', '')
    if fp:
        print(fp)
except Exception:
    pass
" <<< "$INPUT" 2>/dev/null)
[ -n "$FILE" ] && echo "$FILE" >> "$TRACKING"
exit 0
