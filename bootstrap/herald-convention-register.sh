#!/usr/bin/env bash
# herald-convention-register — 커밋 규약 v3.1.0 의 **호출어**를 이 맥의 글로벌 지침에 등록한다.
#
# 왜 필요한가
#   docs/COMMIT-CONVENTION.md 는 clone 한 저장소 안에만 있다. 다른 디렉토리에서 세션을 열면
#   그 문서가 있는 줄 모른다. 글로벌 ~/.claude/CLAUDE.md 는 **모든 세션이 자동으로 읽으므로**,
#   거기에 "이 말이 나오면 저 파일을 보라" 는 한 블록만 넣어 두면 어디서든 호출된다.
#   정본은 여전히 저장소 문서 하나다 — 여기 들어가는 것은 포인터와 핵심 규칙 요약뿐이다.
#
# 사용
#   bash bootstrap/herald-convention-register.sh            # 등록 (멱등)
#   bash bootstrap/herald-convention-register.sh --check    # 등록 여부만 확인
#   bash bootstrap/herald-convention-register.sh --force    # 수기 작성분이 있어도 관리 블록 추가
#   bash bootstrap/herald-convention-register.sh --revert   # 블록 제거
#
# 안전
#   변경 전 CLAUDE.md 를 CLAUDE.md.bak.<epoch> 로 백업한다.
#   마커 밖에 이미 손으로 적어 둔 호출어가 있으면 **건드리지 않고 알리기만** 한다(중복 방지).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GLOBAL="$CLAUDE_DIR/CLAUDE.md"
DOC="$REPO_DIR/docs/COMMIT-CONVENTION.md"
BEGIN='<!-- herald-ai:convention BEGIN -->'
END='<!-- herald-ai:convention END -->'

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }

[ -f "$DOC" ] || { printf '❌ 정본 문서가 없습니다: %s\n' "$DOC" >&2; exit 1; }

has_markers() { [ -f "$GLOBAL" ] && grep -qF "$BEGIN" "$GLOBAL"; }
has_phrase()  { [ -f "$GLOBAL" ] && grep -q 'v3.1 커밋 체계' "$GLOBAL"; }

case "${1:-}" in
    --check)
        if has_markers;      then ok  "호출어 등록됨 (herald-ai 관리 블록) — $GLOBAL"; exit 0
        elif has_phrase;     then ok  "호출어 등록됨 (수기 작성) — $GLOBAL"; exit 0
        else warn "호출어 미등록 — bash $0"; exit 1; fi ;;
    --revert)
        has_markers || { warn "관리 블록이 없습니다 (수기 작성분은 건드리지 않습니다)"; exit 0; }
        cp "$GLOBAL" "$GLOBAL.bak.$(date +%s)"
        BEGIN="$BEGIN" END="$END" GLOBAL="$GLOBAL" python3 - <<'PY'
import os, re
p = os.environ['GLOBAL']
s = open(p, encoding='utf-8').read()
s = re.sub(re.escape(os.environ['BEGIN']) + r'.*?' + re.escape(os.environ['END']) + r'\n*',
           '', s, flags=re.S)
open(p, 'w', encoding='utf-8').write(s)
PY
        ok "관리 블록 제거 — $GLOBAL"; exit 0 ;;
    ''|--register|--force) ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf '❌ 모르는 인자: %s (--help)\n' "$1" >&2; exit 2 ;;
esac

if has_markers; then
    :   # 아래에서 블록 내용을 최신으로 갈아끼운다(경로가 바뀌었을 수 있다)
elif [ "${1:-}" = "--force" ]; then
    warn "--force — 수기 작성분이 있어도 관리 블록을 추가합니다. 중복 문단이 없는지 확인하십시오."
elif has_phrase; then
    warn "이미 손으로 등록돼 있습니다 — 중복을 만들지 않기 위해 건드리지 않습니다."
    say  "     자동 관리로 바꾸려면 해당 문단을 지운 뒤 이 스크립트를 다시 실행하십시오."
    say  "     대상: $GLOBAL"
    exit 0
fi

mkdir -p "$CLAUDE_DIR"
[ -f "$GLOBAL" ] && cp "$GLOBAL" "$GLOBAL.bak.$(date +%s)" && ok "백업: $(basename "$GLOBAL").bak.<epoch>"

BEGIN="$BEGIN" END="$END" GLOBAL="$GLOBAL" DOC="$DOC" python3 - <<'PY'
import os, re

path, begin, end, doc = (os.environ[k] for k in ('GLOBAL', 'BEGIN', 'END', 'DOC'))
block = f"""{begin}
## 커밋 규약 호출어 — 「v3.1 커밋 체계」

> 이 블록은 herald-ai 의 `bootstrap/herald-convention-register.sh` 가 관리합니다. 손으로 고치지 마십시오.

- 사용자가 **"v3.1 커밋 체계"** 라고 하면 규약 **v3.1.0** 을 적용한다.
  **정본**: `{doc}`
- 핵심: **`patch = 묶음 × 10 + 커밋(1자리)`** — `1.5.247` = 묶음 24 · 커밋 7.
  **맨 뒤 한 자리가 커밋, 그 앞이 전부 묶음.** 묶음 상한 없음. 커밋 9 도달 시 다음 묶음 `x0` 강제.
  minor 상승 시 patch 는 `10` 부터 (`x.y.0~x.y.9` 는 미정의 구간). 소급 재번호 금지.
- 호출되면 정본의 「호출됐을 때 할 일」 7단계를 따른다: 현재 버전 확인 → 다음 번호 계산 →
  granularity 점검 → CHANGELOG·DEVLOG·버전 파일 갱신 → 검증 → HEREDOC 커밋 → push 는 별도 요청 시.
- **새 저장소에 규약을 도입**할 때는 정본의 「새 저장소에 도입하기」 절을 따른다
  (스캐폴딩: `bash <herald-ai>/bootstrap/herald-convention-init.sh <대상 저장소>`).
- 정본 파일이 없으면(그 맥에 herald-ai clone 이 없음) **추측하지 말고 사용자에게 알린다.**
{end}"""

try:
    s = open(path, encoding='utf-8').read()
except FileNotFoundError:
    s = "# 사용자 글로벌 지침\n"

if begin in s:
    s = re.sub(re.escape(begin) + r'.*?' + re.escape(end), block, s, flags=re.S)
    action = '갱신'
else:
    s = s.rstrip('\n') + '\n\n---\n\n' + block + '\n'
    action = '추가'

open(path, 'w', encoding='utf-8').write(s)
print(f"  ✅ 호출어 블록 {action} — {path}")
PY

say ""
say "다음 세션부터 어느 디렉토리에서든 \"v3.1 커밋 체계\" 로 호출됩니다."
say "  정본: $DOC"
