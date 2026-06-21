#!/usr/bin/env bash
# herald-ai uninstaller — settings.json 의 herald 훅 제거 + (선택) 스킬 삭제
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"

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

# /session-log 커맨드 제거
if [ -f "$COMMANDS_DIR/session-log.md" ]; then
    rm -f "$COMMANDS_DIR/session-log.md"
    say "  ✅ /session-log 커맨드 제거"
fi

say ""
say "스킬 파일은 보존했습니다. 완전 삭제하려면:"
say "  rm -rf $SKILLS_DIR/task-tracker $SKILLS_DIR/telegram-notify"
say "  (telegram.conf 도 함께 삭제됨 — 토큰 백업 주의)"
