#!/usr/bin/env bash
# dirmem-setup.sh — 디렉토리 기억(dirmem)·실행기(marvis) 설치. 재실행 안전.
#
#   bash bootstrap/dirmem-setup.sh                 도구 설치 + 전역 규칙 블록
#   bash bootstrap/dirmem-setup.sh --rules-only    전역 규칙 블록만 (install.sh 가 도구를 이미 설치한 경우)
#   bash bootstrap/dirmem-setup.sh --shell-guard   위 + ~/.zshrc 에 셸 가드 등록 (선택)
#
# 하는 일
#   1. bin/{marvis,dirmem,dirmem-transcripts} → ~/.herald/bin (install.sh 의 vault 도구와 같은 자리)
#      ~/.herald/bin 이 PATH 에 없고 ~/.local/bin 이 있으면 그곳에 링크를 둔다
#   2. ~/.claude/CLAUDE.md · ~/.codex/AGENTS.md · ~/.gemini/GEMINI.md 에 공통 규칙 블록
#      (<!-- dirmem:global:begin --> ~ end) 삽입/교체. 내용이 바뀔 때만 *.bak-dirmem 백업
#   3. (선택) 셸 가드: 맨 claude/codex/agy 실행에도 단일 모드 경고. marvis llm 은 자체 가드가 있다
set -eu
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$REPO_DIR/templates/dirmem"
HERALD_BIN="$HOME/.herald/bin"
TOOLS="marvis dirmem dirmem-transcripts"

ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }

rules_only=0; shell_guard=0
for a in "$@"; do
  case "$a" in
    --rules-only) rules_only=1 ;;
    --shell-guard) shell_guard=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "알 수 없는 인자: $a" >&2; exit 2 ;;
  esac
done

# 1) 도구 ---------------------------------------------------------------
if [ $rules_only -eq 0 ]; then
  mkdir -p "$HERALD_BIN"
  for t in $TOOLS; do install -m 755 "$REPO_DIR/bin/$t" "$HERALD_BIN/$t"; done
  ok "도구 설치 — $TOOLS → $HERALD_BIN"
fi
case ":$PATH:" in
  *":$HERALD_BIN:"*) ok "PATH 에 $HERALD_BIN 있음" ;;
  *)
    if case ":$PATH:" in *":$HOME/.local/bin:"*) true ;; *) false ;; esac; then
      mkdir -p "$HOME/.local/bin"
      for t in $TOOLS; do ln -sfn "$HERALD_BIN/$t" "$HOME/.local/bin/$t"; done
      ok "PATH 에 $HERALD_BIN 이 없어 ~/.local/bin 에 링크 — $TOOLS"
    else
      warn "PATH 에 없습니다. 셸 설정에 추가: export PATH=\"\$HOME/.herald/bin:\$PATH\""
    fi ;;
esac

# 2) 전역 규칙 블록 -----------------------------------------------------
install_rule() {
  local file="$1" agent="$2" tmp
  mkdir -p "$(dirname "$file")"; touch "$file"
  tmp="$(mktemp)"
  awk '/<!-- dirmem:global:begin/{skip=1} !skip{print} /<!-- dirmem:global:end -->/{skip=0}' "$file" > "$tmp"
  { awk '{a[NR]=$0} END{n=NR; while(n>0 && a[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print a[i]}' "$tmp"
    [ -s "$tmp" ] && echo
    sed "s/__AGENT__/$agent/g" "$TPL/global-rule.md"; } > "$tmp.2"
  if cmp -s "$tmp.2" "$file"; then
    ok "규칙 블록 동일 — $file"
  else
    cp "$file" "$file.bak-dirmem"
    mv "$tmp.2" "$file"
    ok "규칙 블록 → $file ($agent)"
  fi
  rm -f "$tmp" "$tmp.2"
}
install_rule "$HOME/.claude/CLAUDE.md" claude
install_rule "$HOME/.codex/AGENTS.md"  codex
install_rule "$HOME/.gemini/GEMINI.md" gemini

# 3) (선택) 셸 가드 -----------------------------------------------------
if [ $shell_guard -eq 1 ]; then
  ZRC="$HOME/.zshrc"; GUARD="$HOME/.herald/dirmem/ai-guard.zsh"
  mkdir -p "$(dirname "$GUARD")"; install -m 644 "$TPL/ai-guard.zsh" "$GUARD"
  if grep -q "herald/dirmem/ai-guard.zsh" "$ZRC" 2>/dev/null; then
    ok "셸 가드 이미 등록됨"
  else
    [ -f "$ZRC" ] && cp "$ZRC" "$ZRC.bak-dirmem"
    { echo; echo '# herald-ai dirmem 셸 가드 (bootstrap/dirmem-setup.sh 가 추가)'
      echo '[ -f "$HOME/.herald/dirmem/ai-guard.zsh" ] && source "$HOME/.herald/dirmem/ai-guard.zsh"'; } >> "$ZRC"
    ok "셸 가드 → $ZRC (새 터미널부터)"
  fi
fi
