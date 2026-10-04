#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-$PWD}"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/detect-active-spec.sh"

detect_sdd_project "$CWD" || exit 0

STATE_FILE="${TMPDIR:-/tmp}/sdd-state-${SESSION_ID}.json"
HAD_WRITES=false

if [ -f "$STATE_FILE" ]; then
  HAD_WRITES=$(jq -r '.had_writes // false' "$STATE_FILE" 2>/dev/null || echo "false")
  rm -f "$STATE_FILE" 2>/dev/null || true
fi

[[ "$HAD_WRITES" = "true" ]] || exit 0

# One reminder per turn, not one per attempt. Claude Code sets
# stop_hook_active while it is already continuing because of a Stop hook;
# without this guard, saving the memory we just asked for re-arms the flag
# and the reminder bounces back on the next Stop.
[[ "$STOP_HOOK_ACTIVE" = "true" ]] && exit 0

MESSAGE="Session end — invoke session-wrap to capture memory and lessons:
  - feedback: approach corrections or validations received this session?
  - project: status, goal, or deadline changes?
  - user: new preferences or expertise observed?
  - reference: external resources encountered?

Verification: run verification-before-completion before claiming any work is done."

jq -n --arg msg "$MESSAGE" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: $msg
  }
}'
