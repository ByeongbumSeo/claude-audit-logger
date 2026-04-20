#!/bin/bash
# SessionStart hook: Initialize or resume audit log for this session
# - startup: create new log file with header (includes cwd)
# - resume: ensure file exists, append resume marker
# - clear/compact: append marker only

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
IFS=$'\t' read -r SESSION_ID EVENT_TYPE CWD <<< \
  "$(echo "$INPUT" | jq -r '[.session_id // "", .source // "startup", .cwd // ""] | @tsv')"

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

LOG_DIR="$HOME/.claude/audit-logs"
LOG_FILE="$LOG_DIR/${SESSION_ID}.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Expose session ID to all Bash commands via CLAUDE_ENV_FILE
# This allows /audit skill to identify the correct session without shared pointer files
if [[ -n "$CLAUDE_ENV_FILE" ]]; then
  echo "export AUDIT_SESSION_ID=\"$SESSION_ID\"" >> "$CLAUDE_ENV_FILE"
fi

# Cleanup logs older than 14 days
find "$LOG_DIR" -name "*.log" -mtime +14 -delete 2>/dev/null

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

case "$EVENT_TYPE" in
  resume)
    if [[ -f "$LOG_FILE" ]]; then
      echo "" >> "$LOG_FILE"
      echo "--- Resumed: ${TIMESTAMP} | ${CWD} ---" >> "$LOG_FILE"
    else
      echo "# Session: ${SESSION_ID} | Started: ${TIMESTAMP} | ${CWD} (resumed, previous log missing)" > "$LOG_FILE"
    fi
    ;;
  clear)
    if [[ -f "$LOG_FILE" ]]; then
      echo "" >> "$LOG_FILE"
      echo "--- Cleared: ${TIMESTAMP} ---" >> "$LOG_FILE"
    fi
    ;;
  compact)
    # Context compaction — no action needed for audit
    ;;
  *)
    # startup (default): create new log file
    echo "# Session: ${SESSION_ID} | Started: ${TIMESTAMP} | ${CWD}" > "$LOG_FILE"
    ;;
esac

exit 0
