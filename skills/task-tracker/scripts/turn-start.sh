#!/bin/bash
# turn-start.sh — UserPromptSubmit 훅 핸들러
#
# 목적:
#   매 사용자 프롬프트 제출 시점의 epoch 를 .turn_start_epoch 에 기록한다.
#   notify.sh 가 이 값을 기준으로 "현재 채팅 (턴) 소요 시간" 을 계산한다.
#
# 효과:
#   텔레그램 알림의 경과 시간이 세션 누적이 아닌 **현재 턴 소요 시간** 으로 표시됨.
#   질문 → 응답대기/완료 또는 응답대기 답변 → 다음 응답대기/완료 사이 시간.
#
# 다중 인스턴스 분리 (2026-05-09~):
#   /tmp/task-tracker/<instance-id>/ 자기 인스턴스의 디렉토리만 다룬다.
#   다른 인스턴스의 .muted / .z-active 는 절대 건드리지 않음.
#
# 설치:
#   ~/.claude/settings.json 의 hooks.UserPromptSubmit 배열에 명령 추가.

set -uo pipefail

# 인스턴스별 RUNTIME_DIR 해석
source "$(dirname "$0")/instance-resolve.sh"

# 매 UserPromptSubmit 마다 덮어쓰기 (현재 턴의 시작 시각)
date '+%s' > "$RUNTIME_DIR/.turn_start_epoch"

# 사용자 프롬프트 = 새 turn 시작 = 알림 채널 항상 활성화 (2026-05-05 v2 강화)
# 두 케이스 모두 해제 (이 인스턴스의 .muted / .z-active 만):
#   ① Z 자율 실행 중 외부 개입 (.z-active 가 있는 경우)
#   ② 직전 [done] 발송 후 자동 set 된 .muted (notify.sh) — 다음 응답 알림 보장
# 이로써 매 turn 의 Stop 훅이 .muted 가드에 막혀 알림이 누락되는 사고 방지.
rm -f "$RUNTIME_DIR/.muted" "$RUNTIME_DIR/.z-active"

# 정상 종료 (블록 metadata 출력 없음)
exit 0
