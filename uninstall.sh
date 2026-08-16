#!/usr/bin/env bash
# herald-ai uninstaller — settings.json 의 herald 훅 제거 + (선택) 스킬 삭제
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
HERALD_BIN="$HOME/.herald/bin"          # install.sh [4/7] 이 설치하는 곳

say()  { printf '%s\n' "$*"; }

say "── herald-ai 제거 ──"
if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%s 2>/dev/null || echo bak)"
    SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os
p=os.environ['SETTINGS']
cfg=json.load(open(p))
hooks=cfg.get('hooks',{})
MARK='task-tracker/scripts'
for ev in list(hooks):
    hooks[ev]=[e for e in hooks[ev] if MARK not in json.dumps(e)]
    if not hooks[ev]:
        del hooks[ev]
json.dump(cfg, open(p,'w'), ensure_ascii=False, indent=2)
print("  ✅ settings.json 에서 herald 훅 제거")
PY
fi

# /session-log · /session-save 커맨드 제거
for _cmd in session-log session-save; do
    if [ -f "$COMMANDS_DIR/$_cmd.md" ]; then
        rm -f "$COMMANDS_DIR/$_cmd.md"
        say "  ✅ /$_cmd 커맨드 제거"
    fi
done

# vault 도구 제거 — install.sh 가 설치한 것만 골라 지운다.
# ~/.herald/ 자체는 건드리지 않는다: vault.conf·machine_id·투입키가 거기 있고,
# 그것들은 **사용자의 구성**이지 이 패키지가 설치한 물건이 아니다.
if [ -d "$HERALD_BIN" ]; then
    _removed=""
    for _t in "$HERALD_BIN"/herald-* "$HERALD_BIN"/herald_*.py; do
        [ -f "$_t" ] || continue
        rm -f "$_t"
        _removed="$_removed $(basename "$_t")"
    done
    rm -rf "$HERALD_BIN/__pycache__"
    rmdir "$HERALD_BIN" 2>/dev/null || true      # 남의 파일이 있으면 지우지 않는다
    [ -n "$_removed" ] && say "  ✅ vault 도구 제거 —$_removed"
fi

say ""
say "보존한 것:"
say "  • 스킬 파일 — 완전 삭제하려면:"
say "      rm -rf $SKILLS_DIR/task-tracker $SKILLS_DIR/telegram-notify $SKILLS_DIR/trip-ledger"
say "      (telegram.conf 도 함께 삭제됨 — 토큰 백업 주의)"
say "  • ~/.herald/ 의 설정 — vault.conf · machine_id · 투입 SSH 키."
say "    이것들은 당신의 구성이라 제거기가 건드리지 않습니다."
