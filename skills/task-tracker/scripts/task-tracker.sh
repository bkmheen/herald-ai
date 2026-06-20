#!/bin/bash
# task-tracker.sh - Cowork 작업 시간 및 토큰 사용량 추적
# 위치: ~/.claude/skills/task-tracker/scripts/task-tracker.sh
# 사용법: task-tracker.sh {setup|start|stop|status|history} [작업명]

set -euo pipefail

# ── 경로 설정 ─────────────────────────────────────────
# 스크립트 자신의 위치 기준으로 스킬 루트를 결정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_FILE="${SKILL_DIR}/config"
HISTORY_FILE="${SKILL_DIR}/task_history.jsonl"

# 인스턴스별 RUNTIME_DIR 해석 (다중 Claude Code 분리, 2026-05-09~)
# 같은 인스턴스의 훅 (notify.sh / session-start.sh / turn-start.sh) 과 동일한
# /tmp/task-tracker/<instance-id>/ 디렉토리로 수렴한다.
source "${SCRIPT_DIR}/instance-resolve.sh"

STATE_FILE="${RUNTIME_DIR}/.current_task"
TURN_FILE="${RUNTIME_DIR}/.turn_counter"
LAST_HASH_FILE="${RUNTIME_DIR}/.last_hash"
LAST_SENT_FILE="${RUNTIME_DIR}/.last_sent_epoch"
MUTED_FILE="${RUNTIME_DIR}/.muted"
Z_ACTIVE_FILE="${RUNTIME_DIR}/.z-active"
SESSION_START_FILE="${RUNTIME_DIR}/.session_start_epoch"
SESSION_DIR_FILE="${RUNTIME_DIR}/.session_dir"
MISSION_FILE="${RUNTIME_DIR}/.mission"   # "M T": M=미션(주제) 순번, T=그 미션 내 대화 순번

CCUSAGE_CMD="npx --yes ccusage@latest"

mkdir -p "$RUNTIME_DIR"

# ── 유틸리티 ──────────────────────────────────────────
get_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
get_epoch() { date '+%s'; }                                      # 현재 시각 epoch(초)
format_number() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }   # 천 단위 콤마 숫자 포맷

# config 파일에서 플랜 토큰 한도(PLAN_LIMIT)를 읽어 반환 (없으면 0)
load_plan_limit() {
    local plan_limit=0
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        plan_limit="${PLAN_LIMIT:-0}"
    fi
    echo "$plan_limit"
}

# 토큰 한도값 → 플랜 표시명(Pro / Max 5x / Max 20x / Custom) 매핑
get_plan_name() {
    case "$1" in
        44000)  echo "Pro" ;;
        88000)  echo "Max 5x" ;;
        220000) echo "Max 20x" ;;
        *)      echo "Custom ($1 tokens)" ;;
    esac
}

# 오늘(당일) 자 ccusage 사용량 JSON 반환 (실패 시 error JSON + 비정상 종료코드)
get_token_usage() {
    local today
    today=$(date '+%Y%m%d')
    $CCUSAGE_CMD daily --json --since "$today" 2>/dev/null || {
        echo '{"error": "ccusage 실행 실패"}'
        return 1
    }
}

# 이번 달(월초~오늘) 누적 비용($) 합계 반환
get_monthly_cost() {
    local month_start
    month_start=$(date '+%Y%m01')
    local json
    json=$($CCUSAGE_CMD daily --json --since "$month_start" 2>/dev/null) || { echo "0"; return 1; }
    echo "$json" | jq -r 'if .totals then .totals.totalCost // 0 else 0 end' 2>/dev/null || echo "0"
}

get_projected_monthly_cost() {
    # 최근 31일(rolling) 누적 비용을 일평균으로 환산해 31일 월 추정.
    # 월초(경과일수가 작을 때) 분모가 작아 과장되던 문제를 제거 — 항상 31일 창으로 안정적.
    # 31일 창(date -v-30d ~ 오늘)의 일평균 × 31 = 사실상 31일 누적과 동일하나,
    # 데이터 누락일이 있어도 평균 기반이라 일관됨.
    local since
    since=$(date -v-30d '+%Y%m%d' 2>/dev/null) || since=$(date -d '30 days ago' '+%Y%m%d' 2>/dev/null)
    [[ -z "$since" ]] && { echo "0"; return 1; }
    local json
    json=$($CCUSAGE_CMD daily --json --since "$since" 2>/dev/null) || { echo "0"; return 1; }
    local rolling_cost
    rolling_cost=$(echo "$json" | jq -r 'if .totals then .totals.totalCost // 0 else 0 end' 2>/dev/null || echo "0")
    # 일평균 = 31일 누적 / 31, 월예상 = 일평균 × 31
    echo "scale=2; $rolling_cost / 31 * 31" | bc 2>/dev/null || echo "0"
}

get_rolling_30d() {
    # 최근 30일 비용 합계와, 직전 30일 대비 변동률을 한 번의 ccusage 호출로 계산.
    # 출력: "<last30_cost>|<pct>"  (pct 는 부호 포함 정수; 산출 불가 시 빈 값 → 표시부에서 '-')
    #   - last30  : 오늘 포함 최근 30일(period >= cut) 실제 합계 (표시용, 환산 안 함)
    #   - pct     : 일평균(=30일 환산) 기준 직전 30일 대비 변동률
    #
    # ── 짧은 기록 보정 (핵심) ──────────────────────────────────────────────
    # 기존 방식은 last30(30일치) 과 prev30(직전 구간의 "단순 합") 을 직접 비교했다.
    # 기록 시작이 60일보다 가까우면 직전 구간(예: 5일치)의 합이 30일치보다 훨씬 작아
    # 분모가 과소 → 변동률이 비정상적으로 커진다(예: +1817%).
    # → 해결: 양쪽을 "일평균"으로 환산해 비교한다. 일평균 = 합계 / 그 구간의 실제 기록일수.
    #   (일평균 × 30 으로 30일 기준 환산해도 비율은 동일하므로 일평균끼리 비교한다.)
    #   이로써 직전 구간이 5일치여도 30일 단위의 비율로 환산되어 공정하게 비교된다.
    # ── -% 표시 조건 ───────────────────────────────────────────────────────
    # 전체 데이터 기간(가장 오래된 기록일~오늘)이 31일 이하이면 비교할 직전 구간이
    # 사실상 없으므로 pct 를 빈 값으로 둔다(표시부에서 '-%').
    local since cut json last30 last_days prev_sum prev_days pct
    local min_period today_epoch min_epoch span_days
    since=$(date -v-59d '+%Y%m%d' 2>/dev/null) || since=$(date -d '59 days ago' '+%Y%m%d' 2>/dev/null)
    cut=$(date -v-29d '+%Y-%m-%d' 2>/dev/null) || cut=$(date -d '29 days ago' '+%Y-%m-%d' 2>/dev/null)
    [[ -z "$since" || -z "$cut" ]] && { echo "0|"; return; }
    json=$($CCUSAGE_CMD daily --json --since "$since" 2>/dev/null) || { echo "0|"; return; }
    # 최근 30일(period >= cut): 합계 + 기록일수
    last30=$(echo "$json"   | jq -r --arg c "$cut" '[(.daily // [])[] | select(.period >= $c) | (.totalCost // 0)] | add // 0' 2>/dev/null || echo "0")
    last_days=$(echo "$json" | jq -r --arg c "$cut" '[(.daily // [])[] | select(.period >= $c)] | length' 2>/dev/null || echo "0")
    # 직전 30일(period < cut): 합계 + 기록일수
    prev_sum=$(echo "$json"  | jq -r --arg c "$cut" '[(.daily // [])[] | select(.period <  $c) | (.totalCost // 0)] | add // 0' 2>/dev/null || echo "0")
    prev_days=$(echo "$json" | jq -r --arg c "$cut" '[(.daily // [])[] | select(.period <  $c)] | length' 2>/dev/null || echo "0")
    # 전체 데이터 기간(일): 가장 오래된 기록일 ~ 오늘 (포함)
    min_period=$(echo "$json" | jq -r '[(.daily // [])[].period] | min // empty' 2>/dev/null)
    span_days=0
    if [[ -n "$min_period" ]]; then
        today_epoch=$(date '+%s')
        min_epoch=$(date -j -f '%Y-%m-%d' "$min_period" '+%s' 2>/dev/null) || min_epoch=$(date -d "$min_period" '+%s' 2>/dev/null)
        [[ -n "$min_epoch" ]] && span_days=$(( (today_epoch - min_epoch) / 86400 + 1 ))
    fi
    # 변동률: 일평균(=30일 환산) 기준. 총 기간 31일 이하 또는 한쪽 구간 공란이면 산출 불가(빈 값).
    pct=$(awk -v ls="$last30" -v ld="$last_days" -v ps="$prev_sum" -v pd="$prev_days" -v sp="$span_days" 'BEGIN{
        if (sp+0 <= 31) exit;            # 총 데이터 31일 이하 → 비교 불가 → -% 표시
        if (ld+0 <= 0 || pd+0 <= 0) exit;
        la = ls/ld; pa = ps/pd;          # 각 구간 일평균(= 30일 환산값을 30으로 나눈 것)
        if (pa <= 0) exit;
        printf "%+.0f", (la-pa)/pa*100;
    }')
    echo "${last30}|${pct}"
}

# ccusage JSON → "input|output|total|cost" 한 줄로 파싱 (jq, 없으면 node 폴백)
parse_token_summary() {
    local json="$1"
    if command -v jq &>/dev/null; then
        local i o t c
        # ccusage 출력 형식: {"daily": [...], "totals": {...}} 또는 배열 [...]
        i=$(echo "$json" | jq -r 'if .totals then .totals.inputTokens // 0 elif type == "array" then [.[] | .inputTokens // 0] | add // 0 else .inputTokens // 0 end' 2>/dev/null || echo "0")
        o=$(echo "$json" | jq -r 'if .totals then .totals.outputTokens // 0 elif type == "array" then [.[] | .outputTokens // 0] | add // 0 else .outputTokens // 0 end' 2>/dev/null || echo "0")
        t=$(echo "$json" | jq -r 'if .totals then .totals.totalTokens // 0 elif type == "array" then [.[] | .totalTokens // 0] | add // 0 else .totalTokens // 0 end' 2>/dev/null || echo "0")
        c=$(echo "$json" | jq -r 'if .totals then .totals.totalCost // 0 elif type == "array" then [.[] | .cost // 0] | add // 0 else .cost // 0 end' 2>/dev/null || echo "0")
        echo "${i}|${o}|${t}|${c}"
    else
        node -e "
            const d=JSON.parse(process.argv[1]);
            const t=d.totals||(Array.isArray(d)?{inputTokens:d.reduce((s,r)=>s+(r.inputTokens||0),0),outputTokens:d.reduce((s,r)=>s+(r.outputTokens||0),0),totalTokens:d.reduce((s,r)=>s+(r.totalTokens||0),0),totalCost:d.reduce((s,r)=>s+(r.cost||r.totalCost||0),0)}:d);
            console.log([t.inputTokens||0,t.outputTokens||0,t.totalTokens||0,t.totalCost||t.cost||0].join('|'));
        " "$json" 2>/dev/null || echo "0|0|0|0"
    fi
}

# JSON 문자열에서 단일 필드값 추출 (jq, 없으면 node 폴백; fb=기본값)
json_field() {
    local json="$1" field="$2" fb="${3:-}"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".${field} // \"${fb}\"" 2>/dev/null || echo "$fb"
    else
        node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d['${field}']??'${fb}');" <<< "$json" 2>/dev/null || echo "$fb"
    fi
}

# ── SETUP ─────────────────────────────────────────────
cmd_setup() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚙️  Task Tracker 초기 설정"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  📋 의존성 확인 중..."
    echo ""

    local dep_ok=true

    if command -v node &>/dev/null; then
        echo "     ✅ Node.js $(node -v)"
    else
        echo "     ❌ Node.js 미설치 — ccusage 실행에 필요합니다"
        dep_ok=false
    fi

    if command -v npx &>/dev/null; then
        echo "     ✅ npx 사용 가능"
    else
        echo "     ❌ npx 미설치"
        dep_ok=false
    fi

    if command -v jq &>/dev/null; then
        echo "     ✅ jq $(jq --version 2>/dev/null || echo '설치됨')"
    else
        echo "     ⚠️  jq 미설치 (node.js로 대체 가능, 'brew install jq' 권장)"
    fi

    if command -v bc &>/dev/null; then
        echo "     ✅ bc 사용 가능"
    else
        echo "     ⚠️  bc 미설치 (소수점 계산 불가)"
    fi

    echo ""

    if [[ "$dep_ok" != "true" ]]; then
        echo "  ❌ 필수 의존성이 누락되었습니다."
        return 1
    fi

    echo "  📌 Claude 요금제를 선택하세요:"
    echo ""
    echo "     1) Pro          — \$20/월,  ~44,000 tokens / 5시간 블록"
    echo "     2) Max 5x       — \$100/월, ~88,000 tokens / 5시간 블록"
    echo "     3) Max 20x      — \$200/월, ~220,000 tokens / 5시간 블록"
    echo "     4) 직접 입력     — 커스텀 토큰 한도 지정"
    echo ""

    local choice
    read -rp "  선택 [1-4]: " choice

    local plan_limit plan_name
    case "$choice" in
        1) plan_limit=44000;  plan_name="Pro" ;;
        2) plan_limit=88000;  plan_name="Max 5x" ;;
        3) plan_limit=220000; plan_name="Max 20x" ;;
        4)
            read -rp "  토큰 한도 입력 (숫자): " plan_limit
            if ! [[ "$plan_limit" =~ ^[0-9]+$ ]]; then
                echo "  ❌ 올바른 숫자를 입력하세요."
                return 1
            fi
            plan_name="Custom"
            ;;
        *) echo "  ❌ 올바른 번호를 선택하세요 (1-4)."; return 1 ;;
    esac

    cat > "$CONFIG_FILE" <<EOF
# Task Tracker 설정
# 생성: $(get_timestamp)
# 변경: 'task-tracker.sh setup' 재실행 또는 이 파일 직접 수정
PLAN_NAME="${plan_name}"
PLAN_LIMIT=${plan_limit}
EOF

    echo ""
    echo "  ✅ 설정 완료!"
    echo ""
    echo "     플랜:      ${plan_name}"
    echo "     토큰 한도: $(format_number ${plan_limit}) tokens / 5시간 블록"
    echo "     설정 파일: ${CONFIG_FILE}"
    echo ""

    echo "  🔍 ccusage 연결 테스트 중..."
    if $CCUSAGE_CMD daily --json --since "$(date '+%Y%m%d')" &>/dev/null; then
        echo "     ✅ ccusage 정상 동작"
    else
        echo "     ⚠️  ccusage 실행 실패"
        echo "        'npx --yes ccusage@latest daily'를 수동으로 실행해 보세요"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🎉 설정이 완료되었습니다!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ── START ─────────────────────────────────────────────
# 미션(주제)·대화 카운터 갱신. 신호는 Claude 가 매 start 시 넘긴다:
#   - "new"          → 새 주제: 미션 +1, 대화 = 1
#   - "cont"(또는 미지정) → 같은 주제 연장: 대화 +1
#   - 세션 첫 작업(.mission 없음) → 미션 = 1, 대화 = 1 (신호 무시)
update_mission() {
    local sig="${1:-cont}" m=0 t=0
    # `|| true`: set -e 환경에서 개행 없는 파일을 read 하면 EOF 로 1 을 반환해
    # 스크립트가 중단되던 버그 방지 (값은 정상적으로 채워진다).
    if [[ -f "$MISSION_FILE" ]]; then
        read -r m t < "$MISSION_FILE" 2>/dev/null || true
    fi
    [[ "$m" =~ ^[0-9]+$ ]] || m=0
    [[ "$t" =~ ^[0-9]+$ ]] || t=0
    if [[ $m -eq 0 ]]; then
        m=1; t=1
    elif [[ "$sig" == "new" ]]; then
        m=$((m + 1)); t=1
    else
        t=$((t + 1))
    fi
    # 개행 포함 저장 — 이후 read 가 EOF 로 실패하지 않도록.
    printf '%s %s\n' "$m" "$t" > "$MISSION_FILE" 2>/dev/null || true
}

# 현재 "[미션-대화]" 카운터를 echo (없으면 1-1).
read_mission() {
    local m=1 t=1
    if [[ -f "$MISSION_FILE" ]]; then
        read -r m t < "$MISSION_FILE" 2>/dev/null || true
    fi
    [[ "$m" =~ ^[0-9]+$ ]] || m=1
    [[ "$t" =~ ^[0-9]+$ ]] || t=1
    echo "${m}-${t}"
}

# start 서브커맨드: 작업 시작 기록(STATE_FILE 생성)·미션 카운터 갱신·시작 토큰 스냅샷
cmd_start() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo ""
        echo "  ⚠️  초기 설정이 필요합니다. setup을 먼저 실행합니다."
        echo ""
        cmd_setup
        [[ ! -f "$CONFIG_FILE" ]] && return 1
    fi

    local task_name="${1:-unnamed_task}"
    local mission_sig="${2:-cont}"
    update_mission "$mission_sig"
    local timestamp epoch
    timestamp=$(get_timestamp)
    epoch=$(get_epoch)

    local plan_limit
    plan_limit=$(load_plan_limit)
    local plan_name
    plan_name=$(get_plan_name "$plan_limit")

    echo ""
    echo "  🚀 작업 시작: ${task_name}"
    echo ""
    echo "  📅 시작 시간: ${timestamp}"
    echo "  💳 플랜: ${plan_name} ($(format_number ${plan_limit}) tokens/블록)"
    echo ""

    echo "  📊 현재 토큰 사용량 (오늘 누적):"
    local usage_json token_data
    usage_json=$(get_token_usage) || true

    if echo "$usage_json" | grep -q '"error"' 2>/dev/null; then
        echo "     ⚠️  토큰 조회 실패 — ccusage를 확인하세요"
        token_data="0|0|0|0"
    else
        token_data=$(parse_token_summary "$usage_json")
        IFS='|' read -r input_t output_t total_t cost_val <<< "$token_data"
        echo "     Input:  $(format_number "${input_t}") tokens"
        echo "     Output: $(format_number "${output_t}") tokens"
        echo "     Total:  $(format_number "${total_t}") tokens"
        printf "     Cost:   \$%.4f\n" "${cost_val}"
    fi

    echo ""

    cat > "$STATE_FILE" <<EOF
{
  "task_name": "${task_name}",
  "start_time": "${timestamp}",
  "start_epoch": ${epoch},
  "start_tokens": "${token_data}",
  "plan_limit": ${plan_limit}
}
EOF

    # 새 task 시작 시 turn 단위 notify 상태만 리셋
    # - 중복 해시 / last_sent / MUTED / stale context 만 제거
    # - TURN_FILE 은 세션 단위 카운터이므로 여기서 삭제하지 않는다
    #   (SessionStart 훅에서만 리셋 → "세션 내 몇 번째 응답" 의미가 유지됨)
    # - MUTED 제거: 이전 [done]/SessionEnd 의 muting 해제 (방어적)
    rm -f "$LAST_HASH_FILE" "$LAST_SENT_FILE" "$MUTED_FILE" "${RUNTIME_DIR}/.notify_context"

    # 세션 시작 시각 폴백: SessionStart 훅이 아직 설치되지 않았거나
    # 발화하지 않은 경우에도 "경과 시간"이 세션 기준이 되도록
    # 최초 tracker start 시 session_start_epoch를 생성한다.
    if [[ ! -f "$SESSION_START_FILE" ]]; then
        echo "$epoch" > "$SESSION_START_FILE"
    fi

    # 세션 시작 디렉토리명 폴백: SessionStart 훅(session-start.sh)이 기록하지만,
    # 훅 미발화 시에도 stop 요약의 "[디렉토리]" 접두가 나오도록 최초 start 시 보강.
    # 세션 단위로 고정 — 이미 있으면 덮어쓰지 않는다.
    if [[ ! -f "$SESSION_DIR_FILE" ]]; then
        printf '%s' "${PWD##*/}" > "$SESSION_DIR_FILE" 2>/dev/null || true
    fi
}

# ── STOP ──────────────────────────────────────────────
cmd_stop() {
    if [[ ! -f "$STATE_FILE" ]]; then
        # 이중 stop 호출 또는 start 누락 시에도 에러로 취급하지 않는다.
        # 지난 작업 정보가 있으면 참고용으로 출력, exit 0 으로 정상 종료.
        if [[ -f "${RUNTIME_DIR}/.last_task" ]]; then
            local _lt _tn _st
            _lt=$(cat "${RUNTIME_DIR}/.last_task" 2>/dev/null || echo "{}")
            _tn=$(json_field "$_lt" "task_name" "?")
            _st=$(json_field "$_lt" "start_time" "?")
            echo "ℹ️  진행 중인 작업이 없습니다 (이미 종료됨: ${_tn} @ ${_st})"
        else
            echo "ℹ️  진행 중인 작업이 없습니다."
        fi
        return 0
    fi

    local start_data
    start_data=$(cat "$STATE_FILE")

    local task_name start_time start_epoch start_tokens plan_limit
    task_name=$(json_field "$start_data" "task_name" "unnamed")
    start_time=$(json_field "$start_data" "start_time" "")
    start_epoch=$(json_field "$start_data" "start_epoch" "0")
    start_tokens=$(json_field "$start_data" "start_tokens" "0|0|0|0")
    plan_limit=$(json_field "$start_data" "plan_limit" "0")

    local config_limit
    config_limit=$(load_plan_limit)
    [[ "$config_limit" -gt 0 ]] && plan_limit="$config_limit"

    local plan_name
    plan_name=$(get_plan_name "$plan_limit")

    local end_time end_epoch
    end_time=$(get_timestamp)
    end_epoch=$(get_epoch)

    local elapsed=$(( end_epoch - start_epoch ))
    local hours=$(( elapsed / 3600 ))
    local minutes=$(( (elapsed % 3600) / 60 ))
    local seconds=$(( elapsed % 60 ))
    local duration_str
    if [[ $hours -gt 0 ]]; then
        duration_str="${hours}시간 ${minutes}분 ${seconds}초"
    elif [[ $minutes -gt 0 ]]; then
        duration_str="${minutes}분 ${seconds}초"
    else
        duration_str="${seconds}초"
    fi

    local usage_json end_token_data
    usage_json=$(get_token_usage) || true
    end_token_data=$(parse_token_summary "$usage_json")

    IFS='|' read -r s_input s_output s_total s_cost <<< "$start_tokens"
    IFS='|' read -r e_input e_output e_total e_cost <<< "$end_token_data"

    local d_input=$(( e_input - s_input ))
    local d_output=$(( e_output - s_output ))
    local d_total=$(( e_total - s_total ))
    local d_cost
    d_cost=$(echo "$e_cost - $s_cost" | bc 2>/dev/null || echo "0")

    local usage_pct="N/A"
    if [[ $e_total -gt 0 && $plan_limit -gt 0 ]]; then
        usage_pct=$(echo "scale=1; $e_total * 100 / $plan_limit" | bc 2>/dev/null || echo "N/A")
    fi

    local pct_icon="🟢"
    if [[ "$usage_pct" != "N/A" ]]; then
        local pct_int=${usage_pct%.*}
        [[ $pct_int -ge 80 ]] && pct_icon="🔴"
        [[ $pct_int -ge 50 && $pct_int -lt 80 ]] && pct_icon="🟡"
    fi

    local roll last30 chg chg_str session_dir
    roll=$(get_rolling_30d)
    last30=${roll%%|*}
    chg=${roll#*|}
    # 변동률 산출 불가(총 데이터 31일 이하 등)면 '-%' 로 표시
    if [[ -n "$chg" ]]; then
        chg_str=" (${chg} %)"
    else
        chg_str=" (-%)"
    fi

    # 세션 시작 디렉토리명 (맨 앞 "[디렉토리]" 접두). 훅/폴백이 기록한 .session_dir
    # 우선, 없으면 현재 PWD basename.
    session_dir=""
    [[ -f "$SESSION_DIR_FILE" ]] && session_dir=$(cat "$SESSION_DIR_FILE" 2>/dev/null)
    [[ -z "$session_dir" ]] && session_dir="${PWD##*/}"

    # IP 마지막 옥텟 접미 (다양한 시스템 구분용): "<디렉토리명>@<옥텟>"
    # 텔레그램 라벨(instance-resolve.sh)과 동일 규칙으로 채팅 한 줄 요약도 맞춘다.
    local ip_addr def_if ip_oct
    def_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')
    [[ -n "$def_if" ]] && ip_addr=$(ipconfig getifaddr "$def_if" 2>/dev/null)
    [[ -z "$ip_addr" ]] && ip_addr=$(ipconfig getifaddr en0 2>/dev/null)
    [[ -z "$ip_addr" ]] && ip_addr=$(ipconfig getifaddr en1 2>/dev/null)
    [[ -z "$ip_addr" ]] && ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip_addr" ]] && ip_addr=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -1)
    ip_oct=$(printf '%s' "${ip_addr##*.}" | tr -dc '0-9')
    [[ -n "$ip_oct" ]] && session_dir="${session_dir}@${ip_oct}"

    # 토큰을 천 단위(K)로 변환 (히스토리/기타 참조용)
    local d_total_k e_total_k
    d_total_k=$(echo "scale=1; $d_total / 1000" | bc 2>/dev/null || echo "0")
    e_total_k=$(echo "scale=1; $e_total / 1000" | bc 2>/dev/null || echo "0")

    # 미션-대화 카운터 (M=주제 순번, T=그 주제 내 대화 순번)
    local mission_tag inst_disc
    mission_tag=$(read_mission)
    # 인스턴스 식별자(claude PID 끝 4자) — 같은 디렉토리에서 여러 claude 가 동시에
    # 돌 때 메시지를 구분(A안, 항상 표시). 카운터 자체는 이미 인스턴스별로 분리됨.
    inst_disc="${INSTANCE_ID##*-}"
    inst_disc="${inst_disc: -4}"
    [[ -z "$inst_disc" ]] && inst_disc="?"

    # 한 줄 요약 출력: [디렉토리·PID4:M-T] ✅ 작업 | ⏱️ 소요 | 월누적 $X (±N %)
    # 디렉토리·PID4 = 같은 디렉토리 다중 인스턴스 구분, M=주제 순번, T=그 주제의
    # 대화 순번, ⏱️=이번(M-T) 대화 소요시간. 월누적=최근 30일 합계,
    # (±N %)=직전 30일 대비 변동률(일평균=30일 환산 기준). 총 데이터 31일 이하면 (-%).
    printf "[%s·%s:%s] ✅ %s | ⏱️ %s | 월누적 \$%.1f%s\n" \
        "$session_dir" "$inst_disc" "$mission_tag" "$task_name" "$duration_str" "$last30" "$chg_str"
    echo ""

    echo "{\"task\":\"${task_name}\",\"start\":\"${start_time}\",\"end\":\"${end_time}\",\"duration_sec\":${elapsed},\"duration\":\"${duration_str}\",\"tokens_used\":${d_total},\"cost\":${d_cost},\"plan\":\"${plan_name}\"}" >> "$HISTORY_FILE"

    # .last_task 보존 — Notification 훅이 stop 이후에도 작업 정보를 참조할 수 있도록
    cp -f "$STATE_FILE" "${RUNTIME_DIR}/.last_task" 2>/dev/null || true
    rm -f "$STATE_FILE"
}

# ── STATUS ────────────────────────────────────────────
cmd_status() {
    echo ""
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        echo "  💳 플랜: ${PLAN_NAME:-미설정} ($(format_number ${PLAN_LIMIT:-0}) tokens/블록)"
    else
        echo "  ⚠️  설정 없음 — 'task-tracker.sh setup'을 실행하세요"
    fi

    if [[ -f "$STATE_FILE" ]]; then
        local sd tn st
        sd=$(cat "$STATE_FILE")
        tn=$(json_field "$sd" "task_name" "?")
        st=$(json_field "$sd" "start_time" "?")
        echo "  📌 진행 중: ${tn} (${st}~)"
    else
        echo "  📌 진행 중인 작업 없음"
    fi

    if [[ -f "$HISTORY_FILE" ]]; then
        local td tc
        td=$(date '+%Y-%m-%d')
        tc=$(grep -c "\"start\":\"${td}" "$HISTORY_FILE" 2>/dev/null || echo "0")
        echo "  📊 오늘 완료한 작업: ${tc}건"
    fi

    echo ""
    echo "  🪪 인스턴스: ${INSTANCE_LABEL}  (id=${INSTANCE_ID})"
    echo ""
    echo "  📂 경로:"
    echo "     스킬: ${SKILL_DIR}"
    echo "     설정: ${CONFIG_FILE}"
    echo "     런타임: ${RUNTIME_DIR}"
    echo ""
}

# ── HISTORY ───────────────────────────────────────────
cmd_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "  📭 작업 히스토리가 없습니다."
        return 0
    fi
    local count="${1:-10}"
    echo ""
    echo "  📜 최근 작업 히스토리 (최대 ${count}건)"
    echo "  ─────────────────────────────────────────────"
    tail -n "$count" "$HISTORY_FILE" | while IFS= read -r line; do
        if command -v jq &>/dev/null; then
            printf "  %s | %-30s | %s | %s tokens\n" \
                "$(echo "$line" | jq -r '.start')" \
                "$(echo "$line" | jq -r '.task')" \
                "$(echo "$line" | jq -r '.duration')" \
                "$(format_number "$(echo "$line" | jq -r '.tokens_used')")"
        else
            echo "  $line"
        fi
    done
    echo ""
}

# ── MUTE-Z / UNMUTE-Z ─────────────────────────────────
# Atelier Task Z 가 자율 실행 중인 동안 매 turn 의 진행 보고 알림을 차단한다.
# Z 외부 (사용자 프롬프트 / Z 자체 종료 / Z 자체 중단) 에서 unmute 호출하여 알림 정상화.
# turn-start.sh 가 .z-active 존재 시 자동 unmute (사용자 프롬프트 = Z 외부 개입 신호).
cmd_mute_z() {
    touch "$MUTED_FILE" "$Z_ACTIVE_FILE"
    echo "  🔕 Atelier Task Z mute (.muted + .z-active set)"
}

# Task Z mute 해제: .muted + .z-active 제거 → 알림 정상화
cmd_unmute_z() {
    rm -f "$MUTED_FILE" "$Z_ACTIVE_FILE"
    echo "  🔔 Atelier Task Z unmute (.muted + .z-active cleared)"
}

# ── MAIN ──────────────────────────────────────────────
case "${1:-help}" in
    setup)    cmd_setup ;;
    start)    cmd_start "${2:-}" "${3:-}" ;;
    stop)     cmd_stop ;;
    status)   cmd_status ;;
    history)  cmd_history "${2:-10}" ;;
    mute-z)   cmd_mute_z ;;
    unmute-z) cmd_unmute_z ;;
    *)
        echo ""
        echo "  Task Tracker — Cowork 작업 시간·토큰 추적"
        echo ""
        echo "  Commands:"
        echo "    setup          초기 설정 (플랜 선택, 의존성 확인)"
        echo "    start [name]   작업 시작 (시간·토큰 스냅샷)"
        echo "    stop           작업 종료 (소요시간·토큰 증분 보고)"
        echo "    status         현재 상태"
        echo "    history [n]    최근 작업 히스토리 (기본 10건)"
        echo "    mute-z         Atelier Task Z 자율 실행 mute"
        echo "    unmute-z       Atelier Task Z mute 해제 + 알림 정상화"
        echo ""
        exit 1
        ;;
esac
