# Changelog

All notable changes to claude-audit-logger are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.2] - 2026-04-21

### Fixed

- **`/audit task` was permanently empty after 1.1.1** (#20) — `scripts/audit-task-marker.sh` wrote a `=== [ts] /audit ... ===` separator for every `UserPromptSubmit`, including invocations of `/audit` itself. Since `/audit task` is defined as "entries after the last separator", the skill always observed its own invocation as the task boundary and returned an empty result. The prior `.message.content` bug in 1.1.0 masked this because no separators were written at all — task mode effectively showed the whole session. The hook now skips separator writing when `.prompt` matches `^/(claude-audit-logger:)?audit(-doctor)?(\s|$)`, so the previous real user task remains the nearest boundary. Consecutive `/audit` calls also behave correctly (each one shows the same preceding task instead of an empty window).

## [1.1.1] - 2026-04-21

### Fixed

- **`UserPromptSubmit` hook read the wrong payload field** (#15) — `scripts/audit-task-marker.sh` extracted the user prompt from `.message.content`, but Claude Code's actual `UserPromptSubmit` payload places the prompt at top-level `.prompt` (string). `CONTENT` was always empty, the length-2 guard tripped, and the script silently exited without writing the `=== ... ===` task separator. `/audit` task mode was effectively non-functional since 1.0.0. Now reads `.prompt` directly and drops the `2>/dev/null` that masked the silent schema mismatch.
- **Multi-line prompts split the task separator across log lines** — surfaced as a follow-up after the `.prompt` fix above made `CONTENT` non-empty for the first time. A pasted multi-line prompt produced `=== [ts] line1\nline2 ===` rendered as two log lines, which broke `/audit` task-mode boundary detection. Embedded newlines and carriage returns now collapse to spaces before the line is written.
- **Non-string `.prompt` produced fake separators** — defensive guard surfaced in pre-merge review. If Claude Code ever sends `.prompt` as an integer or boolean, `jq -r` coerces it to its string form (`"42"`, `"true"`) which passes the length-2 guard and writes a misleading separator. A jq type guard now collapses non-strings to `""`.

### Removed

- **Manual `(claude-audit-logger)` description prefix on plugin skills** (#16) — added in 1.1.0 so users could identify plugin ownership in the skill list, but Claude Code already prepends the plugin name automatically for plugin-owned skills, producing duplicate prefixes (`(claude-audit-logger) (claude-audit-logger) ...`) in the slash menu. The manual prefix has been removed from `skills/audit/SKILL.md` and `skills/audit-doctor/SKILL.md`.

## [1.1.0] - 2026-04-20

### Added

- **`/audit-doctor` skill** — comprehensive health check that diagnoses six common failure modes (missing jq, hook script files absent or non-executable, SessionStart hook did not fire, missing log directory, missing current session log, jq parsing smoke test) and surfaces actionable fix commands in priority order.
- **Diagnostic guidance in `/audit`** — when the log file is missing, `/audit` now runs a quick `jq` + `AUDIT_SESSION_ID` check and shows a specific remediation message (install jq, restart Claude Code, or run `/audit-doctor`) instead of the previous generic "log not created yet" message.
- **`.claude-plugin/marketplace.json`** — enables `/plugin marketplace add ByeongbumSeo/claude-audit-logger` (the command documented in README) to succeed. Without this file the install flow failed for every new user. (#11)
- **README Prerequisites section** — `jq` installation commands for macOS/Debian/Fedora/Arch placed above the install step, plus an explicit reminder to restart Claude Code after install so the SessionStart hook fires in a new session.
- **`/audit` output example** — README now shows what the rendered audit table looks like, complementing the existing raw log format documentation.
- **`(claude-audit-logger)` description prefix** on all skills so users can identify plugin ownership in the skill list.

### Changed

- **SESSION_ID sanitization** — switched from denylist (`tr -d '/.\\'`) to allowlist (`tr -cd 'a-zA-Z0-9_-'`). The allowlist also blocks spaces, semicolons, null bytes, and other vectors the denylist missed.
- **Performance**: consolidated three separate `jq` calls into a single `@tsv` invocation in `audit-logger.sh` and `audit-session-init.sh`, reducing subprocess overhead on the hot path.
- **Refactor**: merged the two CMD normalization passes (leading whitespace strip + multiline flatten) in `audit-logger.sh` into a single `tr | sed` pipeline.

### Fixed

- **Multiline bash commands corrupted the log** (#4) — `heredoc` or `&&` newlines produced multi-line entries that `/audit` could not parse. Commands are now flattened to a single line before logging.
- **Skip regex allowed state-changing commands** (#5) — `javac` (compiler) and `mkdir -p $HOME` / `mkdir -p ~/` (directory creation) were incorrectly in the read-only skip list and went unrecorded. These have been removed. The duplicate `command -v` entry in the regex has also been cleaned up.
- **Leading whitespace bypassed skip pattern matching** (#5) — `  rm -rf /` (leading spaces) evaded the `^` anchor. Commands are now stripped of leading whitespace before matching.
- **`SESSION_ID` was unquoted in env export** (#6) — `echo "export AUDIT_SESSION_ID=$SESSION_ID"` could break on special characters. The value is now double-quoted when written to `CLAUDE_ENV_FILE`.
- **Missing `jq` caused silent noise instead of graceful exit** (#7) — all three scripts now guard with `command -v jq &>/dev/null || exit 0` before reading stdin, eliminating stderr error spam when `jq` is absent.
- **`SESSION_ID` path traversal** (#8) — a session ID containing `../` could cause log writes outside `~/.claude/audit-logs/`. Now sanitized (see _Changed_).
- **Plaintext prompt logging was not disclosed** (#9) — README now notes that task separator lines include up to 100 characters of prompt text, and advises against pasting secrets into prompts.
- **`marketplace.json` schema** (PR #12 review) — `plugins[0].source` corrected from `"."` to `"./"` which is what the Claude Code schema requires (discovered during local install test).

### Security

- Defense-in-depth against path traversal and shell injection in session ID handling (see _Changed_ and _Fixed_ above).

## [1.0.0] - 2026-04-11

### Added

- Initial release.
- Four hooks: `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure` with zero token overhead.
- `/audit` skill with task / session / today modes and `--success` / `--fail` filters.
- Per-session log isolation via `CLAUDE_ENV_FILE`.
- Automatic cleanup of logs older than 14 days.
- English and Korean README.

[1.1.2]: https://github.com/ByeongbumSeo/claude-audit-logger/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/ByeongbumSeo/claude-audit-logger/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ByeongbumSeo/claude-audit-logger/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ByeongbumSeo/claude-audit-logger/releases/tag/v1.0.0
