# Telegram 알림 스킬

## 목적
Cowork 세션에서 텔레그램 메시지를 전송한다. `curl` 또는 `python3`으로 직접 Telegram Bot API를 호출한다 (Chrome MCP 불필요).

> **변경 이력**: 2026-05-01 Chrome MCP → curl/python3 전환.
> 2026-06-20 토큰을 외부 config 로 분리 (공개 repo 안전). `task-tracker/scripts/notify.sh` 의 `send_telegram()` 와 동일 방식.

## 트리거
- "알림 보내", "텔레그램", "notify", "완료 알림" 등
- 다른 스킬/작업 완료 후 사용자가 알림을 요청한 경우

## 설정

토큰·CHAT_ID 는 스크립트/문서에 하드코딩하지 않고 **외부 config** 에서 로드한다(공개 repo 안전).
파일: `~/.claude/skills/task-tracker/telegram.conf` (권한 600, `.gitignore` 대상). 템플릿은 `telegram.conf.example`.

```bash
# telegram.conf 예시
TOKEN="<your-bot-token>"
CHAT_ID="<your-chat-id>"
# BOT: @QBack_bot
```

아래 호출은 이 파일을 source 하여 `$TOKEN`·`$CHAT_ID` 를 사용한다.

## 실행 절차

### MUTE 가드 (전송 직전 필수, 2026-05-05 신설) ⛔

`task-tracker` 의 `.muted` 플래그가 있으면 **모든 telegram-notify 호출이 즉시 종료**한다. 자율 실행 동안 sub-task 가 자체 알림을 보내지 않도록 단일 출처 mute 보장.

```bash
# 모든 호출의 첫 줄에 의무 추가 (인스턴스별 .muted 도 함께 확인):
[ -f /tmp/task-tracker/.muted ] && { echo "🔕 muted (telegram-notify skipped)"; exit 0; }
```

### config 로드 (방법 A·B 공통 선행)

```bash
CONF="${HERALD_TELEGRAM_CONF:-$HOME/.claude/skills/task-tracker/telegram.conf}"
[ -f "$CONF" ] || { echo "❌ telegram.conf 없음 — telegram.conf.example 참고해 생성"; exit 1; }
# shellcheck disable=SC1090
. "$CONF"   # → $TOKEN, $CHAT_ID
```

### 방법 A — bash 한 줄 (권장)

```bash
[ -f /tmp/task-tracker/.muted ] && { echo "🔕 muted"; exit 0; }
CONF="${HERALD_TELEGRAM_CONF:-$HOME/.claude/skills/task-tracker/telegram.conf}"; . "$CONF"
MESSAGE="{메시지 내용}"
TOKEN="$TOKEN" CHAT_ID="$CHAT_ID" MSG="$MESSAGE" python3 -c "
import json, os, urllib.request
TOKEN = os.environ['TOKEN']; CHAT_ID = os.environ['CHAT_ID']; msg = os.environ['MSG']
body = json.dumps({'chat_id': CHAT_ID, 'text': msg}).encode()
req = urllib.request.Request(
    f'https://api.telegram.org/bot{TOKEN}/sendMessage',
    data=body, headers={'Content-Type': 'application/json'})
print(urllib.request.urlopen(req).read().decode())
"
```

### 방법 B — curl (대안)

```bash
[ -f /tmp/task-tracker/.muted ] && { echo "🔕 muted"; exit 0; }
CONF="${HERALD_TELEGRAM_CONF:-$HOME/.claude/skills/task-tracker/telegram.conf}"; . "$CONF"
MESSAGE="{메시지 내용}"

ESCAPED=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$MESSAGE")
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -H 'Content-Type: application/json' \
    -d "{\"chat_id\":\"${CHAT_ID}\",\"text\":${ESCAPED},\"parse_mode\":\"HTML\"}"
```

### 결과 확인

- `"ok": true` → 전송 성공. message_id를 사용자에게 보고한다.
- `"ok": false` → 실패. error_code와 description을 사용자에게 보고한다.

## 메시지 형식

| 상황 | 메시지 예시 |
|------|-----------|
| 작업 완료 알림 | `✅ (작업유형: 결과 요약)` |
| 사용자 확인 요청 | `⏸️ (질문 요약)` |
| 오류 알림 | `❌ (오류 내용)` |
| 커스텀 메시지 | 사용자가 지정한 텍스트 그대로 전송 |

## 주의사항

1. **Chrome 브라우저 불필요**: python3 `urllib` 또는 `curl`로 직접 전송한다.
2. **HTML 파스 모드**: `parse_mode: HTML` 사용 시 `<b>`, `<code>` 태그 허용. `&`, `<`, `>` 는 이스케이프 필요.
3. **봇 토큰 보안**: 토큰은 `telegram.conf` (권한 600, git 제외) 에만 둔다. 스킬 파일·스크립트에 하드코딩 금지.
