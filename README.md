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

```bash
git clone https://github.com/bkmheen/herald-ai.git
cd herald-ai
bash install.sh
```

설치 스크립트가 (1) 의존성 점검 → (2) 스킬을 `~/.claude/skills/` 로 복사 →
(3) `telegram.conf` 생성 → (4) `~/.claude/settings.json` 에 훅 병합(기존 설정 백업)까지 멱등 수행합니다.

### 텔레그램 설정

```bash
cp config/telegram.conf.example ~/.claude/skills/task-tracker/telegram.conf
chmod 600 ~/.claude/skills/task-tracker/telegram.conf
$EDITOR ~/.claude/skills/task-tracker/telegram.conf   # TOKEN, CHAT_ID 입력
```

- **TOKEN**: [@BotFather](https://t.me/BotFather) 에서 봇 생성 후 발급.
- **CHAT_ID**: [@userinfobot](https://t.me/userinfobot) 에게 말 걸면 알려줍니다.

미설정 시 텔레그램은 건너뛰고 데스크톱 알림만 동작합니다.

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

현재 버전: **0.1.1**

## 📄 라이선스

MIT © 2026 bkmheen
