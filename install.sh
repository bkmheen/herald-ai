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
HERALD_BIN="$HOME/.herald/bin"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }
err()  { printf '  ❌ %s\n' "$*" >&2; }

say "── herald-ai 설치 ──────────────────────────────"

# 1) 의존성 점검 ------------------------------------------------
say "[1/7] 의존성 점검"
command -v bash    >/dev/null 2>&1 && ok "bash"    || { err "bash 필요"; exit 1; }
command -v python3 >/dev/null 2>&1 && ok "python3" || { err "python3 필요 (텔레그램 전송·설정 병합)"; exit 1; }
command -v curl    >/dev/null 2>&1 && ok "curl"    || warn "curl 없음 — 텔레그램 전송 불가(python3 폴백 사용)"
command -v bc      >/dev/null 2>&1 && ok "bc"      || warn "bc 없음 — 소요시간 계산 제한 (apt install bc / brew install bc)"
command -v jq      >/dev/null 2>&1 && ok "jq"      || warn "jq 없음(선택) — node 폴백 사용"
if command -v node >/dev/null 2>&1; then ok "node ($(node -v 2>/dev/null))"
else warn "node 없음 — ccusage 토큰/비용 추적 비활성 (Node.js 설치 권장)"; fi

# 2) 스킬 복사 -------------------------------------------------
say "[2/7] 스킬 설치 → $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
# 런타임/개인 파일(telegram.conf·task_history.jsonl·config)은 보존한다.
# rsync 없이 coreutils(cp) 만으로 rsync --exclude 와 동등하게: 복사 전 개인 파일을
# 백업 → 트리 복사 → 백업 복원. 원래 없던 파일(=repo 샘플)은 지워 fresh install 오염 방지.
mkdir -p "$TT_DIR"
for _f in telegram.conf task_history.jsonl config; do
    [ -f "$TT_DIR/$_f" ] && cp "$TT_DIR/$_f" "$TT_DIR/.$_f.keep"
done
cp -R "$REPO_DIR/skills/task-tracker/." "$TT_DIR/"
for _f in telegram.conf task_history.jsonl config; do
    if [ -f "$TT_DIR/.$_f.keep" ]; then mv -f "$TT_DIR/.$_f.keep" "$TT_DIR/$_f"   # 기존 개인 파일 복원
    else rm -f "$TT_DIR/$_f"; fi                                                   # 원래 없던 repo 샘플 제거(rsync --exclude 동등)
done
mkdir -p "$SKILLS_DIR/telegram-notify"
cp -R "$REPO_DIR/skills/telegram-notify/." "$SKILLS_DIR/telegram-notify/"
# trip-ledger — 여행·출장 지출 원장 파이프라인(문서 전용, 런타임 상태 없음).
# 개인 식별자(시트 ID·맵 목록)는 볼트 Registry 에 있고 여기엔 없으므로 통째로 덮어써도 안전.
mkdir -p "$SKILLS_DIR/trip-ledger"
cp -R "$REPO_DIR/skills/trip-ledger/." "$SKILLS_DIR/trip-ledger/"
# CRLF 방어: Windows 에서 clone/ZIP 다운로드하면 셸 스크립트가 CRLF 로 섞여
# 런타임 훅이 깨진다("invalid option name" 등). 설치되는 .sh 의 \r 을 제거한다.
# perl 은 macOS·Linux 기본 탑재(BSD/GNU sed -i 비호환 회피). 없으면 조용히 건너뜀.
if command -v perl >/dev/null 2>&1; then
    find "$TT_DIR" "$SKILLS_DIR/telegram-notify" -type f -name '*.sh' \
        -exec perl -i -pe 's/\r$//' {} + 2>/dev/null || true
fi
chmod +x "$TT_DIR/scripts/"*.sh
ok "task-tracker, telegram-notify, trip-ledger 스킬 복사 완료"

# 플랜 설정(config) — 없을 때만 example 에서 생성
if [ ! -f "$TT_DIR/config" ] && [ -f "$REPO_DIR/skills/task-tracker/config.example" ]; then
    cp "$REPO_DIR/skills/task-tracker/config.example" "$TT_DIR/config"
    ok "플랜 설정 생성 (config) — 필요시 task-tracker.sh setup 으로 변경"
fi

# 2.5) 슬래시 커맨드 복사 -------------------------------------
say "[3/7] 슬래시 커맨드 설치 → $COMMANDS_DIR"
if [ -d "$REPO_DIR/commands" ]; then
    mkdir -p "$COMMANDS_DIR"
    cp -R "$REPO_DIR/commands/." "$COMMANDS_DIR/"
    ok "/session-log · /session-save 커맨드 복사 완료"
else
    warn "commands 디렉토리 없음 — 커맨드 건너뜀"
fi

# 2.7) vault 도구 설치 ----------------------------------------
# herald-vault 파이프라인 도구. 데이터가 아니라 실행 파일이므로 ~/.herald/bin 에 둔다
# (~/.herald 자체는 herald-init.sh 가 만들지만, 여기서도 없으면 만든다 — 멱등).
say "[4/7] vault 도구 설치 → $HERALD_BIN"
if [ -d "$REPO_DIR/bin" ]; then
    mkdir -p "$HERALD_BIN"
    for _t in "$REPO_DIR/bin/"*; do
        [ -f "$_t" ] || continue
        install -m 755 "$_t" "$HERALD_BIN/$(basename "$_t")"
    done
    ok "$(ls -1 "$REPO_DIR/bin" | tr '\n' ' ')설치 완료"
    case ":$PATH:" in
        *":$HERALD_BIN:"*) ok "PATH 에 이미 있음" ;;
        *) warn "PATH 에 없습니다. 셸 설정에 다음을 넣으십시오:"
           say  "       export PATH=\"\$HOME/.herald/bin:\$PATH\"" ;;
    esac
else
    warn "bin 디렉토리 없음 — vault 도구 건너뜀"
fi

# 3) 텔레그램 자격증명 -----------------------------------------
say "[5/7] 텔레그램 설정"
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
say "[6/7] Claude Code 훅 병합 → $SETTINGS"
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
say "[7/7] 완료"
say ""
say "다음 단계:"
say "  1) telegram.conf 에 봇 토큰/CHAT_ID 입력 (아직이면)"
say "       \$EDITOR $CONF"
say "  2) (선택) 플랜 설정:  bash $TT_DIR/scripts/task-tracker.sh setup"
say "  3) Claude Code 새 세션을 시작하면 훅이 활성화됩니다."
say ""
say "추가 기능:"
say "  • /session-log  — 이번 세션 작업 차례를 화면에 표시 (필터 인자 지원, 파일 미생성)"
say "  • /session-save — 세션 작업기록 MD 저장 (herald-vault 로 모임; /session-log 필터 인계)"
say ""
say "vault 도구 ($HERALD_BIN):"
say "  • herald-find \"검색어\"   — vault 전문 검색 (clone 있으면 ripgrep, 없으면 Forgejo API)"
say "  • herald-index          — sessions/INDEX.md · index.json 재생성 (멱등)"
say "  • herald-sort           — _inbox 회수분을 제자리로 (관리 호스트)"
say "  • herald-legacy-import  — 흩어진 옛 기록을 sessions/_legacy 로 (기본 모의 실행)"
say "  • herald-send / herald-env — 투입·환경 스냅샷 (일반 호스트)"
say ""
say "전송 테스트(실제 미전송):"
say "  NOTIFY_DRY_RUN=1 bash $TT_DIR/scripts/notify.sh done"
say "──────────────────────────────────────────────"
