# claude-audit-logger

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Claude Code bypass-permissions 모드를 위한 제로 코스트 감사 로그.**

[English](README.md)

---

## Why?

`--dangerously-skip-permissions`로 Claude Code를 실행하면 모든 도구 호출이 자동 승인됩니다. 긴 세션이 끝난 후 *"정확히 뭘 실행한 거지?"*를 확인할 방법이 없습니다.

**claude-audit-logger**는 파일 생성, 수정, 셸 명령 등 상태를 변경하는 모든 명령을 토큰 비용 0, 컨텍스트 주입 0으로 기록합니다.

## Quick Start

### 설치

```bash
# 마켓플레이스 추가
/plugin marketplace add ByeongbumSeo/claude-audit-logger

# 플러그인 설치
/plugin install claude-audit-logger
```

### 동작 확인

새 세션을 열고 아무 파일을 수정한 뒤:

```
/audit
```

방금 실행한 명령이 표시되면 정상 동작입니다.

## 사용법

| 명령 | 설명 |
|------|------|
| `/audit` | 직전 작업 (마지막 프롬프트 이후 명령들) |
| `/audit session` | 현재 세션 전체 |
| `/audit today` | 오늘 모든 세션 |
| `/audit --success` | 성공한 명령만 |
| `/audit --fail` | 실패한 명령만 |
| `/audit session --fail` | 세션 전체 중 실패만 |

## 동작 원리

```
사용자 프롬프트  →  UserPromptSubmit  →  작업 구분선 기록
                        ↓
Claude 도구 실행  →  실행 완료  →  PostToolUse (성공 기록)
                               →  PostToolUseFailure (실패 기록)

세션 시작  →  SessionStart  →  로그 초기화, 세션 ID 설정
```

모든 Hook은 셸 스크립트(`command` 타입)로 실행됩니다. 디스크의 로그 파일에 기록만 하며, Claude 컨텍스트에는 **아무것도 주입하지 않습니다**.

### 기록 대상

| 유형 | 트리거 | 예시 |
|------|--------|------|
| `CREATE` | Write 도구 | `/abs/path/to/new-file.java` |
| `EDIT` | Edit / MultiEdit 도구 | `/abs/path/to/file.java` |
| `BASH` | Bash 도구 (상태 변경) | `./gradlew test` |

읽기 전용 명령(`ls`, `cat`, `grep`, `git status` 등)은 기본적으로 **제외**됩니다. 파일 리다이렉트(`>`, `>>`, `tee`)가 포함된 명령은 읽기 명령이어도 항상 기록됩니다.

### 로그 형식

```
# Session: abc123 | Started: 2026-04-08 14:30:00 | /Users/.../my-project

=== [2026-04-08 14:30:05] MemberService에 findByIdx 추가해 ===
[2026-04-08 14:30:12] [EDIT] src/main/.../MemberService.java
[2026-04-08 14:30:25] [BASH] ./gradlew test
[2026-04-08 14:30:50] [BASH:FAIL] ./gradlew test --tests BrokenTest

=== [2026-04-08 14:35:00] 테스트 코드 보강해 ===
[2026-04-08 14:35:10] [CREATE] src/test/.../MemberServiceTest.java
```

- 성공: `[TYPE]`, 실패: `[TYPE:FAIL]`
- 절대경로 사용 (User scope에서 여러 프로젝트 구분)
- 세션 헤더에 cwd 포함

### 토큰 비용

| 구성 요소 | 토큰 비용 | 빈도 |
|-----------|----------|------|
| Hook 실행 (3개 스크립트) | **0** (셸 스크립트) | 매 도구 호출 |
| `/audit` 조회 | Read 도구 비용 | 수동 호출 시만 |

### 로그 저장 위치

```
~/.claude/audit-logs/
├── {sessionId}.log
└── ...
```

- 세션별 독립 파일
- 14일 이상 로그는 세션 시작 시 자동 삭제
- 멀티세션 안전: 세션별 `CLAUDE_ENV_FILE` 기반 — 공유 포인터 없음, 경합 없음

> **참고**: 작업 구분선에는 프롬프트 텍스트의 앞부분(최대 100자)이 포함됩니다.
> 로그는 로컬에 평문으로 저장되므로, 프롬프트에 민감한 정보(비밀번호, 토큰, API 키)를 직접 입력하지 않는 것을 권장합니다.

## 요구 사항

- Claude Code CLI
- `jq` (JSON 파싱)
- macOS 또는 Linux
- `--dangerously-skip-permissions` 사용자 권장

## FAQ

**Q: 일반 모드에서도 필요한가요?**
A: 아닙니다. 권한 확인 팝업이 이미 감사 역할을 합니다. bypass-permissions 사용자를 위한 플러그인입니다.

**Q: 멀티세션에서 로그가 섞이나요?**
A: 아닙니다. `CLAUDE_ENV_FILE` 기반으로 세션별 격리됩니다. 각 세션이 독립된 로그 파일에 기록합니다.

**Q: 기존 Hook 설정과 충돌하나요?**
A: 아닙니다. Claude Code는 같은 이벤트에 여러 Hook을 등록할 수 있습니다. 기존 Hook과 함께 동작합니다.

**Q: 디스크 공간은 많이 차지하나요?**
A: 거의 없습니다. 로그는 plain text이며 세션당 보통 수 KB입니다. 14일 이상 로그는 자동 삭제됩니다.

## License

[MIT](LICENSE)
