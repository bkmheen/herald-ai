# dirmem 셸 가드 — ~/.zshrc 에서 source (bash bootstrap/dirmem-setup.sh --shell-guard 가 등록)
#
# 바탕화면(~/Desktop 과 그 하위) 밖에서는 "한 디렉토리에 한 세션" 원칙을 지키도록,
# 같은 디렉토리에 이미 claude / codex / agy 세션이 떠 있으면 실행 전에 경고하고 확인을 받는다.
# 바탕화면 안에서는 AI_MEMORY 병렬 규칙으로 동시 실행을 허용하므로 검사하지 않는다.
# 비대화형 실행(파이프·스크립트, claude -p 등)은 검사하지 않는다.

_dirmem_guard() {
  [[ -t 0 && -t 1 ]] || return 0
  local here="${PWD:A}" desk="${HOME:A}/Desktop"
  [[ "$here" == "$desk" || "$here" == "$desk"/* ]] && return 0

  local others
  others=$(lsof -a -d cwd -c claude -c codex -c agy -Fpcn 2>/dev/null | awk -v d="$here" '
    /^p/ { pid = substr($0, 2) }
    /^c/ { cmd = substr($0, 2) }
    /^n/ { if (substr($0, 2) == d) print "  - PID " pid " (" cmd ")" }')
  [[ -z "$others" ]] && return 0

  print -u2 "⚠️  이 디렉토리에서 이미 AI 세션이 실행 중입니다: $here"
  print -u2 "$others"
  print -u2 "바탕화면 밖에서는 한 디렉토리에 한 세션 원칙입니다 (기억 혼선 방지)."
  local ans
  read "ans?그래도 실행하시겠습니까? [y/N] "
  [[ "$ans" == [yY]* ]]
}

claude() { _dirmem_guard && command claude "$@"; }
codex()  { _dirmem_guard && command codex "$@"; }
agy()    { _dirmem_guard && command agy "$@"; }
