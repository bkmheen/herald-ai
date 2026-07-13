# CLAUDE.md — herald-ai 작업 규칙 (단일 출처)

이 파일은 Claude Code 가 프로젝트 진입 시 자동으로 읽는 규칙 문서입니다.
**herald-ai 저장소의 git 운영 규칙은 이 파일이 단일 출처(single source of truth)** 이며,
git 으로 배포되므로 어느 Mac 에서 clone/설치하든 동일하게 적용됩니다.
(참고: `~/.claude/.../memory/` 의 프로젝트 메모리는 머신 로컬이라 전파되지 않습니다.
그래서 "여러 Mac 에서 동일 적용" 이 필요한 규칙은 반드시 저장소 안 이 파일에 둡니다.)

---

## 핵심 포인트

- **버전 관리**: `major.minor.patch` 체계. 작업 전환 시 `minor`↑, 연속 작업 시 `patch`↑,
  `major` 는 사용자 승낙 시에만. 최초 `major` 는 `0`.
- **커밋**: 매 수정마다 강제는 아니나, 실행 전·요청 시 반드시 커밋 선행.
  모든 `patch` 에는 최소한의 커밋 기록을 남김.
- **개발 기록**: README / CHANGELOG / DEVLOG 표준 기록 유지, 파일 비대 시 주제별
  분할(`README_subtitle.md`)하고 전체 구조는 README 에 남겨 연결.
- **푸시**: 자동 금지, 사용자 요청 시에만.

---

## 상세 내용

### 버전 관리 규칙

- 형식: `major.minor.patch`.
- 작업이 바뀌면 `minor` 증가, 연속된 일이면 `patch` 증가.
- `major` 는 사용자 승낙 시에만 증가. 최초 `major` 는 `0`.
- 모든 `patch` 에 대해 최소한 커밋 기록을 남김.
- 개발 단계 완료마다 `minor`·`patch` 번호를 적절히 유지 또는 증가.
- 현재 버전의 단일 출처는 [`VERSION`](VERSION) 파일. README 등 문서의 버전 표기는
  이 파일과 일치시킨다.

### 커밋 규칙

- 수정할 때마다 커밋할 필요는 없음.
- 단, 실행 전 또는 요청 받았을 때는 지금까지의 수정 내용을 커밋한 후 실행.
- 커밋 메시지 말미에 공동 작성자 트레일러를 남긴다:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

### 커밋 시 개발 기록 규칙

- README, CHANGELOG, DEVLOG 등 표준에 따라 기록 — 향후 참고 가능하도록 매 수정마다 작성.
- 한 파일이 너무 커지면 `README_subtitle.md` 형태로 주제별 분할.
- 전체 구조는 README 에 남겨 서브 파일의 존재를 알림.
- CHANGELOG, DEVLOG 도 동일한 분할·연결 방식으로 관리.

### 푸시 규칙

- `push` 는 자동으로 하지 않음.
- 필요 시 사용자가 별도로 요청.
