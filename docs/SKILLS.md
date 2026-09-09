# 이 환경에서 쓰는 스킬 목록

herald-ai 를 쓰는 맥에는 **세 갈래의 스킬**이 올라갑니다. 어디서 오는지, 왜 쓰는지가 이 문서의 내용입니다.

> **살아 있는 목록은 명령으로 뽑습니다.** 이 문서는 *역할과 출처*를 설명하고, 실제로 지금
> 이 맥에 무엇이 로드돼 있는지는 아래 명령이 답합니다 (문서와 현실이 어긋날 일이 없습니다).
>
> ```bash
> bash bootstrap/herald-env-setup.sh --list-skills
> ```

| 갈래 | 출처 | 설치 | 필수 |
|---|---|---|:---:|
| herald-ai 스킬 | 이 저장소 `skills/` | `bash install.sh` | ✅ |
| oh-my-claudecode(OMC) 스킬·에이전트 | OMC 플러그인 | `bash bootstrap/herald-env-setup.sh --apply` | ✅ |
| superpowers 스킬 | superpowers 마켓플레이스 또는 `~/.claude/skills/superpowers/` | 선택 | — |

---

## 1. herald-ai 스킬 — 이 저장소가 설치한다

| 스킬 | 하는 일 |
|---|---|
| `task-tracker` | **모든 작업의 시작·종료를 기록**하고 텔레그램·데스크톱 알림을 보낸다. 소요시간·토큰·비용을 함께 붙인다. 알림 본문은 Claude 가 `notify-ctx.sh` 로 남긴 요약에서 온다 |
| `telegram-notify` | 텔레그램 전송 계층 (`task-tracker` 가 호출) |
| `trip-ledger` | 여행·출장 지출을 노트 → 구글시트 원장 → 구글맵 목록으로 잇는 파이프라인. **막힌 길을 다시 가지 않도록** `LESSONS.md` 에 검증된 경로·재시도 금지 경로를 쌓는다 |

슬래시 커맨드 (`commands/` → `~/.claude/commands/`):

| 커맨드 | 하는 일 |
|---|---|
| `/session-log [필터]` | 이번 세션 작업을 일자·시간별로 **화면에만** 표시 (파일 미생성) |
| `/session-save [필터]` | 세션 작업기록 MD 를 herald-vault 에 저장. 직전 `/session-log` 의 필터 범위를 인계 |

## 2. oh-my-claudecode(OMC) — 작업 엔진

플러그인이 제공하는 스킬 40여 개와 에이전트 19 개. **이 환경의 일하는 방식 자체**입니다.
전체 목록은 `--list-skills` 로 뽑고, 여기서는 자주 쓰는 갈래만 적습니다.

| 갈래 | 스킬 | 쓰임 |
|---|---|---|
| 실행 | `autopilot` · `ralph` · `ultrawork` · `team` · `ultraqa` | 자율 실행 · 반복 루프 · 병렬 처리 · 다중 에이전트 |
| 계획 | `plan` · `ralplan` · `deep-interview` · `deep-dive` | 착수 전 요구사항 정리와 합의 |
| 조사 | `trace` · `debug` · `external-context` · `sciomc` | 인과 추적 · 문서 조사 · 데이터 분석 |
| 지식 | `wiki` · `remember` · `learner` · `skillify` | 세션을 넘겨 쌓이는 기록, 반복 작업의 스킬화 |
| 환경 | **`hud`** · `omc-setup` · `omc-doctor` · `mcp-setup` | 상태줄 · 설치 · 진단 |
| 검증 | `verify` · `visual-verdict` | 완료 주장 전 확인 |

에이전트(19): `architect` `planner` `critic` `analyst` `executor` `debugger` `tracer` `verifier`
`code-reviewer` `security-reviewer` `test-engineer` `qa-tester` `explore` `designer` `scientist`
`document-specialist` `git-master` `code-simplifier` `writer`

MCP 툴도 함께 붙습니다 — LSP(정의·참조·진단·리네임) · wiki · notepad · project-memory ·
`ast_grep` · `python_repl` · 세션 검색.

> **HUD 도 OMC 스킬입니다** (`hud`). 상태줄 설정은 [ENVIRONMENT.md](ENVIRONMENT.md#2-hud-상태줄--기준-설정) 참조.

## 3. superpowers — 작업 규율 (선택)

작업의 *방법*을 강제하는 스킬 묶음입니다. 없어도 herald-ai 는 동작합니다.

`brainstorming` · `writing-plans` · `executing-plans` · `test-driven-development` ·
`systematic-debugging` · `verification-before-completion` · `requesting-code-review` ·
`receiving-code-review` · `subagent-driven-development` · `dispatching-parallel-agents` ·
`using-git-worktrees` · `finishing-a-development-branch` · `writing-skills` · `using-superpowers`

기준 스냅샷에서는 마켓플레이스 설치가 아니라 `~/.claude/skills/superpowers/` 에 놓인
**skills-dir 플러그인**으로 로드됩니다. 두 경로 중 하나만 씁니다.

---

## 새 맥에서 이 목록을 재현하려면

```bash
bash install.sh                              # 1갈래 (herald-ai 스킬·커맨드)
bash bootstrap/herald-env-setup.sh --apply   # 2갈래 (OMC) + HUD 설정
bash bootstrap/herald-env-setup.sh --apply --all   # 3갈래(superpowers)까지
bash bootstrap/herald-env-setup.sh --list-skills   # 결과 확인
```

설치 순서·이유·HUD 기준값은 [ENVIRONMENT.md](ENVIRONMENT.md),
값의 단일 출처는 [`config/environment.manifest.json`](../config/environment.manifest.json) 입니다.
