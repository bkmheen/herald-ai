#!/usr/bin/env bash
# herald-onboard — 새 맥의 **단일 진입점**. 전체 순서를 처음부터 끝까지 점검하고,
#                  안 되어 있는 것은 무엇을 어떻게 하면 되는지 절대경로 명령으로 안내한다.
#
# 목적
#   저장소 하나만 알면 나머지는 이 스크립트가 안내한다. 무엇을 어떤 순서로 깔아야 하는지
#   외우고 있을 필요가 없다. 점검 결과에 안 된 항목이 하나라도 있으면 exit 1 이다.
#
# 사용
#   bash bootstrap/herald-onboard.sh            # 전체 점검 (기본 — 아무것도 바꾸지 않는다)
#   bash bootstrap/herald-onboard.sh --apply    # 자동으로 되는 것은 실행하고, 나머지는 안내
#
# 자동으로 되는 것 / 안 되는 것
#   되는 것   herald-ai 본체 설치 · OMC 플러그인 · HUD 설정 · 커밋 규약 호출어 등록
#   안 되는 것 시스템 패키지(brew/apt) · Claude Code 설치 · 텔레그램 토큰 입력
#             → 사용자 승인·자격증명이 필요한 일은 대신 하지 않고 명령만 보여 준다
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TT_DIR="$CLAUDE_DIR/skills/task-tracker"
CONF="$TT_DIR/telegram.conf"
HERALD_BIN="$HOME/.herald/bin"

APPLY=0
case "${1:-}" in
    --apply)   APPLY=1 ;;
    ''|--check) ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) printf '❌ 모르는 인자: %s (--help)\n' "$1" >&2; exit 2 ;;
esac

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
miss() { printf '  ❌ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }
cmd()  { printf '       %s\n' "$*"; }

TODO=()
todo() { TODO+=("$1"); }

case "$(uname -s)" in
    Darwin) PKG="brew install bc jq node git" ;;
    *)      PKG="sudo apt update && sudo apt install -y python3 curl bc jq nodejs npm git" ;;
esac

say "══ herald-ai 온보딩 점검 ══════════════════════"
say "  저장소: $REPO_DIR"
say "  설정  : $CLAUDE_DIR"
[ "$APPLY" = "1" ] && say "  모드  : 적용 — 자동으로 되는 것은 실행합니다" \
                   || say "  모드  : 점검만 — 아무것도 바꾸지 않습니다 (--apply 로 실행)"
say ""

# ── [1/6] 시스템 의존성 ────────────────────────────────────────
say "[1/6] 시스템 의존성"
NEED_PKG=0
for t in bash python3 git; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t"
    else miss "$t — 필수"; NEED_PKG=1; fi
done
if command -v node >/dev/null 2>&1; then ok "node ($(node -v 2>/dev/null))"
else miss "node — HUD 상태줄과 비용 추적에 필요"; NEED_PKG=1; fi
for t in curl bc jq; do
    command -v "$t" >/dev/null 2>&1 && ok "$t" || { warn "$t 없음 (권장 — 폴백 있음)"; NEED_PKG=1; }
done
if [ "$NEED_PKG" = "1" ]; then
    cmd "$PKG"
    todo "시스템 패키지 설치:  $PKG"
fi

# ── [2/6] Claude Code ─────────────────────────────────────────
say ""
say "[2/6] Claude Code"
HAS_CLAUDE=0
if command -v claude >/dev/null 2>&1; then
    HAS_CLAUDE=1; ok "claude ($(claude --version 2>/dev/null | head -1))"
else
    miss "claude 없음 — 플러그인 설치·HUD 가 모두 이것을 전제한다"
    cmd "npm install -g @anthropic-ai/claude-code     # 또는 https://claude.ai/download"
    todo "Claude Code 설치:  npm install -g @anthropic-ai/claude-code"
fi

# ── [3/6] herald-ai 본체 ──────────────────────────────────────
say ""
say "[3/6] herald-ai 본체 (알림 훅 · 스킬 · vault 도구)"
installed_core() {
    [ -f "$TT_DIR/scripts/notify.sh" ] && \
    [ -f "$SETTINGS" ] && grep -q 'task-tracker/scripts' "$SETTINGS" 2>/dev/null
}
if installed_core; then
    ok "스킬·훅 설치됨 (task-tracker · telegram-notify · trip-ledger)"
elif [ "$APPLY" = "1" ]; then
    say "  ▸ bash $REPO_DIR/install.sh"
    bash "$REPO_DIR/install.sh" >/dev/null && ok "install.sh 완료" || { miss "install.sh 실패"; todo "install.sh 재실행"; }
else
    miss "미설치"
    cmd "bash $REPO_DIR/install.sh"
    todo "herald-ai 본체 설치:  bash $REPO_DIR/install.sh"
fi
if [ -d "$HERALD_BIN" ]; then
    case ":$PATH:" in
        *":$HERALD_BIN:"*) ok "PATH 에 ~/.herald/bin 포함" ;;
        *) warn "PATH 에 ~/.herald/bin 없음 — vault 도구를 이름으로 못 부른다"
           cmd 'echo '"'"'export PATH="$HOME/.herald/bin:$PATH"'"'"' >> ~/.zshrc'
           todo 'PATH 추가:  echo '"'"'export PATH="$HOME/.herald/bin:$PATH"'"'"' >> ~/.zshrc' ;;
    esac
fi

# ── [4/6] 텔레그램 자격증명 ───────────────────────────────────
say ""
say "[4/6] 텔레그램 알림 설정"
if [ ! -f "$CONF" ]; then
    warn "telegram.conf 없음 — install.sh 를 먼저 돌리면 생성된다 (데스크톱 알림만 동작)"
    todo "텔레그램 설정:  \$EDITOR $CONF"
elif grep -q '<your-telegram' "$CONF" 2>/dev/null; then
    miss "telegram.conf 의 TOKEN·CHAT_ID 가 아직 예시값이다 (텔레그램 전송 안 됨)"
    cmd "\$EDITOR $CONF        # @BotFather 에서 토큰, @userinfobot 에서 CHAT_ID"
    todo "텔레그램 토큰·CHAT_ID 입력:  \$EDITOR $CONF"
else
    ok "telegram.conf 입력됨"
fi

# ── [5/6] 동반 환경 (OMC · HUD) ───────────────────────────────
say ""
say "[5/6] 동반 환경 — oh-my-claudecode · HUD 상태줄"
if [ "$APPLY" = "1" ]; then
    # claude 가 없어도 호출한다 — env-setup 이 플러그인 단계만 건너뛰고 HUD 설정은 병합한다
    bash "$REPO_DIR/bootstrap/herald-env-setup.sh" --apply | sed -n '/── 적용/,$p' | sed 's/^/  /'
    [ "$HAS_CLAUDE" = "1" ] || todo "claude 설치 후 재실행:  bash $REPO_DIR/bootstrap/herald-onboard.sh --apply"
elif bash "$REPO_DIR/bootstrap/herald-env-setup.sh" >/dev/null 2>&1; then
    ok "기준 환경과 일치 (플러그인 · HUD 설정)"
else
    miss "기준과 다름 — 자세한 차이는 아래 명령으로 확인"
    cmd "bash $REPO_DIR/bootstrap/herald-env-setup.sh"
    cmd "bash $REPO_DIR/bootstrap/herald-env-setup.sh --apply"
    todo "동반 환경 적용:  bash $REPO_DIR/bootstrap/herald-env-setup.sh --apply"
fi
if [ ! -f "$CLAUDE_DIR/hud/omc-hud.mjs" ]; then
    warn "HUD 래퍼 없음 — Claude Code 새 세션에서 한 번 실행: /oh-my-claudecode:hud setup"
    todo "HUD 래퍼 생성:  Claude Code 새 세션에서 /oh-my-claudecode:hud setup"
fi

# ── [6/6] 커밋 규약 호출어 ────────────────────────────────────
say ""
say "[6/6] 커밋 규약 — 호출어 「v3.1 커밋 체계」"
if bash "$REPO_DIR/bootstrap/herald-convention-register.sh" --check 2>/dev/null | grep -q '✅'; then
    bash "$REPO_DIR/bootstrap/herald-convention-register.sh" --check
elif [ "$APPLY" = "1" ]; then
    bash "$REPO_DIR/bootstrap/herald-convention-register.sh" | sed 's/^/  /'
else
    miss "미등록 — 다른 디렉토리에서는 규약이 호출되지 않는다"
    cmd "bash $REPO_DIR/bootstrap/herald-convention-register.sh"
    todo "호출어 등록:  bash $REPO_DIR/bootstrap/herald-convention-register.sh"
fi

# ── 마무리 ────────────────────────────────────────────────────
say ""
say "══════════════════════════════════════════════"
if [ ${#TODO[@]} -eq 0 ]; then
    say "✅ 전 항목 완료입니다."
    say ""
    say "  • Claude Code 를 재시작하면 훅·플러그인·상태줄이 적용됩니다."
    say "  • 스킬 목록:  bash $REPO_DIR/bootstrap/herald-env-setup.sh --list-skills"
    say "  • 새 저장소에 커밋 규약 도입:"
    say "      bash $REPO_DIR/bootstrap/herald-convention-init.sh <대상 저장소>"
    say "══════════════════════════════════════════════"
    exit 0
fi
say "남은 할 일 ${#TODO[@]}건 — 위에서 아래로 처리하십시오:"
_i=1
for t in "${TODO[@]}"; do printf '  %d) %s\n' "$_i" "$t"; _i=$((_i+1)); done
say ""
if [ "$APPLY" = "0" ]; then
    say "자동으로 되는 것부터 처리하려면:"
    say "  bash $REPO_DIR/bootstrap/herald-onboard.sh --apply"
else
    say "위 항목은 사용자 승인·자격증명이 필요해 자동으로 처리하지 않았습니다."
fi
say "처리 후 다시 점검:  bash $REPO_DIR/bootstrap/herald-onboard.sh"
say "══════════════════════════════════════════════"
exit 1
