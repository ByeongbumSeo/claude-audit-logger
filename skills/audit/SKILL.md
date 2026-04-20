---
name: audit
description: (claude-audit-logger) View audit logs of auto-approved commands (file creates/edits, bash executions) by task, session, or today. Use when you see keywords like 'audit', 'audit log', 'command log', 'what did it do', 'trace log'.
user_invocable: true
argument-hint: "[task|session|today] [--success|--fail]"
---

# Audit Log Viewer

View audit logs of important auto-approved commands (file creates/edits/deletes, git, builds, etc.) during a session.

## Usage

- `/audit` or `/audit task` - Last task (commands since the most recent prompt)
- `/audit session` - Entire current session log
- `/audit today` - All sessions from today
- `/audit --success` - Only successful commands
- `/audit --fail` - Only failed commands
- `/audit session --fail` - Failed commands from entire session

## Procedure

### 1. Parse arguments

Determine mode and filter from `$ARGUMENTS`:

**Mode:**
- Empty or `task` - **task mode**
- `session` - **session mode**
- `today` - **today mode**

**Filter (optional, combinable with mode):**
- `--success` - Show only successful entries (no `:FAIL`)
- `--fail` - Show only failed entries (contains `:FAIL`)
- No filter - Show all (default)

### 2. Get current session ID

Get session ID from environment variable via Bash tool:

```bash
echo $AUDIT_SESSION_ID
```

This variable is set per-session via CLAUDE_ENV_FILE by the SessionStart hook. It is isolated per session, safe for multi-session use.

### 3. Retrieve logs by mode

#### task mode (default)
Show only entries **after the last `=== [...]` separator** in the current session log.

```bash
echo $AUDIT_SESSION_ID
```

Read `~/.claude/audit-logs/{AUDIT_SESSION_ID}.log` with Read tool, extract content after the last `===` separator.

If log is empty: "No important commands recorded in this task."

#### session mode
Read the entire current session log file.

```bash
echo $AUDIT_SESSION_ID
```

Read full `~/.claude/audit-logs/{AUDIT_SESSION_ID}.log` with Read tool.

#### today mode
Show all logs from today's date.

```bash
# Today's date
TODAY=$(date '+%Y-%m-%d')

# Find log files containing today's date
grep -l "$TODAY" ~/.claude/audit-logs/*.log
```

Read those files with Read tool, filter to show only separators (`===`) and entries (`[YYYY-MM-DD ...]`) matching today's date.

### 4. Apply filters

After retrieving log entries, apply filter if specified:

- **`--success`**: Exclude lines containing `:FAIL]`. Keep separators (`===`, `---`, `#`).
- **`--fail`**: Keep only lines containing `:FAIL]`. Keep separators (`===`, `---`, `#`).
- **No filter**: Show all entries as-is.

### 5. Output format

Categorize and display:

```
## Audit Log (session mode)

**Session**: abc123 | **Started**: 2026-04-07 14:30:00 | /Users/.../skypeople-api

### Task 1: Add findByIdx to MemberService (14:30:00)
| Time | Type | Target |
|------|------|--------|
| 14:30:05 | EDIT | src/main/.../MemberService.java |
| 14:30:12 | BASH | ./gradlew test |
| 14:30:20 | BASH:FAIL | ./gradlew test --tests BrokenTest |

### Task 2: Write tests (14:35:00)
| Time | Type | Target |
|------|------|--------|
| 14:35:05 | CREATE | src/test/.../MemberServiceTest.java |

**Summary**: 3 succeeded, 1 failed
```

### 6. When no logs exist

Differentiate between expected-empty states and misconfigurations so users know whether to wait, retry, or fix setup.

**6-a. Filter returned empty (normal)**

The log has entries but the filter excluded all of them.

> "No commands matching the filter." (e.g., `--fail` but no failures)

**6-b. Log file exists but has no entries (normal)**

The session started correctly but no state-changing commands have run yet.

> "No important commands recorded yet. (Read-only/exploration commands are not logged.)"

**6-c. Log file is missing → run a quick diagnosis**

Before showing the generic "log not created" message, check two common misconfigurations and surface actionable guidance.

Run both checks with the Bash tool:

```bash
# Check 1: is jq installed?
command -v jq &>/dev/null && echo "jq_ok" || echo "jq_missing"

# Check 2: is the SessionStart hook environment set?
echo "session_id=${AUDIT_SESSION_ID:-<empty>}"
```

Then decide what to show:

| jq | AUDIT_SESSION_ID | Message |
|----|------------------|---------|
| missing | any | "`jq` is not installed — all hook scripts exit silently without it. Install jq: `brew install jq` (macOS) or `sudo apt install jq` (Linux). Then restart Claude Code." |
| ok | empty | "The SessionStart hook did not run in this session. This usually happens when the plugin was installed mid-session. Restart Claude Code to trigger initialization." |
| ok | set | "The SessionStart hook ran but the log file is unexpectedly missing. Run `/audit-doctor` for a full health check." |

Always append a one-line pointer to the full health check skill:

> Run `/audit-doctor` for a comprehensive diagnostic.
