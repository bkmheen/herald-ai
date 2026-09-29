# {{PROJECT_NAME}} — 이 프로젝트에서 일하는 방법

> AGENTS.md 규약을 쓰는 도구(Codex 등) 은 작업 디렉토리의 `AGENTS.md` 를 자동으로 읽는다.
> 이 프로젝트의 지침은 도구와 무관하게 하나로 관리한다.

## 먼저 읽을 것

**같은 디렉토리의 `CLAUDE.md` 내용을 그대로 따른다.** 도구 이름만 다르고 규칙은 동일하다.

순서를 요약하면 이렇다.

1. `.llm/BOARD.md` — 누가 어디까지 했는가. 이어받을 지점
2. `.llm/memory/00_INDEX.md` — 공용 기억 색인
3. `.llm/agents/codex/memory/00_INDEX.md` — 내 개별 기억 (있으면)
4. `codex/STATUS.md` — 내 작업공간의 현재 상태

## 내 자리

| 경로 | 용도 |
|---|---|
| `codex/` | 내 작업공간. 산출물과 생성 스크립트를 여기 둔다 |
| `.llm/agents/codex/` | 내 개별 기억·세션 기록 |
| `.llm/` | 공용. 모든 LLM 이 읽고 쓴다 |

**남의 작업공간과 남의 `agents/` 는 읽기만 한다.** 고치지 않는다.

## 기억과 기록

- 공용 사실은 `.llm/memory/` · 나만의 것은 `.llm/agents/codex/memory/`
- 작업을 마칠 때마다 `.llm/BOARD.md` 의 **내 줄을 갱신**한다
- ⛔ 도구의 홈 디렉토리에는 이 프로젝트의 기억을 남기지 않는다
- 작성 규칙은 `.llm/README.md`
