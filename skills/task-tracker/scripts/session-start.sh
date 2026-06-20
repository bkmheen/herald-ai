#!/bin/bash
# session-start.sh — SessionStart 훅 핸들러
#
# 목적:
#   1. 세션 시작 시각을 .session_start_epoch 에 기록 (경과 시간의 기준)
#   2. 세션 단위 상태 파일 리셋 (턴 카운터, MUTED, 중복 해시 등)
#
# 다중 인스턴스 분리 (2026-05-09~):
#   /tmp/task-tracker/<instance-id>/ 자기 인스턴스의 디렉토리만 다룬다.
#   다른 Claude Code 인스턴스의 상태는 절대 건드리지 않음.
#
# 설치:
#   ~/.claude/settings.json 의 hooks.SessionStart 에서 호출

set -uo pipefail

# 인스턴스별 RUNTIME_DIR 해석
source "$(dirname "$0")/instance-resolve.sh"

SESSION_START_FILE="$RUNTIME_DIR/.session_start_epoch"

# 세션 시작 epoch 기록 (항상 덮어쓰기 — 새 세션의 기준으로 사용)
date '+%s' > "$SESSION_START_FILE"

# 세션이 처음 시작한 디렉토리명 기록 (stop 요약의 맨 앞 "[디렉토리]" 접두에 사용).
# SessionStart 훅의 cwd = claude 를 실행한 디렉토리 = 세션 시작 디렉토리.
printf '%s' "${PWD##*/}" > "$RUNTIME_DIR/.session_dir" 2>/dev/null || true

# 세션 단위 상태 리셋 (이 인스턴스 디렉토리 안에서만)
# - .turn_counter: 세션 내 진행 보고 번호 (세션마다 1부터)
# - .muted: 이전 세션의 SessionEnd 가 남긴 플래그 제거
# - .last_hash / .last_sent_epoch: 이전 세션의 중복 차단 흔적 제거
# - .notify_context: 이전 세션 잔존 컨텍스트
# - .pending_done_*: 예약 발송 흔적 (현재 미사용이지만 방어적 정리)
# - .turn_start_epoch: 첫 UserPromptSubmit 이 다시 채울 것
# - .label: 라벨을 이번 세션 시작시각으로 다시 만들도록 제거(디렉토리·세션 식별자)
rm -f "$RUNTIME_DIR/.turn_counter" \
      "$RUNTIME_DIR/.last_hash" \
      "$RUNTIME_DIR/.last_sent_epoch" \
      "$RUNTIME_DIR/.muted" \
      "$RUNTIME_DIR/.notify_context" \
      "$RUNTIME_DIR/.pending_done" \
      "$RUNTIME_DIR/.pending_done_pid" \
      "$RUNTIME_DIR/.turn_start_epoch" \
      "$RUNTIME_DIR/.mission" \
      "$RUNTIME_DIR/.label"

exit 0
