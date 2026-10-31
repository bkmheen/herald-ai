<!-- dirmem:protocol v1 -->
# AI 공용 작업 규칙 (Claude · Codex/ChatGPT · Gemini/Antigravity 공통)

이 디렉토리는 **디렉토리 이식형 기억** 을 사용합니다. 이 작업에 관한 모든 기억은
이 디렉토리 안의 `AI_MEMORY/` 에만 둡니다. 디렉토리를 옮기거나 다른 맥·다른 AI 에서
열어도 그대로 이어서 작업할 수 있어야 합니다.

## 시작 방법
터미널에서 이 디렉토리로 이동해 `marvis llm claude` / `marvis llm codex` / `marvis llm gemini` 로 시작하는 것이
표준입니다. 실행기가 각 AI 의 자체 기억을 끄고, 세션 일지를 만들어 `DIRMEM_SESSION` 에 넣고,
시작 시점의 기억·현황·최근 일지를 전달합니다. 대화 원문도 종료 시 `AI_MEMORY/transcripts/` 에
보관되어 다른 맥에서 `marvis llm claude --resume` / `marvis llm codex resume` 으로 이어 갈 수 있습니다.

## 세션 시작 시 (필수)
1. `dirmem start <claude|codex|gemini>` 를 실행합니다 (marvis 로 시작했다면 이미 만든 일지를 그대로 재사용합니다). 출력 첫 줄의 `DIRMEM_SESSION=` 경로가
   **이번 세션 전용 일지** 입니다. 이 경로를 세션 내내 기억해 두십시오.
2. 출력된 기억(MEMORY)·현황(STATUS)·최근 세션 일지를 읽고, 다른 AI/세션이 해 둔 작업을 이어받습니다.

## 작업 중
- 의미 있는 진행·결정·산출물은 **내 세션 일지** 에 기록합니다: `dirmem log "내용"` (일지 경로는 `$DIRMEM_SESSION`)
- 오래 유지할 사실·결정·사용자 선호: `dirmem remember <agent> "내용"` → `AI_MEMORY/MEMORY.md`
- 진행 현황·다음 할 일 변경: `dirmem status <agent> "내용"` → `AI_MEMORY/STATUS.md`
- 산출물 파일은 이 디렉토리 안에 상대 경로로 둡니다. 절대 경로(/Users/...)를 기억에 적지 않습니다.

## 병렬 실행 규칙 (병렬 모드 폴더 — 바탕화면 기본값, `marvis mode` 로 확인·변경)
- 다른 세션의 일지 파일(`AI_MEMORY/sessions/*`)은 **읽기만** 하고 수정하지 않습니다.
- `MEMORY.md`·`STATUS.md` 는 위 명령으로 **추가만** 합니다. 전체 정리(재작성)가 필요하면
  `dirmem lock <agent>` → 편집 → `dirmem unlock` 순서로 하고, 잠금 중에는 짧게 끝냅니다.
- 같은 산출물 파일을 다른 세션이 작업 중인지 STATUS 와 최근 일지로 확인한 뒤 손댑니다.
  작업을 맡을 때 `dirmem status <agent> "담당: <파일/작업>"` 으로 먼저 표시합니다.

## 각 AI 고유 기억 저장소 사용 금지
- Claude 의 `~/.claude/projects/.../memory`, Codex 의 전역 메모리, Gemini/Antigravity 의
  전역 knowledge 등 **경로에 묶인 전역 기억에 이 작업의 내용을 저장하지 않습니다.**
  (디렉토리를 옮기면 끊기고, 다른 AI 가 읽지 못합니다.)

## dirmem 이 설치되지 않은 맥에서
명령이 없으면 같은 규칙을 파일로 직접 수행합니다:
`AI_MEMORY/sessions/<YYMMDD-HHMMSS>_<agent>_<호스트>.md` 를 새로 만들어 내 일지로 쓰고,
MEMORY.md·STATUS.md 에는 `- [일시 agent@호스트] 내용` 형식의 줄을 끝에 추가만 합니다.
설치 방법: herald-ai 저장소에서 `bash install.sh` (또는 `bash bootstrap/dirmem-setup.sh`).

## 이 작업 고유 지시사항
(필요 시 아래에 작성)
