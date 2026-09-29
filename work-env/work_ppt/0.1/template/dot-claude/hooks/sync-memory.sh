#!/usr/bin/env bash
# sync-memory.sh — Claude 기억을 프로젝트 디렉토리와 양방향 동기화
#
#   원본(홈):     ~/.claude/projects/<slug>/memory/   Claude Code 가 실제로 읽는 곳.
#                                                     경로에서 슬러그를 만들므로 맥마다 다르다.
#   사본(프로젝트): <프로젝트>/{{MEMORY_DIR}}/           디렉토리와 함께 이동한다.
#
# 왜 필요한가
#   대화 기록도, 홈의 기억 폴더도 컴퓨터 간에 동기화되지 않는다. 사본을 프로젝트 안에 두고
#   세션 시작 때 되돌리면, 다른 맥에서 이 디렉토리를 열어도 같은 기억으로 이어진다.
#
# 모드
#   restore  : SessionStart — 사본 → 홈 (다른 컴퓨터에서 처음 열어도 기억 복원)
#   backup   : Stop         — 홈 → 사본 (매 턴 종료마다. Bash 로 기록한 경우도 포착)
#   (없음)   : PostToolUse  — 기록된 파일이 memory 폴더 안일 때만 backup
#
# 양방향 모두 "더 새로운 파일만 덮어씀"(rsync -u) 이라 어느 쪽에서 고쳐도 최신본이 남는다.
# **삭제는 전파하지 않는다** — 기억을 지울 때는 양쪽에서 지워야 한다.
#
# 의존성: bash · rsync(없으면 cp 로 대체) · python3(PostToolUse 페이로드 파싱, 없으면 grep)
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
DEST="$PROJECT_DIR/{{MEMORY_DIR}}"
# Claude Code 는 프로젝트 절대경로의 영숫자 이외 문자를 모두 '-' 로 바꿔 슬러그를 만든다.
# 이 계산 덕분에 어느 맥·어느 경로에 두어도 훅이 알아서 대응한다.
SLUG="$(printf '%s' "$PROJECT_DIR" | sed 's/[^A-Za-z0-9]/-/g')"
SRC="$HOME/.claude/projects/$SLUG/memory"
MODE="${1:-}"

if [ -z "$MODE" ]; then
  payload="$(cat 2>/dev/null || true)"
  if command -v python3 >/dev/null 2>&1; then
    fpath="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))
except Exception:
    print("")
' 2>/dev/null || true)"
  else
    fpath="$(printf '%s' "$payload" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  fi
  case "$fpath" in
    */.claude/projects/*/memory/*) MODE=backup ;;
    *) exit 0 ;;
  esac
fi

sync_dir() {  # sync_dir <from> <to> : 더 새로운 파일만 복사, 삭제 없음
  local from="$1" to="$2"
  [ -d "$from" ] || return 0
  mkdir -p "$to"
  if command -v rsync >/dev/null 2>&1; then
    rsync -au --exclude '.last_sync' "$from"/ "$to"/ 2>/dev/null
  else
    cp -Rpn "$from"/. "$to"/ 2>/dev/null
  fi
}

case "$MODE" in
  restore) sync_dir "$DEST" "$SRC" ;;
  backup)  sync_dir "$SRC" "$DEST"
           date '+%Y-%m-%d %H:%M:%S' > "$DEST/.last_sync" 2>/dev/null ;;
  *) exit 0 ;;
esac
exit 0
