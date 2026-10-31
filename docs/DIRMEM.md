# dirmem · marvis — 디렉토리 이식형 다중 LLM 작업 환경

작업 폴더마다 기억을 **그 폴더 안**에 두고, Claude Code · Codex(ChatGPT) · Gemini/Antigravity 가
같은 기억과 작업 결과를 이어받도록 하는 도구입니다. 폴더를 옮기거나 다른 Mac 에서 열어도
(예: iCloud 동기화 바탕화면) 그대로 이어서 작업합니다. → [메인 README](../README.md)

> **ha-we 와의 관계** — [ha-we](WORK-ENV.md) 는 목적이 정해진 작업 디렉토리 **한 벌을 배포**하고(R1 진입점·R2 디렉토리 안 기억),
> dirmem 은 **아무 폴더에나** 같은 원칙을 가볍게 적용하는 기억 + 실행기다. ha-we 로 뿌린 폴더(`.llm/`)는
> marvis 가 `자체 기억 체계` 로 인식해 dirmem 을 덧씌우지 않는다.

## 역할 분리

| 무엇 | 어디에 | 다른 Mac 으로 |
|------|--------|---------------|
| 실행 도구 (`marvis`, `dirmem`, 규칙 템플릿) | **herald-ai** (`bin/`, `templates/dirmem/`) | `git pull && bash install.sh` |
| 기억·현황·세션 일지 | 작업 폴더 `AI_MEMORY/` | 폴더 동기화(iCloud 바탕화면 등) |
| 대화 원문 (Claude·Codex) | 작업 폴더 `AI_MEMORY/transcripts/` | 폴더 동기화 → 시작 시 자동 복원 |

머신 로컬 기억(`~/.claude/projects/.../memory` 등)은 쓰지 않습니다 — 전파되지 않기 때문입니다
(trip-ledger·ha-we 와 같은 판단).

## 사용법

```bash
cd <작업 폴더>
marvis llm claude           # 또는 codex / gemini. 뒤의 인자는 각 CLI 에 그대로 전달
marvis llm claude -w        # 새 iTerm 창에서 시작
marvis llm claude --resume  # (다른 Mac 에서) 이전 대화 이어 하기 — 폴더 안 사본이 자동 복원됨
marvis llm codex resume     # Codex 이어 하기
marvis llm ls               # 모드 · 실행 중 세션 · 최근 일지
marvis mode [parallel|single|auto]   # 폴더 실행 모드 보기·지정·기본값 복귀
```

### 실행기가 보장하는 것
1. 각 도구의 자체 기억을 실행 옵션으로 끔 (Claude `autoMemoryEnabled=false`, Codex `memories=false`)
2. 세션 일지 생성(`DIRMEM_SESSION`) + 시작 시점 기억·현황·최근 일지 주입
3. 시작 시 폴더 안 대화 원문을 이 Mac 의 기록 위치로 복원, 종료 시 폴더 안으로 저장.
   폴더 경로가 바뀌었으면 대화 안의 옛 경로·slug 를 새 값으로 치환

### 폴더 유형 (자동 판별)

| 유형 | 판별 | 동작 |
|------|------|------|
| 프로젝트 자체 실행기 | `_tools/session_start.py` + `_SESSION-POLICY.md` (하위 폴더 포함) | 그 실행기로 위임. `-w` 는 프로젝트의 `_tools/iterm_sessions.py launch` 를 같은 PATH·모드로 호출. 모드 기본값: `MARVIS_CLAUDE_MODE=background`, `MARVIS_CODEX_MODE=shared` |
| 자체 기억 체계 | `.llm/` 또는 dirmem 이 아닌 `CLAUDE.md`/`AGENTS.md` | 자체 기억만 끄고 폴더 규칙을 따르게 안내 (`dirmem init` 거부) |
| dirmem | `AI_MEMORY/` | 위 1~3 전체 |
| 그 외 | — | 자동 `dirmem init` 후 dirmem 으로 동작 |
| 홈·바탕화면 자체 | — | 기억을 두지 않음 |

### 실행 모드

| 모드 | 동작 | 기본값 |
|------|------|--------|
| `parallel` | 같은 폴더에서 여러 터미널 동시 실행 허용. 각 세션은 자기 일지만 쓰고 공유 파일은 잠금 후 추가만 | 바탕화면 아래, 자체 실행기 프로젝트 |
| `single` | 같은 폴더에 `claude`/`codex`/`agy` 세션이 있으면 확인 후 실행 | 그 외 |

폴더(또는 상위 폴더)의 `.marvis.conf` (`mode=parallel|single`) 가 기본값보다 우선합니다.

## 폴더 구조 (dirmem)

```
<작업 폴더>/
  AGENTS.md   공용 규칙 본문 (Codex·Antigravity 가 자동으로 읽음)
  CLAUDE.md   Claude 진입점 (@AGENTS.md, @AI_MEMORY/MEMORY.md, @AI_MEMORY/STATUS.md)
  GEMINI.md   Gemini/Antigravity 진입점
  .marvis.conf  (선택) 실행 모드
  AI_MEMORY/
    MEMORY.md     오래 유지할 사실·결정 (공유, 추가 전용, 잠금)
    STATUS.md     진행 현황·담당 (공유, 추가 전용, 잠금)
    sessions/     세션별 일지 <YYMMDD-HHMMSS>_<agent>_<호스트>_<pid>.md
    transcripts/  claude/<세션>.jsonl, codex/YYYY/MM/DD/rollout-*.jsonl, 각 ORIGIN(저장 당시 경로)
```

`AI_MEMORY/` 안에는 심볼릭 링크를 만들지 않습니다(다중 Mac 동기화에서 대상을 잃음).

## 명령 (dirmem)

`dirmem help` — `init [--force] [DIR]` · `start <agent>` · `log "내용"` · `remember <agent> "내용"` ·
`status <agent> "내용"` · `context` · `lock`/`unlock` · `root`

## 설치

- `bash install.sh` — 도구는 vault 도구와 함께 `~/.herald/bin` 에 설치되고, 이어서
  `bootstrap/dirmem-setup.sh --rules-only` 가 전역 규칙 블록을 넣습니다.
- 단독: `bash bootstrap/dirmem-setup.sh` (도구 + 규칙). `~/.herald/bin` 이 PATH 에 없고
  `~/.local/bin` 이 있으면 그곳에 링크를 둡니다.
- 규칙 블록: `~/.claude/CLAUDE.md` · `~/.codex/AGENTS.md` · `~/.gemini/GEMINI.md` 의
  `<!-- dirmem:global:begin -->` ~ `end` 를 삽입/교체, 내용이 바뀔 때만 `*.bak-dirmem` 백업
- (선택) `--shell-guard` → `~/.zshrc` 에 셸 가드(맨 `claude`/`codex`/`agy` 실행에도 단일 모드 경고)
- 템플릿(`templates/dirmem/`)은 저장소에서 읽습니다. 저장소가 `~/Code/herald-ai` 등 기본 후보에
  없으면 `HERALD_AI_DIR` 로 지정합니다 (`ha-we` 와 같은 탐색 순서).

## 주의 · 한계

- 대화 원문에는 대화 중 붙여 넣은 내용이 그대로 들어 있습니다. 폴더를 남에게 넘기면 함께 넘어갑니다.
- 대화 복원은 Claude·Codex 만 지원합니다(Antigravity 는 규칙·기억 주입만).
- 같은 대화를 두 Mac 에서 동시에 이어 가지 않는다는 전제입니다.
- 자체 실행기 프로젝트에는 대화 복원·resume 을 끼워 넣지 않습니다(그 프로젝트의 정책을 따름).
- 공유 파일 잠금(`mkdir`)은 한 Mac 안에서만 원자적입니다.
