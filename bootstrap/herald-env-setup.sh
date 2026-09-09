#!/usr/bin/env bash
# herald-env-setup — 이 맥이 herald-ai 기준 환경과 무엇이 다른지 점검하고, 원하면 맞춘다.
#
# 무엇을 다루는가
#   herald-ai 자체(훅·스킬·vault 도구)는 install.sh 가 설치한다. 이 스크립트는 그 옆에서
#   같은 작업 환경을 이루는 **동반 구성요소**를 다룬다 — oh-my-claudecode(OMC) 플러그인과
#   OMC HUD(상태줄) 설정. 명세의 단일 출처는 config/environment.manifest.json 이다.
#
# 사용
#   bash bootstrap/herald-env-setup.sh                 # 점검만 (기본, 아무것도 바꾸지 않음)
#   bash bootstrap/herald-env-setup.sh --list-skills   # 이 맥에 로드된 스킬·에이전트 목록
#   bash bootstrap/herald-env-setup.sh --apply         # 필수 구성요소 + HUD 설정 적용
#   bash bootstrap/herald-env-setup.sh --apply --all   # 선택 플러그인까지 함께
#   bash bootstrap/herald-env-setup.sh --apply --with-settings   # 권장 전역 설정도 병합
#   bash bootstrap/herald-env-setup.sh --apply --no-hud          # HUD 설정은 건드리지 않음
#   bash bootstrap/herald-env-setup.sh --hud-only      # HUD 상태줄 설정만 기준값으로 (플러그인 미설치)
#
# 되돌리기
#   settings.json 은 변경 직전 settings.json.bak.<epoch> 로 백업된다.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_DIR/config/environment.manifest.json"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

MODE="check"; WANT_ALL=0; WANT_SETTINGS=0; WANT_HUD=1; ONLY_HUD=0
for arg in "$@"; do
    case "$arg" in
        --apply)         MODE="apply" ;;
        --check)         MODE="check" ;;
        --list-skills)   MODE="skills" ;;
        --hud-only)      MODE="apply"; ONLY_HUD=1 ;;
        --all)           WANT_ALL=1 ;;
        --with-settings) WANT_SETTINGS=1 ;;
        --no-hud)        WANT_HUD=0 ;;
        -h|--help)       sed -n '2,22p' "$0"; exit 0 ;;
        *) printf '❌ 모르는 인자: %s (--help)\n' "$arg" >&2; exit 2 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
miss() { printf '  ❌ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || { printf '❌ python3 필요\n' >&2; exit 1; }
[ -f "$MANIFEST" ] || { printf '❌ 명세 파일이 없습니다: %s\n' "$MANIFEST" >&2; exit 1; }

# --list-skills — 이 맥에 실제로 로드된 것을 센다(문서에 적힌 목록이 아니라 현재 상태) ---
if [ "$MODE" = "skills" ]; then
    # 여러 줄을 좁은 폭으로 접어 출력한다(스킬이 40개를 넘어 한 줄로는 안 읽힌다)
    listcol() { tr ' ' '\n' | sed '/^$/d' | sort | paste -sd' ' - | fold -s -w 92 | sed 's/^/    /'; }

    say "── 이 맥에 로드된 스킬 · 에이전트 ──────────────"
    say "  대상: $CLAUDE_DIR"
    say ""

    say "[herald-ai 스킬] — install.sh 가 설치 ($REPO_DIR/skills/)"
    for d in "$REPO_DIR/skills/"*/; do
        [ -d "$d" ] || continue
        _n="$(basename "$d")"
        if [ -d "$CLAUDE_DIR/skills/$_n" ]; then ok "$_n"; else miss "$_n — 미설치 (bash install.sh)"; fi
    done
    say "  ▸ 커맨드: $(ls "$REPO_DIR/commands" 2>/dev/null | sed 's/\.md$//' | paste -sd' ' -)"

    OMC_ROOT="$(find "$CLAUDE_DIR/plugins/cache/omc/oh-my-claudecode" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
    say ""
    if [ -n "$OMC_ROOT" ]; then
        say "[oh-my-claudecode 스킬] — 플러그인 제공 (v$(basename "$OMC_ROOT"))"
        find "$OMC_ROOT/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | listcol
        say "  에이전트:"
        find "$OMC_ROOT/agents" -maxdepth 1 -name '*.md' -exec basename {} .md \; 2>/dev/null | listcol
    else
        miss "oh-my-claudecode 미설치 — bash $0 --apply"
    fi

    if [ -d "$CLAUDE_DIR/skills/superpowers/skills" ]; then
        say ""
        say "[superpowers 스킬] — 선택"
        find "$CLAUDE_DIR/skills/superpowers/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | listcol
    fi

    say ""
    say "  설명·역할: docs/SKILLS.md · 설치 명세: config/environment.manifest.json"
    say "──────────────────────────────────────────────"
    exit 0
fi

HAS_CLAUDE=0
command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1

say "── herald-ai 동반 환경 점검 ────────────────────"
say "  명세: config/environment.manifest.json"
say "  대상: $CLAUDE_DIR"
say ""

# 1) 현재 상태를 명세와 대조한다 (읽기만) ---------------------
PLAN="$(MANIFEST="$MANIFEST" CLAUDE_DIR="$CLAUDE_DIR" python3 - <<'PY'
import json, os

man = json.load(open(os.environ['MANIFEST']))
cdir = os.environ['CLAUDE_DIR']

def load(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return default

markets  = load(os.path.join(cdir, 'plugins', 'known_marketplaces.json'), {})
installed = load(os.path.join(cdir, 'plugins', 'installed_plugins.json'), {}).get('plugins', {})
settings = load(os.path.join(cdir, 'settings.json'), {})
enabled  = settings.get('enabledPlugins', {})

rows = []
def row(*cols):
    rows.append('\t'.join(str(c).replace('\t', ' ') for c in cols))

for m in man.get('marketplaces', []):
    state = 'ok' if m['name'] in markets else 'missing'
    row('MARKETPLACE', m['name'], state, int(bool(m.get('required'))), m.get('add_command', ''))

for p in man.get('plugins', []):
    pid = p['id']
    # skills-dir 플러그인은 마켓플레이스가 아니라 ~/.claude/skills/<name>/ 에 놓인다
    skills_dir = os.path.join(cdir, 'skills', p['name'])
    if pid in installed:
        ver = installed[pid][0].get('version', '?')
        state = 'ok' if enabled.get(pid, True) else 'disabled'
    elif os.path.isdir(skills_dir):
        state, ver = 'ok-skillsdir', '-'
    else:
        state, ver = 'missing', '-'
    row('PLUGIN', pid, state, int(bool(p.get('required'))), p.get('install_command', ''),
        ver, p.get('version_at_capture', '-'), p.get('provides', ''))

hud = man.get('hud', {})
wrapper = os.path.join(cdir, 'hud', 'omc-hud.mjs')
frag = hud.get('settings_fragment', {})
same = all(settings.get(k) == v for k, v in frag.items())
row('HUD', 'wrapper', 'ok' if os.path.isfile(wrapper) else 'missing')
row('HUD', 'settings', 'ok' if same else 'differs')

rec = man.get('claude_settings_recommended', {}).get('fragment', {})
row('SETTINGS', 'recommended',
    'ok' if all(settings.get(k) == v for k, v in rec.items()) else 'differs')

print('\n'.join(rows))
PY
)"

MISSING_REQUIRED=0
say "[마켓플레이스]"
while IFS=$'\t' read -r kind name state required cmd rest; do
    [ "$kind" = "MARKETPLACE" ] || continue
    if [ "$state" = "ok" ]; then ok "$name"
    elif [ "$required" = "1" ]; then miss "$name — 미등록 (필수)"; MISSING_REQUIRED=1
    else warn "$name — 미등록 (선택)"; fi
done <<< "$PLAN"

say ""
say "[플러그인]"
while IFS=$'\t' read -r kind pid state required cmd ver capver provides; do
    [ "$kind" = "PLUGIN" ] || continue
    case "$state" in
        ok)           ok "$pid  $ver  (기준 $capver)" ;;
        ok-skillsdir) ok "$pid  (skills-dir 로 로드됨)" ;;
        disabled)     warn "$pid — 설치됐으나 비활성. claude plugin enable $pid" ;;
        missing)
            if [ "$required" = "1" ]; then miss "$pid — 미설치 (필수) · $provides"; MISSING_REQUIRED=1
            else warn "$pid — 미설치 (선택) · $provides"; fi ;;
    esac
done <<< "$PLAN"

say ""
say "[HUD · 전역 설정]"
while IFS=$'\t' read -r kind name state rest; do
    case "$kind:$name:$state" in
        HUD:wrapper:ok)        ok  "HUD 래퍼 (hud/omc-hud.mjs)" ;;
        HUD:wrapper:missing)   miss "HUD 래퍼 없음 — Claude Code 에서 /oh-my-claudecode:hud setup 1회 실행" ;;
        HUD:settings:ok)       ok  "HUD 설정 (statusLine · omcHud) 기준과 동일" ;;
        HUD:settings:differs)  warn "HUD 설정이 기준과 다름 — --apply 로 맞춤" ;;
        SETTINGS:recommended:ok)      ok  "권장 전역 설정 반영됨" ;;
        SETTINGS:recommended:differs) warn "권장 전역 설정 미반영 (선택) — --apply --with-settings" ;;
    esac
done <<< "$PLAN"

if [ "$MODE" = "check" ]; then
    say ""
    if [ "$MISSING_REQUIRED" = "1" ]; then
        say "필수 구성요소가 빠져 있습니다. 맞추려면:"
        say "  bash $REPO_DIR/bootstrap/herald-env-setup.sh --apply"
        say "──────────────────────────────────────────────"
        exit 1
    fi
    say "기준 환경과 일치합니다 (선택 항목 제외)."
    say "──────────────────────────────────────────────"
    exit 0
fi

# 2) 적용 ------------------------------------------------------
say ""
say "── 적용 ────────────────────────────────────────"

if [ "$ONLY_HUD" = "1" ]; then
    ok "--hud-only — 플러그인은 건드리지 않고 HUD 설정만 기준값으로 맞춥니다."
elif [ "$HAS_CLAUDE" = "0" ]; then
    warn "claude CLI 가 PATH 에 없어 플러그인 설치를 건너뜁니다 (HUD 설정만 진행)."
else
    while IFS=$'\t' read -r kind name state required cmd rest; do
        [ "$kind" = "MARKETPLACE" ] || continue
        [ "$state" = "missing" ] || continue
        [ "$required" = "1" ] || [ "$WANT_ALL" = "1" ] || continue
        say "  ▸ $cmd"
        eval "$cmd" || warn "마켓플레이스 등록 실패: $name"
    done <<< "$PLAN"

    while IFS=$'\t' read -r kind pid state required cmd ver capver provides; do
        [ "$kind" = "PLUGIN" ] || continue
        [ "$state" = "missing" ] || continue
        [ "$required" = "1" ] || [ "$WANT_ALL" = "1" ] || continue
        say "  ▸ $cmd"
        eval "$cmd" || warn "플러그인 설치 실패: $pid"
    done <<< "$PLAN"
fi

if [ "$WANT_HUD" = "1" ] || [ "$WANT_SETTINGS" = "1" ]; then
    [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%s 2>/dev/null || echo bak)" \
        && ok "settings.json 백업"
    MANIFEST="$MANIFEST" SETTINGS="$SETTINGS" WANT_HUD="$WANT_HUD" WANT_SETTINGS="$WANT_SETTINGS" \
    python3 - <<'PY'
import json, os

man = json.load(open(os.environ['MANIFEST']))
path = os.environ['SETTINGS']
os.makedirs(os.path.dirname(path), exist_ok=True)
try:
    cfg = json.load(open(path))
except (FileNotFoundError, ValueError):
    cfg = {}

applied = []
if os.environ['WANT_HUD'] == '1':
    for k, v in man.get('hud', {}).get('settings_fragment', {}).items():
        cfg[k] = v
        applied.append(k)
if os.environ['WANT_SETTINGS'] == '1':
    for k, v in man.get('claude_settings_recommended', {}).get('fragment', {}).items():
        if isinstance(v, dict) and isinstance(cfg.get(k), dict):
            cfg[k].update(v)          # env 처럼 사전이면 병합 — 기존 항목을 지우지 않는다
        else:
            cfg[k] = v
        applied.append(k)

json.dump(cfg, open(path, 'w'), ensure_ascii=False, indent=2)
print('  ✅ settings.json 병합: ' + ', '.join(applied))
PY
fi

say ""
say "다음 단계:"
if [ "$HAS_CLAUDE" = "1" ]; then
    say "  • Claude Code 를 재시작합니다 (플러그인·상태줄은 새 세션부터 적용)."
    say "  • HUD 래퍼가 없다면 새 세션에서 /oh-my-claudecode:hud setup 을 1회 실행합니다."
else
    say "  • claude CLI 를 설치한 뒤 이 스크립트를 --apply 로 다시 실행합니다."
fi
say "  • (선택) 상태줄 cwd 색이 어둡다면:"
say "       bash $REPO_DIR/bootstrap/omc-hud-cwd-color-patch.sh"
say "  • 점검:  bash $REPO_DIR/bootstrap/herald-env-setup.sh"
say "──────────────────────────────────────────────"
