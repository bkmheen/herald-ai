#!/bin/bash
# notify-question.sh — '응답 대기' 텔레그램 알림 래퍼.
# 사용처: (1) AskUserQuestion PreToolUse 훅 — Claude 의 "중간 질문",
#         (2) Notification 훅 — 권한 승인/입력 요청 프롬프트("수정하시겠습니까?" 류).
# (사용자 지시 2026-05-31: 질문·권한 프롬프트 시 항상 텔레그램 알림)
#
# 동작:
#   - 이미 이번 턴에 [waiting] 등 구체 context 가 기록돼 있으면 그대로 사용(보존).
#   - 없으면 generic [waiting] context 를 fallback 으로 기록.
#   - notify.sh waiting 호출 → CONTEXT 가드 통과 후 발송 (5초 내 동일내용 dedup).
[ "${CLIP2NOTE_SKIP_TRACKER:-}" = "1" ] && exit 0

DIR="$HOME/.claude/skills/task-tracker/scripts"
# shellcheck disable=SC1090
source "$DIR/instance-resolve.sh" 2>/dev/null || exit 0

CTX="${RUNTIME_DIR}/.notify_context"
if [ ! -s "$CTX" ]; then
  printf '%s\n%s\n' '[waiting]' '입력이 필요합니다 — 질문 또는 승인 대기 중입니다.' >"$CTX" 2>/dev/null || true
fi

bash "$DIR/notify.sh" waiting >/dev/null 2>&1 || true
exit 0
