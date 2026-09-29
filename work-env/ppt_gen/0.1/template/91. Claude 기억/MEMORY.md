<!-- 이 파일은 Claude 가 매 세션 읽는 기억 색인이다. 한 기억 = 한 파일, 여기에는 한 줄 포인터만 둔다.
     형식:  - [제목](파일명.md) — 한 줄 요약
     `.claude/hooks/sync-memory.sh` 가 ~/.claude/projects/<slug>/memory/ 와 양방향 동기화한다. -->
