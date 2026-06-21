#!/bin/bash
# instance-resolve.sh — task-tracker 인스턴스별 런타임 디렉토리·라벨 해석
#
# 사용법: 다른 스크립트가 `source` 하여 다음 변수를 받는다.
#   - RUNTIME_DIR     : /tmp/task-tracker/<instance-id>  (없으면 자동 생성)
#   - INSTANCE_ID     : 인스턴스 식별자 (예: "claude-98166")
#   - INSTANCE_LABEL  : 메시지 헤더용 짧은 라벨 (예: "Atelier·8166")
#
# 인스턴스 ID 결정 우선순위:
#   1. $TASK_TRACKER_INSTANCE     — 명시적 override (테스트용)
#   2. 프로세스 트리를 거슬러 올라가 ancestor `claude` 프로세스 PID
#      → 훅 스크립트 / Bash 툴 호출 모두 같은 claude 프로세스의 자식이므로
#        같은 PID로 수렴 (= 같은 RUNTIME_DIR)
#   3. PPID 폴백 (claude ancestor 미발견 시 — 단독 실행, 테스트 등)
#
# 라벨 결정 우선순위:
#   1. $TASK_TRACKER_LABEL        — 명시적 override
#   2. 캐시된 RUNTIME_DIR/.label  — 같은 세션에서 한 번 결정되면 고정
#   3. basename(PWD) + "·" + ID 끝 4자  (예: Atelier·8166)
#   4. "claude·" + ID 끝 4자
#
# 라벨은 RUNTIME_DIR/.label 에 캐시된다 (첫 writer 가 결정).

# 주의: source 되는 스크립트이므로 set -e 류는 건드리지 않는다.

_tt_root="${TASK_TRACKER_ROOT:-/tmp/task-tracker}"
mkdir -p "$_tt_root" 2>/dev/null || true

# ── 프로세스 트리 walk ────────────────────────────────
_tt_find_claude_pid() {
    local pid=$$
    local depth=0
    local cmd ppid
    while [[ $depth -lt 32 ]] && [[ -n "${pid:-}" ]] && [[ "$pid" != "0" ]] && [[ "$pid" != "1" ]]; do
        cmd=$(ps -o comm= -p "$pid" 2>/dev/null | head -1)
        cmd="${cmd##*/}"   # basename
        cmd="${cmd# }"
        cmd="${cmd% }"
        if [[ "$cmd" == "claude" ]]; then
            echo "$pid"
            return 0
        fi
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ -z "$ppid" ]] || [[ "$ppid" == "$pid" ]]; then
            return 1
        fi
        pid="$ppid"
        depth=$((depth + 1))
    done
    return 1
}

# ── ID 해석 ───────────────────────────────────────────
if [[ -n "${TASK_TRACKER_INSTANCE:-}" ]]; then
    INSTANCE_ID="$TASK_TRACKER_INSTANCE"
else
    _tt_cpid=$(_tt_find_claude_pid 2>/dev/null || true)
    if [[ -n "${_tt_cpid:-}" ]]; then
        INSTANCE_ID="claude-${_tt_cpid}"
    else
        INSTANCE_ID="ppid-${PPID}"
    fi
    unset _tt_cpid
fi

# 안전한 파일명만 허용 (영숫자·하이픈·언더스코어)
INSTANCE_ID=$(printf '%s' "$INSTANCE_ID" | tr -c 'A-Za-z0-9-_' '_' | head -c 48)
[[ -z "$INSTANCE_ID" ]] && INSTANCE_ID="default"

RUNTIME_DIR="$_tt_root/$INSTANCE_ID"
mkdir -p "$RUNTIME_DIR" 2>/dev/null || true

# ── 라벨 결정 (캐시 우선) ─────────────────────────────
_tt_label_file="$RUNTIME_DIR/.label"
INSTANCE_LABEL=""

if [[ -f "$_tt_label_file" ]]; then
    INSTANCE_LABEL=$(cat "$_tt_label_file" 2>/dev/null || true)
fi

if [[ -z "$INSTANCE_LABEL" ]]; then
    if [[ -n "${TASK_TRACKER_LABEL:-}" ]]; then
        INSTANCE_LABEL="$TASK_TRACKER_LABEL"
    else
        # cwd basename (디렉토리명)
        _tt_base=""
        if [[ -n "${PWD:-}" ]]; then
            _tt_base="${PWD##*/}"
        fi
        [[ -z "$_tt_base" || "$_tt_base" == "/" ]] && _tt_base="claude"

        # IP 마지막 옥텟 접미 (다양한 시스템 구분용): "<디렉토리명>@<옥텟>"
        # 호스트명은 길어질 수 있어, 로컬 IP 의 마지막 숫자(최대 3자리)만 붙여 짧게 구분한다.
        # 여러 머신에서 같은 디렉토리명을 써도 알림이 섞이지 않는다. (예: MarvisHome@221)
        _tt_ip=""
        # `|| true`: route -n get default 는 macOS 전용. Linux 에서는 exit 3 을 내므로
        # pipefail 을 켠 caller 가 source 했을 때 중단되지 않도록 가드. 아래 hostname -I 폴백이 Linux 커버.
        _tt_defif=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}') || true
        [[ -n "$_tt_defif" ]] && _tt_ip=$(ipconfig getifaddr "$_tt_defif" 2>/dev/null)
        [[ -z "$_tt_ip" ]] && _tt_ip=$(ipconfig getifaddr en0 2>/dev/null)
        [[ -z "$_tt_ip" ]] && _tt_ip=$(ipconfig getifaddr en1 2>/dev/null)
        # 폴백: Linux 등 — hostname -I 첫 주소, 그래도 없으면 ifconfig 비루프백 inet
        [[ -z "$_tt_ip" ]] && _tt_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -z "$_tt_ip" ]] && _tt_ip=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -1)
        _tt_oct="${_tt_ip##*.}"
        _tt_oct=$(printf '%s' "$_tt_oct" | tr -dc '0-9')
        if [[ -n "$_tt_oct" ]]; then
            _tt_base="${_tt_base}@${_tt_oct}"
        fi

        # 세션 시작 시각 (여러 디렉토리/세션의 메시지를 구분하기 위한 식별자)
        # .session_start_epoch(SessionStart 훅이 기록)을 "MM/DD HH:MM" 으로 포맷.
        # 콜론 포함 시각이라 PID 등 숫자로 오인되지 않는다. 없으면 현재 시각으로 폴백.
        _tt_stamp=""
        _tt_epoch_file="$RUNTIME_DIR/.session_start_epoch"
        if [[ -f "$_tt_epoch_file" ]]; then
            _tt_ep=$(cat "$_tt_epoch_file" 2>/dev/null | tr -dc '0-9')
            # epoch → "MM/DD HH:MM" : macOS(date -r) 우선, Linux(date -d @) 폴백
            [[ -n "$_tt_ep" ]] && _tt_stamp=$(date -r "$_tt_ep" '+%m/%d %H:%M' 2>/dev/null || date -d "@$_tt_ep" '+%m/%d %H:%M' 2>/dev/null)
        fi
        [[ -z "$_tt_stamp" ]] && _tt_stamp=$(date '+%m/%d %H:%M' 2>/dev/null)

        INSTANCE_LABEL="${_tt_base}·${_tt_stamp}"
        unset _tt_base _tt_stamp _tt_epoch_file _tt_ep _tt_ip _tt_defif _tt_oct
    fi

    # 64자 이내로 truncate (호스트명 접두로 길어진 라벨 수용)
    INSTANCE_LABEL="${INSTANCE_LABEL:0:64}"

    # 첫 writer 가 캐시 결정 (race 시 한쪽이 이김 — OK)
    echo "$INSTANCE_LABEL" > "$_tt_label_file" 2>/dev/null || true
fi

unset _tt_label_file _tt_root
export RUNTIME_DIR INSTANCE_ID INSTANCE_LABEL
