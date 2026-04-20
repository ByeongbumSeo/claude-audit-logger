# Changelog

All notable changes to claude-audit-logger are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/ByeongbumSeo/claude-audit-logger/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ByeongbumSeo/claude-audit-logger/releases/tag/v1.0.0
