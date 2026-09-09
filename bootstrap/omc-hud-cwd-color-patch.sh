#!/usr/bin/env bash
# OMC HUD cwd 색상 패치 — dim → brightCyan
#
# 왜 있는가
#   HUD 상태줄의 현재 디렉토리가 기본값 dim 이라 어두운 터미널에서 거의 읽히지 않는다.
#   설정 항목으로는 색을 못 바꾸므로 플러그인 캐시의 렌더러를 직접 고친다.
#
# 주의
#   플러그인 캐시 파일을 고치는 패치다. **OMC 를 업데이트하면 새 버전 디렉토리로 갈아타므로
#   다시 실행해야 한다.** 원본은 `.bak` 으로 남긴다.
#
# 사용
#   bash bootstrap/omc-hud-cwd-color-patch.sh            # 최신 버전에 적용
#   bash bootstrap/omc-hud-cwd-color-patch.sh --revert   # .bak 으로 되돌림
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE="$CLAUDE_DIR/plugins/cache/omc/oh-my-claudecode"

[ -d "$CACHE" ] || { printf '❌ OMC 플러그인이 없습니다: %s\n' "$CACHE" >&2; exit 1; }

# 버전 디렉토리를 숫자 정렬로 고른다 (10.x 가 9.x 보다 뒤에 오도록)
# 경로는 <캐시>/<버전>/dist/hud/elements/cwd.js — 캐시 기준 5단계다.
TARGET="$(find "$CACHE" -maxdepth 5 -path '*/dist/hud/elements/cwd.js' -type f 2>/dev/null \
          | sort -V | tail -1)"
[ -n "$TARGET" ] || { printf '❌ 대상 파일을 찾지 못했습니다 (dist/hud/elements/cwd.js)\n' >&2; exit 1; }

if [ "${1:-}" = "--revert" ]; then
    if [ -f "$TARGET.bak" ]; then
        mv -f "$TARGET.bak" "$TARGET"
        printf '↩️  되돌림: %s\n' "$TARGET"
    else
        printf '⚠️  백업이 없습니다: %s.bak\n' "$TARGET"
    fi
    exit 0
fi

if grep -q 'brightCyan(displayPath)' "$TARGET"; then
    printf '✅ 이미 적용됨: %s\n' "$TARGET"
    exit 0
fi

# perl 을 쓴다 — BSD/GNU sed 의 -i 인자 차이를 피한다(macOS·Linux 공용).
perl -i.bak -pe "
    s{import \{ dim \} from '\.\./colors\.js';}{import { brightCyan } from '../colors.js';};
    s{\\\$\{dim\(displayPath\)\}}{\\\$\{brightCyan(displayPath)\}};
" "$TARGET"

if grep -q 'brightCyan(displayPath)' "$TARGET"; then
    printf '✅ 적용: %s\n' "$TARGET"
    printf '   (원본은 %s.bak · Claude Code 재시작 후 반영)\n' "$TARGET"
else
    mv -f "$TARGET.bak" "$TARGET"
    printf '❌ 패턴이 맞지 않아 되돌렸습니다 — OMC 쪽 구현이 바뀐 것으로 보입니다.\n' >&2
    exit 1
fi
