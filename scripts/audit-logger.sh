#!/bin/bash
# PostToolUse / PostToolUseFailure hook: Log important (state-changing) tool calls
# Records only after execution, capturing success/failure status
# Skips read-only/exploration tools and commands

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

LOG_FILE="$HOME/.claude/audit-logs/${SESSION_ID}.log"

# Ensure log file exists
if [[ ! -f "$LOG_FILE" ]]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Determine success/failure
IS_FAIL=false
if [[ "$EVENT_NAME" == "PostToolUseFailure" ]]; then
  IS_FAIL=true
fi

case "$TOOL_NAME" in
  Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    if [[ "$IS_FAIL" == "true" ]]; then
      echo "[${TIMESTAMP}] [CREATE:FAIL] ${FILE_PATH}" >> "$LOG_FILE"
    else
      echo "[${TIMESTAMP}] [CREATE] ${FILE_PATH}" >> "$LOG_FILE"
    fi
    ;;
  Edit|MultiEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    if [[ "$IS_FAIL" == "true" ]]; then
      echo "[${TIMESTAMP}] [EDIT:FAIL] ${FILE_PATH}" >> "$LOG_FILE"
    else
      echo "[${TIMESTAMP}] [EDIT] ${FILE_PATH}" >> "$LOG_FILE"
    fi
    ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$CMD" ]] && exit 0
    # Normalize: strip leading whitespace + flatten multiline for skip-pattern matching and log parsing
    CMD=$(echo "$CMD" | tr '\n' ' ' | sed 's/^[[:space:]]*//; s/  */ /g')

    # Always log if command contains file redirects (even if starts with skip pattern)
    HAS_REDIRECT=false
    if echo "$CMD" | grep -qE ' > | >>|[^|]\|[[:space:]]*tee '; then
      HAS_REDIRECT=true
    fi

    # Skip read-only / exploration commands (unless they redirect to files)
    if [[ "$HAS_REDIRECT" == "false" ]]; then
      if echo "$CMD" | grep -qE "^(ls|cat |head |tail |less |more |grep |rg |find |echo |printf |pwd|which |type |file |wc |stat |diff |test |\[|true|false|cd |env$|printenv|hostname|uname|date$|whoami|id$|command -v|git (log|status|show|diff|branch|describe|remote -v|rev-parse|config --get|tag -l)|java (-version|--version)|node (-v|--version)|npm (-v|--version|ls|list|view|info|outdated)|\.\/gradlew (dependencies|tasks|properties|help)|sort |uniq |tr |cut |awk |sed -n|jq )"; then
        exit 0
      fi
    fi

    if [[ "$IS_FAIL" == "true" ]]; then
      echo "[${TIMESTAMP}] [BASH:FAIL] ${CMD}" >> "$LOG_FILE"
    else
      echo "[${TIMESTAMP}] [BASH] ${CMD}" >> "$LOG_FILE"
    fi
    ;;
esac

exit 0
