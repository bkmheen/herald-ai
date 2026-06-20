#!/bin/bash
# notify.sh - 텔레그램 + macOS 알림 전송 (task-tracker 연동)
# 사용법: notify.sh {progress|waiting|done|session_end} [fallback_message]
#
# 메시지 타입 (v4, 2026-04-17 재설계):
#   🔄 진행 보고      (default / Stop 훅 기본)
#   ⏸️ 응답 대기      (context [waiting] / Notification 훅)
#   ❌ 오류           (context [error])
#   ✅ 완료           (SessionEnd 훅 전용 — session_end 모드에서만 발송)
#
# 다중 인스턴스 분리 (v6, 2026-05-09):
#   /tmp/task-tracker/<instance-id>/ 안에서 모든 상태 관리.
#   메시지 헤더에 🪪 INSTANCE_LABEL 표시 → 사용자가 어느 Claude Code 인스턴스의
#   알림인지 한눈에 구분 가능. 다른 인스턴스의 컨텍스트·상태와 절대 충돌하지 않음.
#
# 주요 변경 (v4):
#   - "✅ 완료" 는 오직 session_end 모드(SessionEnd 훅)에서만 발송.
#     Stop 훅에서 [done] 컨텍스트 마커가 와도 🔄 진행 보고로 강등.
#     → 중간 단계 milestone을 Claude가 [done]으로 잘못 표기해도 "완료" 가 오지 않음.
#   - 경과 시간 기준은 .session_start_epoch (세션 시작).
#     STATE_FILE의 task start_epoch는 폴백.
#   - 턴 카운터는 세션 전체에 걸쳐 누적 (SessionStart 훅에서만 리셋).
#
# 공통 규칙 (v3 에서 유지):
#   1. MUTED 가드: .muted 있으면 즉시 종료 (session_end 제외).
#   2. CONTEXT 필수 가드: .notify_context 없으면 즉시 종료 (session_end 제외).
#   3. 중복 차단: 같은 해시 5초 이내 재발송 skip.
#   4. Telegram HTML 포맷.
#   5. NOTIFY_DRY_RUN=1: 전송 없이 stdout 만 출력 (테스트용).

set -uo pipefail

MODE="${1:-progress}"
FALLBACK="${2:-}"

# ── 설정 (텔레그램 자격증명: 외부 config 에서 로드) ────────
# 토큰을 스크립트에 하드코딩하지 않는다(공개 repo 안전). 아래 우선순위로 로드:
#   1) 환경변수 HERALD_TELEGRAM_TOKEN / HERALD_TELEGRAM_CHAT_ID
#   2) $HERALD_TELEGRAM_CONF (명시 경로)
#   3) 스킬 루트의 telegram.conf  (scripts/../telegram.conf)
#   4) ~/.config/herald-ai/telegram.conf
# config 파일은 `TOKEN="..."` 와 `CHAT_ID="..."` 를 정의하는 shell 조각.
# 어디에도 없으면 텔레그램 전송은 건너뛴다(데스크톱 알림은 계속 동작).
TOKEN="${HERALD_TELEGRAM_TOKEN:-}"
CHAT_ID="${HERALD_TELEGRAM_CHAT_ID:-}"
for _herald_cf in \
    "${HERALD_TELEGRAM_CONF:-}" \
    "$(dirname "$0")/../telegram.conf" \
    "$HOME/.config/herald-ai/telegram.conf"; do
    [ -n "$_herald_cf" ] && [ -f "$_herald_cf" ] && { . "$_herald_cf"; break; }
done
unset _herald_cf

# 인스턴스별 RUNTIME_DIR 해석
source "$(dirname "$0")/instance-resolve.sh"

STATE_FILE="${RUNTIME_DIR}/.current_task"
LAST_TASK_FILE="${RUNTIME_DIR}/.last_task"
CONTEXT_FILE="${RUNTIME_DIR}/.notify_context"
TURN_FILE="${RUNTIME_DIR}/.turn_counter"
LAST_HASH_FILE="${RUNTIME_DIR}/.last_hash"
LAST_SENT_FILE="${RUNTIME_DIR}/.last_sent_epoch"
MUTED_FILE="${RUNTIME_DIR}/.muted"
SESSION_START_FILE="${RUNTIME_DIR}/.session_start_epoch"
TURN_START_FILE="${RUNTIME_DIR}/.turn_start_epoch"

DEDUP_WINDOW_SEC=5

mkdir -p "$RUNTIME_DIR"

# ── 공용 함수 ─────────────────────────────────────────
escape_html() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

format_elapsed() {
    local elapsed="$1"
    local h=$(( elapsed / 3600 ))
    local m=$(( (elapsed % 3600) / 60 ))
    local s=$(( elapsed % 60 ))
    if [[ $h -gt 0 ]]; then
        echo "${h}h ${m}m ${s}s"
    elif [[ $m -gt 0 ]]; then
        echo "${m}m ${s}s"
    else
        echo "${s}s"
    fi
}

read_task_name() {
    local src=""
    if [[ -f "$STATE_FILE" ]]; then
        src="$STATE_FILE"
    elif [[ -f "$LAST_TASK_FILE" ]]; then
        src="$LAST_TASK_FILE"
    fi
    if [[ -z "$src" ]]; then echo ""; return; fi
    if command -v jq &>/dev/null; then
        jq -r '.task_name // ""' "$src" 2>/dev/null
    else
        python3 -c "import json; d=json.load(open('$src')); print(d.get('task_name',''))" 2>/dev/null || echo ""
    fi
}

# 경과 시간 문자열 — 우선순위 (2026-04-19 v6 개정):
#   1. .turn_start_epoch  → 현재 턴 (사용자 프롬프트 → 응답대기/완료) 소요 시간
#   2. .session_start_epoch → 세션 누적 (폴백)
#   3. task .start_epoch  → 폴백
# session_end 모드는 session 기준 사용 (전체 누적이 의미 있음).
read_elapsed_str() {
    local mode_hint="${1:-turn}"  # turn (기본) / session
    local now_epoch base_epoch=0
    now_epoch=$(date '+%s')

    # 1순위: turn 기준 (mode_hint=turn 일 때만)
    if [[ "$mode_hint" == "turn" ]] && [[ -f "$TURN_START_FILE" ]]; then
        base_epoch=$(cat "$TURN_START_FILE" 2>/dev/null || echo 0)
    fi

    # 2순위: 세션 기준
    if [[ "$base_epoch" -eq 0 ]] && [[ -f "$SESSION_START_FILE" ]]; then
        base_epoch=$(cat "$SESSION_START_FILE" 2>/dev/null || echo 0)
    fi

    # 3순위: task start_epoch (폴백)
    if [[ "$base_epoch" -eq 0 ]]; then
        local src=""
        if [[ -f "$STATE_FILE" ]]; then
            src="$STATE_FILE"
        elif [[ -f "$LAST_TASK_FILE" ]]; then
            src="$LAST_TASK_FILE"
        fi
        if [[ -n "$src" ]]; then
            if command -v jq &>/dev/null; then
                base_epoch=$(jq -r '.start_epoch // 0' "$src" 2>/dev/null)
            else
                base_epoch=$(python3 -c "import json; d=json.load(open('$src')); print(d.get('start_epoch',0))" 2>/dev/null || echo 0)
            fi
        fi
    fi

    if [[ "$base_epoch" -gt 0 ]]; then
        local elapsed=$(( now_epoch - base_epoch ))
        [[ $elapsed -lt 0 ]] && elapsed=0
        format_elapsed "$elapsed"
    else
        echo ""
    fi
}

send_telegram() {
    local msg="$1"
    if [[ -n "${NOTIFY_DRY_RUN:-}" ]]; then
        echo "--- [DRY RUN] telegram ---"
        echo "$msg"
        echo "--------------------------"
        return 0
    fi
    # 자격증명 미설정 시 전송 생략 (telegram.conf 없는 환경에서도 안전)
    if [[ -z "${TOKEN:-}" || -z "${CHAT_ID:-}" ]]; then
        return 0
    fi
    local escaped
    escaped=$(python3 -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps(msg))
" <<< "$msg" 2>/dev/null || echo "\"${msg}\"")
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d "{\"chat_id\":\"${CHAT_ID}\",\"text\":${escaped},\"parse_mode\":\"HTML\"}" \
        > /dev/null 2>&1 &
    wait
}

send_macos() {
    local title="$1" body="$2"
    if [[ -n "${NOTIFY_DRY_RUN:-}" ]]; then
        echo "--- [DRY RUN] macOS ---"
        echo "title: $title"
        echo "body:  $body"
        echo "-----------------------"
        return 0
    fi
    # macOS: terminal-notifier 우선(권한 프롬프트 없음), 없으면 osascript.
    # Linux: notify-send(libnotify). 둘 다 없으면(헤더리스 서버 등) 데스크톱 알림은
    #   생략 — 텔레그램이 주 채널이므로 알림 자체는 정상 발송된다.
    local tn
    tn=$(command -v terminal-notifier 2>/dev/null)
    if [[ -n "$tn" ]]; then
        "$tn" -title "${title}" -message "${body}" -sound Glass >/dev/null 2>&1 &
    elif command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${body}\" with title \"${title}\" sound name \"Glass\"" 2>/dev/null &
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "${title}" "${body}" >/dev/null 2>&1 &
    fi
}

# 헤더 빌더 — 모든 메시지 첫 줄에 인스턴스 라벨을 포함시켜 다중 인스턴스 식별
build_header() {
    local emoji="$1" title_kor="$2" turn_suffix="${3:-}"
    local label_html
    label_html=$(printf '%s' "$INSTANCE_LABEL" | escape_html)
    if [[ -n "$turn_suffix" ]]; then
        printf '%s <b>Claude Code [%s]: %s</b> %s' "$emoji" "$label_html" "$title_kor" "$turn_suffix"
    else
        printf '%s <b>Claude Code [%s]: %s</b>' "$emoji" "$label_html" "$title_kor"
    fi
}

# ── session_end 모드 ─────────────────────────────────
# SessionEnd 훅 전용. MUTED / context 가드를 건너뛰고 "✅ 완료" 를 발송한다.
# 중간 단계 [done] 오표기에 영향받지 않는 유일한 "완료" 경로.
if [[ "$MODE" == "session_end" ]]; then
    # 세션에 의미있는 활동이 없었으면 skip (진행 보고 0회, context 없음, start도 없음)
    turn_num=0
    [[ -f "$TURN_FILE" ]] && turn_num=$(cat "$TURN_FILE" 2>/dev/null || echo 0)

    task_name=$(read_task_name)
    elapsed_str=$(read_elapsed_str session)  # session_end 는 세션 누적 사용

    # 이 세션에서 한 번도 작업 시작/응답이 없었으면 알림 의미가 없으므로 skip
    if [[ -z "$task_name" ]] && [[ "$turn_num" -eq 0 ]] && [[ -z "$elapsed_str" ]]; then
        exit 0
    fi

    # 이미 session_end를 한 번 발송했다면 MUTED 가 설정되어 있음 → 중복 skip
    if [[ -f "$MUTED_FILE" ]]; then
        exit 0
    fi

    # 컨텍스트가 남아있으면 본문에 포함 (마커 제거)
    context=""
    if [[ -f "$CONTEXT_FILE" ]]; then
        raw=$(head -11 "$CONTEXT_FILE" 2>/dev/null || true)
        first_line=$(echo "$raw" | head -1)
        case "$first_line" in
            '[done]'|'[DONE]'|'[waiting]'|'[WAITING]'|'[error]'|'[ERROR]'|'[progress]'|'[PROGRESS]')
                context=$(echo "$raw" | tail -n +2 | head -10)
                ;;
            *)
                context=$(echo "$raw" | head -10)
                ;;
        esac
        rm -f "$CONTEXT_FILE"
    fi

    header=$(build_header "✅" "완료")
    message="${header}"
    if [[ -n "$task_name" ]]; then
        ts=$(echo "$task_name" | escape_html)
        message="${message}"$'\n'"📋 ${ts}"
    fi
    if [[ -n "$elapsed_str" ]]; then
        message="${message}"$'\n'"⏱️ <b>소요</b>: ${elapsed_str}"
    fi
    if [[ "$turn_num" -gt 0 ]]; then
        message="${message}"$'\n'"📊 <b>진행 보고</b>: ${turn_num}회"
    fi
    message="${message}"$'\n'"─────────────"
    if [[ -n "$context" ]]; then
        cs=$(echo "$context" | escape_html)
        message="${message}"$'\n'"${cs}"
    else
        message="${message}"$'\n'"세션 종료"
    fi

    send_macos "[$INSTANCE_LABEL] Claude Code 세션 완료" "${task_name:-세션 종료}"
    send_telegram "$message"

    # 이후 혹시 추가로 발화하는 훅이 있어도 발송되지 않도록 MUTED 설정
    touch "$MUTED_FILE"
    exit 0
fi

# ── MUTED 가드 (가장 먼저, session_end·waiting 제외) ─────────
# SessionEnd 이후 잔여 훅이 발화해도 silent. 단, 질문(waiting)은 사용자 응답이
# 반드시 필요하므로 MUTED 여부와 무관하게 항상 통과시킨다 (사용자 지시 2026-06-03:
# "완료하거나 질문이 있을 때 항상 텔레그램").
if [[ -f "$MUTED_FILE" && "$MODE" != "waiting" ]]; then
    exit 0
fi

# ── CONTEXT 가드 (done/waiting 은 fallback 합성, 그 외만 종료) ──────────
# context 파일이 없을 때: done(완료)·waiting(질문)은 "항상 알림" 보장을 위해 generic
# fallback 을 합성한다. progress 등 자동 중간 턴만 노이즈 방지로 종료.
if [[ ! -f "$CONTEXT_FILE" ]]; then
    case "$MODE" in
        done)
            printf '%s\n%s\n' '[done]' '작업이 완료되었습니다.' > "$CONTEXT_FILE"
            ;;
        waiting)
            printf '%s\n%s\n' '[waiting]' '입력이 필요합니다 — 질문 또는 승인 대기 중입니다.' > "$CONTEXT_FILE"
            ;;
        *)
            exit 0
            ;;
    esac
fi

# ── 작업 정보 읽기 ────────────────────────────────────
task_name=$(read_task_name)
elapsed_str=$(read_elapsed_str)

# ── 컨텍스트 + 타입 마커 읽기 ─────────────────────────
context=""
explicit_type=""

raw=$(head -11 "$CONTEXT_FILE" 2>/dev/null || true)

first_line=$(echo "$raw" | head -1)
case "$first_line" in
    '[done]'|'[DONE]')
        # v5: [done] 마커는 Stop 훅에서 ✅ 완료 로 정상 격상된다 (v4 강등 취소).
        # Claude 는 "이 턴의 답변이 자체 완결이면 [done]",
        # 자동 파이프라인 중간이면 마커 없이 (→ 🔄 진행 보고) 작성한다.
        # SessionEnd 훅은 마지막 턴이 [done] 이 아니었을 때의 안전망 역할.
        explicit_type="done"
        context=$(echo "$raw" | tail -n +2 | head -10)
        ;;
    '[waiting]'|'[WAITING]')
        explicit_type="waiting"
        context=$(echo "$raw" | tail -n +2 | head -10)
        ;;
    '[error]'|'[ERROR]')
        explicit_type="error"
        context=$(echo "$raw" | tail -n +2 | head -10)
        ;;
    '[progress]'|'[PROGRESS]')
        explicit_type="progress"
        context=$(echo "$raw" | tail -n +2 | head -10)
        ;;
    *)
        explicit_type=""
        context=$(echo "$raw" | head -10)
        ;;
esac

# context 파일 즉시 삭제 (일회성)
rm -f "$CONTEXT_FILE"

# 마커만 있고 실제 내용이 없으면 skip
if [[ -z "$context" ]]; then
    exit 0
fi

# ── 타입 결정 ─────────────────────────────────────────
if [[ -n "$explicit_type" ]]; then
    msg_type="$explicit_type"
else
    msg_type="progress"
fi

# ── 턴 카운터 (progress만 증가, 세션 단위 누적) ──────
turn_num=0
if [[ -f "$TURN_FILE" ]]; then
    turn_num=$(cat "$TURN_FILE" 2>/dev/null || echo 0)
fi

if [[ "$msg_type" == "progress" ]]; then
    turn_num=$(( turn_num + 1 ))
    echo "$turn_num" > "$TURN_FILE"
fi

# ── 중복 차단 ────────────────────────────────────────
content_hash=$(echo -n "${msg_type}|${context}|${task_name}" | md5 2>/dev/null || echo -n "${msg_type}|${context}|${task_name}" | md5sum | cut -d' ' -f1)
now_epoch=$(date '+%s')

if [[ -f "$LAST_HASH_FILE" ]] && [[ -f "$LAST_SENT_FILE" ]]; then
    last_hash=$(cat "$LAST_HASH_FILE" 2>/dev/null || echo "")
    last_sent=$(cat "$LAST_SENT_FILE" 2>/dev/null || echo 0)
    diff=$(( now_epoch - last_sent ))

    if [[ "$content_hash" == "$last_hash" ]] && [[ $diff -lt $DEDUP_WINDOW_SEC ]]; then
        exit 0
    fi
fi

echo "$content_hash" > "$LAST_HASH_FILE"
echo "$now_epoch" > "$LAST_SENT_FILE"

# ── 메시지 헤더 ──────────────────────────────────────
case "$msg_type" in
    done)
        emoji="✅"
        title_kor="완료"
        mac_title="[$INSTANCE_LABEL] Claude Code 완료"
        time_label="소요"
        ;;
    waiting)
        emoji="⏸️"
        title_kor="응답 대기"
        mac_title="[$INSTANCE_LABEL] Claude Code 응답 필요"
        time_label="경과"
        ;;
    error)
        emoji="❌"
        title_kor="오류"
        mac_title="[$INSTANCE_LABEL] Claude Code 오류"
        time_label="경과"
        ;;
    progress|*)
        emoji="🔄"
        title_kor="진행 보고"
        mac_title="[$INSTANCE_LABEL] Claude Code 진행 보고"
        time_label="경과"
        ;;
esac

turn_suffix=""
if [[ "$msg_type" == "progress" ]] && [[ $turn_num -gt 0 ]]; then
    turn_suffix="<code>#${turn_num}</code>"
fi

header=$(build_header "$emoji" "$title_kor" "$turn_suffix")

message="${header}"
if [[ -n "$task_name" ]]; then
    task_escaped=$(echo "$task_name" | escape_html)
    message="${message}"$'\n'"📋 ${task_escaped}"
fi
if [[ -n "$elapsed_str" ]]; then
    message="${message}"$'\n'"⏱️ <b>${time_label}</b>: ${elapsed_str}"
fi

# done 메시지에 누적 진행 보고 통계 표시
if [[ "$msg_type" == "done" ]] && [[ $turn_num -gt 0 ]]; then
    message="${message}"$'\n'"📊 <b>진행 보고</b>: ${turn_num}회"
fi

context_escaped=$(echo "$context" | escape_html)
message="${message}"$'\n'"─────────────"
message="${message}"$'\n'"${context_escaped}"

mac_body="${task_name:-${title_kor}}"

# ── DRY RUN 모드 (테스트용) ──────────────────────────
if [[ -n "${NOTIFY_DRY_RUN:-}" ]]; then
    echo "--- [DRY RUN] ---"
    echo "instance_id: $INSTANCE_ID"
    echo "instance_label: $INSTANCE_LABEL"
    echo "runtime_dir: $RUNTIME_DIR"
    echo "msg_type: $msg_type"
    echo "turn_num: $turn_num"
    echo "mac_title: $mac_title"
    echo "telegram message:"
    echo "$message"
    echo "-----------------"
    exit 0
fi

# ── 전송 ─────────────────────────────────────────────
send_macos "$mac_title" "$mac_body"
send_telegram "$message"

# ── [done] 이후 MUTED 전환 ──────────────────────────
# Stop 훅 [done] 이 ✅ 완료 를 발송했으면 MUTED 설정.
# → 뒤이어 SessionEnd 훅이 발화해도 "중복 완료" 메시지가 가지 않는다.
# 새 tracker start 또는 SessionStart 가 MUTED 를 해제한다.
if [[ "$msg_type" == "done" ]]; then
    touch "$MUTED_FILE"
fi
