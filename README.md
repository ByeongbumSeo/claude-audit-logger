# claude-audit-logger

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Zero-cost audit trail for Claude Code bypass-permissions mode.**

[한국어](README.ko.md)

---

## Why?

When you run Claude Code with `--dangerously-skip-permissions`, every tool call is auto-approved. After a long session, there's no easy way to answer: *"What exactly did it execute?"*

**claude-audit-logger** silently records every state-changing command — file creates, edits, and shell executions — with zero token cost and zero context injection.

## Quick Start

### Install

```bash
# Add marketplace
/plugin marketplace add ByeongbumSeo/claude-audit-logger

# Install plugin
/plugin install claude-audit-logger
```

### Verify

Open a new session, edit any file, then run:

```
/audit
```

If you see the command you just executed, it's working.

## Usage

| Command | Description |
|---------|-------------|
| `/audit` | Last task (commands since most recent prompt) |
| `/audit session` | Entire current session |
| `/audit today` | All sessions from today |
| `/audit --success` | Only successful commands |
| `/audit --fail` | Only failed commands |
| `/audit session --fail` | Failed commands from entire session |

## How it works

```
User prompt  →  UserPromptSubmit  →  Task separator recorded
                      ↓
Claude tool  →  Tool completes    →  PostToolUse (success logged)
                                  →  PostToolUseFailure (failure logged)

Session start  →  SessionStart    →  Log initialized, session ID set
```

All hooks run as shell scripts (`command` type). They write to log files on disk and inject **nothing** into Claude's context.

### What gets logged

| Type | Trigger | Example |
|------|---------|---------|
| `CREATE` | Write tool | `/abs/path/to/new-file.java` |
| `EDIT` | Edit / MultiEdit tool | `/abs/path/to/file.java` |
| `BASH` | Bash tool (state-changing) | `./gradlew test` |

Read-only commands (`ls`, `cat`, `grep`, `git status`, etc.) are **excluded** by default. Commands with file redirects (`>`, `>>`, `tee`) are always logged even if they start with a read-only pattern.

### Log format

```
# Session: abc123 | Started: 2026-04-08 14:30:00 | /Users/.../my-project

=== [2026-04-08 14:30:05] Add findByIdx to MemberService ===
[2026-04-08 14:30:12] [EDIT] src/main/.../MemberService.java
[2026-04-08 14:30:25] [BASH] ./gradlew test
[2026-04-08 14:30:50] [BASH:FAIL] ./gradlew test --tests BrokenTest

=== [2026-04-08 14:35:00] Write tests ===
[2026-04-08 14:35:10] [CREATE] src/test/.../MemberServiceTest.java
```

- Success: `[TYPE]`, Failure: `[TYPE:FAIL]`
- Absolute paths (to distinguish across projects in user scope)
- Session header includes cwd

### Token cost

| Component | Token cost | Frequency |
|-----------|-----------|-----------|
| Hook execution (all 3 scripts) | **0** (shell scripts) | Every tool call |
| `/audit` query | Read tool cost | On-demand only |

### Log storage

```
~/.claude/audit-logs/
├── {sessionId}.log
└── ...
```

- One file per session
- Logs older than 14 days are automatically deleted on session start
- Multi-session safe: each session uses its own `CLAUDE_ENV_FILE` — no shared pointers, no race conditions

> **Note**: Task separator lines include a truncated snippet (up to 100 characters) of your prompt text.
> Since logs are stored locally in plain text, avoid pasting sensitive information (passwords, tokens, API keys) directly into prompts.

## Requirements

- Claude Code CLI
- `jq` (JSON parsing)
- macOS or Linux
- Recommended for `--dangerously-skip-permissions` users

## FAQ

**Q: Do I need this in normal (interactive) mode?**
A: No. The permission confirmation dialog already serves as an audit trail. This plugin is for bypass-permissions users.

**Q: Will logs from multiple sessions get mixed up?**
A: No. Session isolation is based on `CLAUDE_ENV_FILE`, so each session writes to its own log file independently.

**Q: Will this conflict with my existing hooks?**
A: No. Claude Code supports multiple hooks on the same event. This plugin's hooks will run alongside yours.

**Q: How much disk space do logs use?**
A: Minimal. Logs are plain text, typically a few KB per session. Old logs (>14 days) are auto-deleted.

## License

[MIT](LICENSE)
