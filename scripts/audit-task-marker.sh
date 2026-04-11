#!/bin/bash
# UserPromptSubmit hook: Mark task boundaries in audit log
# Writes user prompt as a separator line between task groups

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

LOG_FILE="$HOME/.claude/audit-logs/${SESSION_ID}.log"

# Ensure log file exists
if [[ ! -f "$LOG_FILE" ]]; then
  exit 0
fi

# Extract user message (handle both string and array content)
CONTENT=$(echo "$INPUT" | jq -r '
  if .message.content | type == "string" then
    .message.content
  elif .message.content | type == "array" then
    [.message.content[] | select(.type == "text") | .text] | join(" ")
  else
    ""
  end
' 2>/dev/null)

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
