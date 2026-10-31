<!-- dirmem:global:begin (herald-ai bootstrap/dirmem-setup.sh 가 관리 — 직접 수정 시 재설치로 덮어써짐) -->
## 바탕화면 작업 디렉토리 기억 규칙 (dirmem)

세션이 `~/Desktop` 또는 그 하위에서 실행될 때 적용합니다. 이 규칙은 Claude·Codex(ChatGPT)·
Gemini/Antigravity 가 공통으로 따르며, 서로의 기억과 작업 결과를 이어받기 위한 것입니다.

0. 표준 시작 방법은 작업 디렉토리에서 `marvis llm claude|codex|gemini` 입니다 (자체 기억 끄기·세션 일지·기억 주입을
   실행기가 보장). 이미 `DIRMEM_SESSION` 이 설정되어 있으면 그 일지를 사용합니다.
1. **바탕화면에 새 작업 디렉토리를 만들면 즉시** `dirmem init "<디렉토리>"` 를 실행합니다.
   이후 그 작업의 모든 기억은 그 디렉토리의 `AI_MEMORY/` 에만 둡니다.
2. **바탕화면 하위 디렉토리에서 작업할 때** (세션이 바탕화면 자체에서 시작된 경우 포함)
   그 디렉토리에 `AI_MEMORY/` 가 있으면 먼저 그 디렉토리의 `AGENTS.md` 를 읽고,
   `cd "<디렉토리>" && dirmem start __AGENT__` 로 세션 일지를 만든 뒤 기억·현황·최근 일지를 이어받습니다.
   `AI_MEMORY/` 가 없는 기존 디렉토리에서 의미 있는 작업을 시작하면 `dirmem init` 후 진행합니다.
   단, 폴더에 **자체 기억 체계**(`.llm/` 또는 dirmem 이 아닌 CLAUDE.md/AGENTS.md 규칙)가 있으면
   dirmem 을 적용하지 말고 그 폴더의 규칙을 따릅니다 (`dirmem init` 도 이 경우 자동으로 거부합니다).
3. 바탕화면 작업의 기억은 이 AI 의 전역/경로별 기억 저장소에 저장하지 않습니다.
4. **병렬 모드 폴더(바탕화면 아래·자체 실행기 프로젝트 기본값, `.marvis.conf` 로 지정 가능)에서는 같은 디렉토리에서
   여러 세션(예: 같은 맥의 터미널 여러 개)이 병렬로 돌 수 있습니다.** 각 세션은 자기 일지만
   쓰고, 공유 파일(MEMORY.md·STATUS.md)은 `dirmem remember/status` 로 추가만 합니다 (AGENTS.md 의 병렬 규칙).
5. 단일 모드 폴더(바탕화면 밖 기본값)는 **한 디렉토리에 한 세션** 원칙을 지킵니다
   (`marvis llm` 으로 시작하면 같은 디렉토리에 세션이 이미 있을 때 실행 전에 경고합니다).
6. `dirmem` 명령이 없으면 사용자에게 herald-ai 의 `install.sh` 실행을 안내하고,
   그동안은 디렉토리의 AGENTS.md 에 적힌 수동 절차로 같은 규칙을 지킵니다.
<!-- dirmem:global:end -->
