---
name: audit-doctor
description: (claude-audit-logger) Diagnose plugin health. Checks jq installation, hook script files, session environment, and log directory. Use when /audit shows no logs or when troubleshooting why the plugin is not recording commands.
user_invocable: true
---

# Audit Doctor

Run health checks on claude-audit-logger plugin installation and surface actionable guidance for common failure modes (missing jq, unregistered hooks, stale session).

## Usage

- `/audit-doctor` - Run all health checks and print a summary with fix suggestions

## Procedure

Run each check with the Bash tool, collect results, then render a single combined report at the end.

### Check 1: jq installation

```bash
if command -v jq &>/dev/null; then
  echo "OK: $(jq --version)"
else
  echo "FAIL: jq not found in PATH"
fi
```

- OK: jq is available
- FAIL: jq is not installed. This is the most common failure mode - all hook scripts exit silently without jq. Remediation:
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt install jq`
  - Fedora/RHEL: `sudo dnf install jq`
  - Arch: `sudo pacman -S jq`

### Check 2: Hook script files

```bash
find ~/.claude -type f \( -name "audit-session-init.sh" -o -name "audit-task-marker.sh" -o -name "audit-logger.sh" \) 2>/dev/null
```

Expected: 3 files found, all with executable bit set.

For each file found, also check executability:

```bash
ls -la <path>
```

- OK: All 3 scripts present and executable (mode includes `x`)
- FAIL (missing): Plugin files not installed. Reinstall: `/plugin marketplace add ByeongbumSeo/claude-audit-logger` then `/plugin install claude-audit-logger@claude-audit-logger`
- FAIL (not executable): `chmod +x <path>`

### Check 3: AUDIT_SESSION_ID environment variable

```bash
echo "${AUDIT_SESSION_ID:-<empty>}"
```

- OK: Non-empty UUID-like string - SessionStart hook ran successfully
- FAIL: Empty - SessionStart hook did not fire in this session. Common causes:
  - Plugin was installed in the middle of this session - restart Claude Code
  - jq missing (see Check 1) - SessionStart script exits silently without jq
  - Hook registration failed - verify Check 2 passes

### Check 4: Log directory

```bash
if [[ -d ~/.claude/audit-logs ]]; then
  echo "OK: $(ls -1 ~/.claude/audit-logs | wc -l | tr -d ' ') file(s)"
else
  echo "FAIL: ~/.claude/audit-logs does not exist"
fi
```

- OK: Directory exists (shows file count)
- FAIL: Directory missing. Created automatically by the SessionStart hook when it runs correctly.

### Check 5: Current session log file

Only run if Check 3 passed.

```bash
LOG="$HOME/.claude/audit-logs/${AUDIT_SESSION_ID}.log"
if [[ -f "$LOG" ]]; then
  echo "OK: $(wc -l < "$LOG" | tr -d ' ') line(s) in $LOG"
else
  echo "FAIL: $LOG does not exist"
fi
```

- OK: Current session log exists
- FAIL: SESSION_ID set but log file missing. Likely the SessionStart hook exited early - check jq (Check 1) and script contents.

### Check 6: jq smoke test

Only run if Check 1 passed. Simulates what the hooks do:

```bash
echo '{"session_id":"test-123","tool_name":"Bash"}' | jq -r '.session_id'
```

- OK: Output is `test-123` - jq works correctly with hook input format
- FAIL: Unexpected output or error - jq is broken (rare; reinstall jq)

## Report format

Combine all check results into a single structured report:

```
## Claude Audit Logger - Health Check

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | jq installation | ✅ / ❌ | <version or error> |
| 2 | Hook scripts | ✅ / ⚠ / ❌ | <count>/3 found, <count> executable |
| 3 | AUDIT_SESSION_ID | ✅ / ❌ | <id or 'empty'> |
| 4 | Log directory | ✅ / ❌ | <file count> |
| 5 | Current session log | ✅ / ❌ / - | <line count or 'n/a'> |
| 6 | jq smoke test | ✅ / ❌ / - | <output or skipped> |

### Diagnosis

<One-paragraph summary of the overall state.>

### Actions

<Numbered list of concrete commands to fix each ❌/⚠ item, in priority order. If all checks pass, state "All systems operational. The plugin is working correctly.">
```

## Prioritization rules

When multiple checks fail, order the fixes this way:

1. Install jq first (Check 1) - fixes most downstream failures
2. Reinstall plugin or fix file permissions (Check 2) - structural fix
3. Restart Claude Code (Check 3) - triggers SessionStart hook
4. Retry `/audit-doctor` to confirm

Do not suggest later fixes before earlier ones are resolved - they may become unnecessary.
