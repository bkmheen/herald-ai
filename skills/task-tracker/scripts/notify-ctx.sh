#!/bin/bash
# notify-ctx.sh — Claude 응답 직전에 알림 컨텍스트를 인스턴스별 경로에 기록한다.
#
# 사용법 (Claude 가 heredoc 으로 호출):
#   ~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
#   [done]
#   ...요약...
#   NOTIFY_EOF
#
# 동작:
#   - instance-resolve.sh 로 자기 인스턴스의 RUNTIME_DIR 해석
#   - stdin 을 RUNTIME_DIR/.notify_context 에 atomic 으로 기록
#   - 다른 Claude Code 인스턴스의 컨텍스트와 절대 충돌하지 않음
#
# 옵션:
#   --print  : 기록한 위치 + 라벨을 stderr 에 한 줄로 표시 (디버그용)

set -uo pipefail

PRINT=0
if [[ "${1:-}" == "--print" ]]; then
    PRINT=1
    shift
fi

# 인스턴스 해석
source "$(dirname "$0")/instance-resolve.sh"

CTX_FILE="$RUNTIME_DIR/.notify_context"
TMP_FILE="$RUNTIME_DIR/.notify_context.tmp.$$"

# stdin → tmp → atomic rename
cat > "$TMP_FILE"
mv -f "$TMP_FILE" "$CTX_FILE"

if [[ "$PRINT" == "1" ]]; then
    echo "notify-ctx → $CTX_FILE  (label: $INSTANCE_LABEL)" >&2
fi
