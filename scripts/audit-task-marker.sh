#!/bin/bash
# UserPromptSubmit hook: Mark task boundaries in audit log
# Writes user prompt as a separator line between task groups

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

LOG_FILE="$HOME/.claude/audit-logs/${SESSION_ID}.log"

# Ensure log file exists
if [[ ! -f "$LOG_FILE" ]]; then
  exit 0
fi

# Extract user prompt text (UserPromptSubmit payload: top-level .prompt is a string).
# Type guard: non-strings (int/bool) collapse to "" so the length check below skips them.
CONTENT=$(echo "$INPUT" | jq -r '.prompt | if type == "string" then . else "" end')

# Flatten newlines/carriage returns so the "=== ... ===" separator stays on a single log line.
# Without this, a multi-line prompt (e.g. pasted code) splits the separator across multiple
# lines and breaks /audit task-mode boundary detection.
CONTENT=$(echo "$CONTENT" | tr '\n\r' ' ')

# Skip separator writing for audit meta-skill invocations.
# /audit and /audit-doctor are read-only view skills; if we wrote a separator for them,
# `/audit task` would treat its own invocation as the task boundary and always return empty.
if [[ "$CONTENT" =~ ^/(claude-audit-logger:)?audit(-doctor)?([[:space:]]|$) ]]; then
  exit 0
fi

# Truncate to 100 chars for readability
if [[ ${#CONTENT} -gt 100 ]]; then
  CONTENT="${CONTENT:0:100}..."
fi

# Skip empty or very short prompts (likely commands)
if [[ ${#CONTENT} -lt 2 ]]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "" >> "$LOG_FILE"
echo "=== [${TIMESTAMP}] ${CONTENT} ===" >> "$LOG_FILE"

exit 0
