#!/usr/bin/env bash
# herald-convention-init — 새 저장소에 커밋 규약 v3.1.0 을 도입한다(스캐폴딩).
#
# 무엇을 만드는가
#   VERSION(0.1.10) · CHANGELOG.md · DEVLOG.md · 규약 절이 든 CLAUDE.md.
#   Claude Code 는 저장소의 CLAUDE.md 를 자동으로 읽으므로, 그 안에 규약이 있으면
#   **그 저장소에서 세션을 여는 누구에게나** 같은 규칙이 적용된다.
#
# 사용
#   bash bootstrap/herald-convention-init.sh <대상 저장소>                  # 모의 실행(기본)
#   bash bootstrap/herald-convention-init.sh <대상 저장소> --apply          # 실제 생성
#   bash bootstrap/herald-convention-init.sh <대상 저장소> --apply --public # 공개 저장소용 트레일러 주석
#
# 원칙
#   - **기존 파일은 절대 덮지 않는다.** 이미 있으면 건너뛰고 알린다.
#   - 대상에 CLAUDE.md 가 이미 있으면 손대지 않고 `CLAUDE.convention.md` 를 따로 만든 뒤,
#     어디에 붙일지 안내만 한다. 남의 지침 파일을 임의로 고치지 않는다.
#   - 기본이 모의 실행이다. --apply 를 줄 때만 파일을 만든다.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$REPO_DIR/templates/new-repo"
DOC="$REPO_DIR/docs/COMMIT-CONVENTION.md"

TARGET=""; APPLY=0; VISIBILITY="private"
for arg in "$@"; do
    case "$arg" in
        --apply)   APPLY=1 ;;
        --public)  VISIBILITY="public" ;;
        --private) VISIBILITY="private" ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        -*) printf '❌ 모르는 인자: %s (--help)\n' "$arg" >&2; exit 2 ;;
        *)  TARGET="$arg" ;;
    esac
done

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
skip() { printf '  ↷ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }

[ -n "$TARGET" ] || { printf '❌ 대상 저장소 경로가 필요합니다 (--help)\n' >&2; exit 2; }
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { printf '❌ 경로를 찾을 수 없습니다: %s\n' "$TARGET" >&2; exit 1; }
[ -d "$TPL" ] || { printf '❌ 템플릿이 없습니다: %s\n' "$TPL" >&2; exit 1; }

if [ "$VISIBILITY" = "public" ]; then
    TRAILER_NOTE='⛔ 공개 저장소이므로 `Worked-On`·`Committed-To` 는 쓰지 않습니다 — 호스트명·IP 가 커밋에 영구히 남습니다.
  작성자 이메일도 공개해도 되는 주소로 고정합니다: `git config user.email <공개 주소>`'
else
    TRAILER_NOTE='비공개 저장소이므로 `Worked-On`(호스트·IP·작업 디렉토리)·`Committed-To`(원격 커밋 시)·`Model` 을 함께 남깁니다.'
fi

say "── 커밋 규약 v3.1.0 도입 ───────────────────────"
say "  대상: $TARGET"
say "  성격: $([ "$VISIBILITY" = public ] && echo '공개 저장소' || echo '비공개 저장소')"
[ "$APPLY" = "1" ] || say "  모드: 모의 실행 — 실제로 만들려면 --apply"
say ""

[ -d "$TARGET/.git" ] || warn "git 저장소가 아닙니다 (git init 이 먼저 필요할 수 있습니다)"

render() {   # <템플릿파일> → 치환된 내용을 표준출력으로
    # 정본 경로는 홈을 `~` 로 줄여 넣는다. 대상 저장소가 다른 맥에서 clone 될 수 있고,
    # 절대경로를 박으면 계정명이 그 저장소에 그대로 남는다.
    TPL_FILE="$1" DOC="${DOC/#$HOME/\~}" TRAILER_NOTE="$TRAILER_NOTE" DATE="$(date +%Y-%m-%d)" python3 - <<'PY'
import os
s = open(os.environ['TPL_FILE'], encoding='utf-8').read()
for k in ('DOC', 'TRAILER_NOTE', 'DATE'):
    s = s.replace('{{CONVENTION_DOC}}' if k == 'DOC' else '{{%s}}' % k, os.environ[k])
print(s, end='')
PY
}

place() {    # <템플릿파일> <대상파일>
    local src="$1" dst="$2"
    if [ -e "$dst" ]; then skip "$(basename "$dst") — 이미 있음, 건드리지 않음"; return; fi
    if [ "$APPLY" = "1" ]; then render "$src" > "$dst"; ok "$(basename "$dst") 생성"
    else ok "$(basename "$dst") 생성 예정"; fi
}

place "$TPL/VERSION"      "$TARGET/VERSION"
place "$TPL/CHANGELOG.md" "$TARGET/CHANGELOG.md"
place "$TPL/DEVLOG.md"    "$TARGET/DEVLOG.md"

# CLAUDE.md — 없으면 규약 절로 새로 만들고, 있으면 별도 파일로 두고 안내만 한다
if [ -e "$TARGET/CLAUDE.md" ]; then
    if [ -e "$TARGET/CLAUDE.convention.md" ]; then
        skip "CLAUDE.convention.md — 이미 있음, 건드리지 않음"
    elif [ "$APPLY" = "1" ]; then
        render "$TPL/CLAUDE.convention.md" > "$TARGET/CLAUDE.convention.md"
        ok "CLAUDE.convention.md 생성 (기존 CLAUDE.md 는 그대로)"
    else
        ok "CLAUDE.convention.md 생성 예정 (기존 CLAUDE.md 는 그대로)"
    fi
    warn "대상에 CLAUDE.md 가 이미 있습니다. 아래 한 줄을 직접 넣으십시오:"
    say  "       > 커밋·버전 규약은 [CLAUDE.convention.md](CLAUDE.convention.md) 를 따릅니다 (규약 v3.1.0)."
elif [ "$APPLY" = "1" ]; then
    { printf '# CLAUDE.md — %s 작업 규칙\n\n' "$(basename "$TARGET")"
      printf '이 파일은 Claude Code 가 저장소 진입 시 자동으로 읽는 규칙 문서입니다.\n'
      printf 'git 으로 배포되므로 **어느 맥에서 clone 하든 같은 규칙이 적용됩니다.**\n\n'
      render "$TPL/CLAUDE.convention.md"; } > "$TARGET/CLAUDE.md"
    ok "CLAUDE.md 생성 (규약 절 포함)"
else
    ok "CLAUDE.md 생성 예정 (규약 절 포함)"
fi

say ""
if [ "$APPLY" = "1" ]; then
    say "다음 단계:"
    say "  1) CHANGELOG.md 의 Verified 에 **실제로 돌린** 검증 명령과 결과를 적습니다."
    say "  2) DEVLOG.md 에 이 저장소를 만든 이유를 적습니다."
    say "  3) 첫 커밋 — 사용자 요청이 있을 때:"
    say "       git -C $TARGET add -A"
    say "       git -C $TARGET commit -F -   # 제목: v0.1.10 [init] <한국어 요약>"
    say "  4) 이후로는 \"v3.1 커밋 체계\" 라고 부르면 됩니다."
else
    say "실제로 만들려면 --apply 를 붙여 다시 실행하십시오:"
    say "  bash $0 $TARGET --apply$([ "$VISIBILITY" = public ] && echo ' --public')"
fi
say "  정본: $DOC"
say "──────────────────────────────────────────────"
