---
name: llm-collaboration-rules
description: 여러 LLM 이 한 디렉토리에서 각자 일하면서 서로 이어받는 방법
metadata:
  type: project
---

# LLM 협업 규칙

## 구조

```
{{SOURCE_DIR}}/          사용자 자료 (모두 읽기만)
reference/           LLM 자료 (모두 읽고 쓴다 · 대장 기록 조건)
.llm/BOARD.md            ★ 누가 어디까지 했는가 — 인계의 접점
.llm/memory/             공용 기억 (모두 읽고 쓴다)
.llm/sessions/           공용 세션 기록
.llm/agents/<llm>/       LLM 개별 기억·기록 (자기 것만 쓴다)
<llm>/                   LLM 작업공간 (산출물 + 생성 스크립트)
```

같은 원본으로 **각자 만들어 비교**하고, 더 나은 쪽을 **이어받는다.**

## 경계 — 무엇을 건드리고 무엇을 건드리지 않는가

| 대상 | 읽기 | 쓰기 |
|---|---|---|
| `{{SOURCE_DIR}}/` (사용자 자료) | ○ | ⛔ **절대 금지** |
| `reference/` (LLM 자료) | ○ | ○ — 단 `reference/README.md` 대장에 기록 |
| `.llm/memory/` · `.llm/sessions/` · `.llm/BOARD.md` | ○ | ○ (공용) |
| `.llm/agents/<내 이름>/` | ○ | ○ |
| `.llm/agents/<남의 이름>/` | ○ | ⛔ |
| `<내 이름>/` | ○ | ○ |
| `<남의 이름>/` | ○ | ⛔ |

**남의 작업을 가져올 때는 내 작업공간으로 복사**해서 진행한다. 남의 자리에서 고치지 않는다.

## 새 LLM 이 참여할 때

1. `<llm>/` 작업공간을 만든다 (이름은 소문자: `claude` · `gemini` · `codex` …)
2. `.llm/agents/<llm>/memory/` · `sessions/` 를 만든다
3. `.llm/BOARD.md` 의 표에 자기 줄을 더한다
4. 그 도구의 진입점 파일이 없으면 만든다 (`CLAUDE.md` · `GEMINI.md` · `AGENTS.md` …).
   내용은 기존 것을 그대로 따르고 **자기 경로만 바꾼다**

## 작업을 마칠 때 — 빠뜨리면 인계가 끊긴다

1. `<내 이름>/STATUS.md` 갱신 — 무엇을 어디까지 만들었나
2. `.llm/BOARD.md` 의 내 줄 갱신 — 최신 산출물 · 어디까지 · 다음 할 일 · 갱신일
3. 다른 LLM 도 알아야 할 판단이면 `.llm/memory/` 또는 `.llm/sessions/` 에 남긴다
4. 나만 아는 구현 세부는 `.llm/agents/<내 이름>/` 에 남긴다

## 이어받을 때

1. `.llm/BOARD.md` — 전체 국면과 그 LLM 의 상태
2. `<llm>/STATUS.md` — 무엇을 어떻게 만들었나
3. `.llm/agents/<llm>/` — **왜 그렇게 정했나** (이것이 가장 중요하다)
4. `<llm>/__history__/` — 무엇이 바뀌어 왔나
5. 이어받을 것을 **내 작업공간으로 복사**한 뒤 진행
6. 내 `STATUS.md` 와 `BOARD.md` 에 **무엇을 누구에게서 이어받았는지** 적는다

## 비교할 때

다른 LLM 의 결과를 평가할 때는 **좋은 점을 먼저 찾아 계승**하고 문제만 고친다.
무엇을 계승했고 무엇을 왜 바꿨는지 기록한다. 그 기록이 다음 비교의 출발점이 된다.
