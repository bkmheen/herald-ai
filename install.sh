#!/usr/bin/env bash
# herald-ai installer — Claude Code 작업 알림(텔레그램+데스크톱) + 토큰비용 추적 훅
# macOS / Linux 공용. 멱등(여러 번 실행해도 안전).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SETTINGS="$CLAUDE_DIR/settings.json"
TT_DIR="$SKILLS_DIR/task-tracker"
CONF="$TT_DIR/telegram.conf"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }
err()  { printf '  ❌ %s\n' "$*" >&2; }

say "── herald-ai 설치 ──────────────────────────────"

# 1) 의존성 점검 ------------------------------------------------
say "[1/6] 의존성 점검"
command -v bash    >/dev/null 2>&1 && ok "bash"    || { err "bash 필요"; exit 1; }
command -v python3 >/dev/null 2>&1 && ok "python3" || { err "python3 필요 (텔레그램 전송·설정 병합)"; exit 1; }
command -v curl    >/dev/null 2>&1 && ok "curl"    || warn "curl 없음 — 텔레그램 전송 불가(python3 폴백 사용)"
command -v bc      >/dev/null 2>&1 && ok "bc"      || warn "bc 없음 — 소요시간 계산 제한 (apt install bc / brew install bc)"
command -v jq      >/dev/null 2>&1 && ok "jq"      || warn "jq 없음(선택) — node 폴백 사용"
if command -v node >/dev/null 2>&1; then ok "node ($(node -v 2>/dev/null))"
else warn "node 없음 — ccusage 토큰/비용 추적 비활성 (Node.js 설치 권장)"; fi

# 2) 스킬 복사 -------------------------------------------------
say "[2/6] 스킬 설치 → $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
# 런타임/개인 파일은 덮어쓰지 않도록 제외하고 복사
rsync -a --exclude 'telegram.conf' --exclude 'task_history.jsonl' --exclude 'config' \
      "$REPO_DIR/skills/task-tracker"   "$SKILLS_DIR/"
rsync -a "$REPO_DIR/skills/telegram-notify" "$SKILLS_DIR/"
chmod +x "$TT_DIR/scripts/"*.sh
ok "task-tracker, telegram-notify 스킬 복사 완료"

# 플랜 설정(config) — 없을 때만 example 에서 생성
if [ ! -f "$TT_DIR/config" ] && [ -f "$REPO_DIR/skills/task-tracker/config.example" ]; then
    cp "$REPO_DIR/skills/task-tracker/config.example" "$TT_DIR/config"
    ok "플랜 설정 생성 (config) — 필요시 task-tracker.sh setup 으로 변경"
fi

# 2.5) 슬래시 커맨드 복사 -------------------------------------
say "[3/6] 슬래시 커맨드 설치 → $COMMANDS_DIR"
if [ -d "$REPO_DIR/commands" ]; then
    mkdir -p "$COMMANDS_DIR"
    rsync -a "$REPO_DIR/commands/" "$COMMANDS_DIR/"
    ok "/session-log 커맨드 복사 완료"
else
    warn "commands 디렉토리 없음 — 커맨드 건너뜀"
fi

# 3) 텔레그램 자격증명 -----------------------------------------
say "[4/6] 텔레그램 설정"
if [ -f "$CONF" ]; then
    ok "telegram.conf 이미 존재 — 유지"
else
    cp "$REPO_DIR/config/telegram.conf.example" "$CONF"
    chmod 600 "$CONF"
    warn "telegram.conf 생성됨 — 토큰/CHAT_ID 를 채워주세요:"
    say  "       $CONF"
    say  "       (미설정 시 데스크톱 알림만 동작, 텔레그램은 건너뜀)"
fi

# 4) 훅 병합 (settings.json) -----------------------------------
say "[5/6] Claude Code 훅 병합 → $SETTINGS"
mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%s 2>/dev/null || echo bak)" && ok "기존 settings.json 백업"
FRAG="$REPO_DIR/hooks/settings.hooks.json" SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os
settings_path = os.environ['SETTINGS']
frag = json.load(open(os.environ['FRAG']))
try:
    cfg = json.load(open(settings_path))
except (FileNotFoundError, ValueError):
    cfg = {}
hooks = cfg.setdefault('hooks', {})
MARK = 'task-tracker/scripts'   # 우리 훅 식별자
for event, entries in frag.items():
    cur = hooks.get(event, [])
    # 기존 herald/task-tracker 훅 제거(멱등) 후 우리 엔트리 추가
    kept = [e for e in cur if MARK not in json.dumps(e)]
    hooks[event] = kept + entries
json.dump(cfg, open(settings_path, 'w'), ensure_ascii=False, indent=2)
print("  ✅ 훅 병합: " + ", ".join(frag.keys()))
PY

# 5) 완료 안내 -------------------------------------------------
say "[6/6] 완료"
say ""
say "다음 단계:"
say "  1) telegram.conf 에 봇 토큰/CHAT_ID 입력 (아직이면)"
say "       \$EDITOR $CONF"
say "  2) (선택) 플랜 설정:  bash $TT_DIR/scripts/task-tracker.sh setup"
say "  3) Claude Code 새 세션을 시작하면 훅이 활성화됩니다."
say ""
say "추가 기능:"
say "  • /session-log — 이번 세션 작업기록 MD 생성 (기본 ~/Desktop, HERALD_LOG_DIR 로 변경)"
say ""
say "전송 테스트(실제 미전송):"
say "  NOTIFY_DRY_RUN=1 bash $TT_DIR/scripts/notify.sh done"
say "──────────────────────────────────────────────"
