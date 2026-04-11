---
name: audit
description: View audit logs of auto-approved commands (file creates/edits, bash executions) by task, session, or today. Use when you see keywords like 'audit', 'audit log', 'command log', 'what did it do', 'trace log'.
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

- No log file: "Audit log has not been created yet. It will start recording from the next session."
- Log file exists but no entries: "No important commands recorded. (Exploration commands are not logged)"
- Filter returns empty: "No commands matching the filter." (e.g., `--fail` but no failures)
