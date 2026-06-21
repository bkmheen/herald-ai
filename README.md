# herald-ai

> Claude Code 작업 상태를 **텔레그램 + 데스크톱**으로 알리고, **토큰/비용까지 요약**해 주는 훅 기반 알림 시스템.

Claude Code 의 hook(`Stop`/`Notification`/`SessionStart`/`SessionEnd`/`UserPromptSubmit`)에 연결되어,
Claude 가 응답을 끝내거나 입력을 기다릴 때마다 **모델이 직접 작성한 10줄 요약**을 알림으로 보냅니다.
각 알림에는 `ccusage` 기반 **월 누적 비용·증감률**과 **세션 소요시간**이 함께 표시됩니다.

```
🪪 [MarvisHome@221·06/20 17:16] Claude Code: 완료 ✅
알림 라벨 호스트 구분 적용 완료
…
⏱️ 1분 12초 | 월누적 $8737.7 (+3%)
```

## ✨ 특징

- **모델 자작 요약** — transcript 원문이 아니라 Claude 가 쓴 핵심 요약을 전송.
- **타입 분화** — `✅ 완료` / `🔄 진행 보고` / `⏸️ 응답 대기` / `❌ 오류` 를 마커로 구분.
- **비용 인지** — 매 알림에 `ccusage` 월누적 비용·증감률 표시.
- **다중 인스턴스 구분** — `<디렉토리>@<IP끝옥텟>` 라벨로 여러 머신·세션 알림이 안 섞임.
- **멀티 채널** — Telegram(주) + 데스크톱(macOS `osascript`/`terminal-notifier`, Linux `notify-send`).
- **크로스플랫폼** — macOS·Linux(Ubuntu) 공용. 헤드리스 서버에서도 텔레그램만으로 동작.
- **토큰 외부화** — 봇 토큰은 `telegram.conf`(git 제외)에만. repo 공개 안전.

## 📦 요구 사항

| 항목 | 필수 | 용도 |
|------|:---:|------|
| bash | ✅ | 훅 스크립트 |
| python3 | ✅ | 텔레그램 전송, 설정 병합 |
| curl | 권장 | 텔레그램 전송(python3 폴백 있음) |
| Node.js (`npx`) | 권장 | `ccusage` 토큰/비용 추적 |
| bc | 권장 | 소요시간 계산 |
| jq | 선택 | JSON 파싱(node 폴백 있음) |

Ubuntu: `sudo apt install -y python3 curl bc jq nodejs npm`

## 🚀 설치

> `bash`·`python3` 만 있으면 동작합니다. 나머지는 권장(없어도 폴백). 설치 스크립트는
> **멱등**이므로 여러 번 실행해도 안전하며, 기존 `settings.json` 은 자동 백업됩니다.

### 0) 사전 요구사항 (선택이지만 권장)

전체 기능(텔레그램 전송·비용 추적·소요시간)을 쓰려면 아래를 먼저 설치하세요.

**macOS (Homebrew)**
```bash
brew install bc jq node      # python3·curl 은 기본 포함
```

**Ubuntu / Debian**
```bash
sudo apt update && sudo apt install -y python3 curl bc jq nodejs npm
```

미설치 항목은 자동으로 우회합니다 — `node` 없으면 비용 추적만, `curl` 없으면 python3 로 전송.

### 1) 설치

```bash
git clone https://github.com/bkmheen/herald-ai.git
cd herald-ai
bash install.sh
```

설치 스크립트가 수행하는 5단계(모두 멱등):

| 단계 | 내용 |
|------|------|
| 1 | **의존성 점검** — 필수/권장 도구 확인 |
| 2 | **스킬 복사** — `task-tracker`·`telegram-notify` → `~/.claude/skills/` (개인 파일 `telegram.conf`·`task_history.jsonl`·`config` 는 보존) |
| 3 | **텔레그램 설정** — `telegram.conf` 가 없을 때만 example 에서 생성 |
| 4 | **훅 병합** — `~/.claude/settings.json` 에 훅 추가(기존 설정 `*.bak.<epoch>` 로 백업, 우리 훅은 중복 제거 후 재삽입) |
| 5 | **완료 안내** — 다음 단계·테스트 명령 출력 |

> `~/.claude` 가 아닌 다른 경로를 쓰려면 `CLAUDE_CONFIG_DIR=/경로 bash install.sh`.

### 2) 텔레그램 설정

```bash
$EDITOR ~/.claude/skills/task-tracker/telegram.conf   # TOKEN, CHAT_ID 입력
```

- **TOKEN**: [@BotFather](https://t.me/BotFather) 에서 봇 생성 후 발급.
- **CHAT_ID**: [@userinfobot](https://t.me/userinfobot) 에게 말 걸면 알려줍니다.
- 파일 권한은 `600` 으로 생성됩니다(토큰 보호). 직접 만들 경우 `chmod 600` 권장.

미설정 시 텔레그램은 건너뛰고 **데스크톱 알림만** 동작합니다.

### 3) 설치 검증

```bash
# (a) 전송 테스트 — 실제로 보내지 않고 메시지만 출력
NOTIFY_DRY_RUN=1 bash ~/.claude/skills/task-tracker/scripts/notify.sh done

# (b) 텔레그램 실제 1회 전송 확인 (DRY_RUN 제거)
bash ~/.claude/skills/task-tracker/scripts/notify.sh done

# (c) 훅이 settings.json 에 병합됐는지 확인
grep -c 'task-tracker/scripts' ~/.claude/settings.json   # 1 이상이면 정상
```

이후 **Claude Code 새 세션을 시작**하면 훅이 활성화되어, 응답 종료·입력 대기 때마다 알림이 전송됩니다.

### 4) 업데이트 · 제거

```bash
# 업데이트: 최신 코드 받은 뒤 재설치(멱등 — 개인 설정 보존)
git -C herald-ai pull && bash herald-ai/install.sh

# 제거: settings.json 의 herald 훅만 제거(스킬 파일은 보존)
bash herald-ai/uninstall.sh
```

### 5) 문제 해결 (FAQ)

| 증상 | 원인 · 해결 |
|------|-------------|
| 알림이 안 옴 | Claude Code **세션을 새로 시작**했는지 확인(훅은 새 세션부터 적용). `grep task-tracker ~/.claude/settings.json` 으로 병합 확인. |
| 텔레그램만 안 옴 | `telegram.conf` 의 `TOKEN`/`CHAT_ID` 확인. `NOTIFY_DRY_RUN=1 ... notify.sh done` 으로 메시지 생성 여부 점검. |
| `월누적` 비용이 `$0`/`(-%)` | `node`(`npx`) 미설치 시 `ccusage` 동작 안 함 → 비용·증감률 비활성. 데이터가 31일 미만이면 증감률은 정상적으로 `(-%)`. |
| 여러 머신/세션 알림이 섞임 | 정상 — 라벨 `<디렉토리>@<IP끝옥텟>` 로 구분됩니다. 모든 상태는 인스턴스별 `/tmp/task-tracker/<id>/` 에 분리. |
| 헤드리스 서버(GUI 없음) | 데스크톱 알림은 건너뛰고 텔레그램만 전송 — 정상 동작. |
| 설치 후 settings 복구 | 설치 직전 백업이 `~/.claude/settings.json.bak.<epoch>` 에 있습니다. |

## ⚙️ 동작 방식

| 훅 | 시점 | 알림 |
|----|------|------|
| `SessionStart` | 세션 시작 | epoch·턴 카운터 초기화 |
| `UserPromptSubmit` | 프롬프트 제출 | task-tracker 리마인더 |
| `Notification` | 입력 대기 | ⏸️ 응답 대기 |
| `Stop` | **응답 종료마다** | 마커에 따라 ✅/🔄/⏸️/❌ |
| `SessionEnd` | 세션 종료 | ✅ 완료(안전망) |

알림 본문은 Claude 가 응답 직전 `notify-ctx.sh` 로 기록한 컨텍스트에서 옵니다:

```bash
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'EOF'
[done]
작업 요약 (10줄 이내)
EOF
```

마커: `[done]`(✅ 자체완결) · 없음(🔄 진행) · `[waiting]`(⏸️ 입력대기) · `[error]`(❌ 오류).

## 🧹 제거

```bash
bash uninstall.sh   # settings.json 의 herald 훅만 제거(스킬 보존)
```

## 🗺️ 로드맵

- [ ] **멀티 프로바이더** — OpenAI Codex CLI / Gemini CLI 어댑터 (현재 Claude Code).
- [ ] **멀티 채널** — Discord / Slack / ntfy.
- [ ] **Claude Code 플러그인 마켓플레이스** 배포(`/plugin install`).

## 📜 변경 이력 · 개발 기록

- **[CHANGELOG.md](CHANGELOG.md)** — 버전별 변경 요약(사용자용, Keep a Changelog 표준).
- **[DEVLOG.md](DEVLOG.md)** — 변경 배경·의사결정 상세(개발자용).
- **[VERSION](VERSION)** — 현재 버전 단일 출처.

현재 버전: **0.1.3**

## 📄 라이선스

MIT © 2026 bkmheen
