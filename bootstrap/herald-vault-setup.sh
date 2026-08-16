#!/usr/bin/env bash
# herald-vault-setup — v0.2.28 세션기록 파이프라인을 관리 호스트에 한 번에 올린다.
#
#   하는 일 (순서대로)
#     1. bin/ 실행 권한 부여 → 변경이 있으면 커밋·push
#     2. install.sh 실행 (도구를 ~/.herald/bin 에 설치)
#     3. 셸 설정에 PATH 등록 (~/.profile·~/.bashrc·~/.zshrc)
#     4. vault 최신화 (git pull) — 이걸 빼면 서버의 회수분이 로컬에 없다
#     5. herald-sort  : _inbox 회수분을 제자리로 (모의로 보여 준 뒤 실제 이동)
#     6. herald-index : INDEX.md·index.json 재생성
#     7. herald-find  : 결과 확인
#     8. herald-legacy-import : 옛 기록 이관 — **--apply-legacy 를 줘야 옮긴다**
#     9. vault 커밋·push      : 정리·색인 결과를 서버에 올린다
#
#   안전 규칙
#     · **묻지 않고 끝까지 간다** (사용자 지시 2026-08-16). 확인을 받으려면 --ask
#     · 자동으로 하는 것은 전부 되돌릴 수 있는 동작이다 —
#       herald-sort 는 덮어쓰지 않고 꾸러미를 _done 으로 보존하며, 커밋은 git 이력에 남는다
#     · **파일을 원래 자리에서 없애는 유일한 동작**인 레거시 이관만은
#       --apply-legacy 를 명시해야 실행되고, --undo 로 되돌린다
#     · 어느 단계를 건너뛰었는지 마지막에 요약한다
#
#   사용
#     bash bootstrap/herald-vault-setup.sh                      # 묻지 않고 끝까지
#     bash bootstrap/herald-vault-setup.sh --ask                # 단계마다 확인
#     bash bootstrap/herald-vault-setup.sh --apply-legacy       # 옛 기록까지 이관
#     bash bootstrap/herald-vault-setup.sh --legacy-root ~/Desktop --legacy-root ~/Documents
#     bash bootstrap/herald-vault-setup.sh --no-commit --no-push --no-vault-commit
#
#   관리 호스트(vault 클론을 가진 컴퓨터)에서 실행한다.
#   일반 호스트는 vault 를 읽지 못하므로 이 스크립트가 필요하지 않다.
#
# 구현 주의 (실측으로 겪은 함정)
#   · `set -o pipefail` 을 쓰지 않는다 — `cmd | head` 에서 head 가 먼저 끝나면
#     SIGPIPE 로 앞 명령이 죽어 set -e 가 스크립트를 중단시킨다
#   · **배열을 쓰지 않는다** — macOS 기본 bash 3.2 는 `set -u` 상태에서 빈 배열을
#     펼치면 unbound variable 로 죽는다. 줄바꿈 구분 문자열 + 위치인자로 처리한다
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT="${HERALD_VAULT:-$HOME/herald-vault}"
HERALD_BIN="$HOME/.herald/bin"
SELF="$0"

ASK=0                # 기본은 묻지 않는다. --ask 로 확인을 켠다
DO_COMMIT=1
DO_PUSH=1
DO_VAULT_COMMIT=1
APPLY_LEGACY=0
LEGACY_ROOTS=""      # 줄바꿈 구분
DONE_STEPS=""
SKIPPED_STEPS=""

NL='
'

# ── 출력 ────────────────────────────────────────────────────────────────
say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m⚠\033[0m %s\n' "$*"; }
die()  { printf '\033[31m오류: %s\033[0m\n' "$*" >&2; exit 1; }

add_done()    { DONE_STEPS="${DONE_STEPS}${DONE_STEPS:+$NL}$1"; }
add_skipped() { SKIPPED_STEPS="${SKIPPED_STEPS}${SKIPPED_STEPS:+$NL}$1"; }

confirm() {
  # $1 = 물음. **기본은 묻지 않고 진행한다** (사용자 지시 2026-08-16).
  #   되돌릴 수 있는 동작만 자동으로 한다 —
  #     herald-sort  : 덮어쓰지 않고 꾸러미는 _done 으로 보존한다
  #     커밋·push    : git 이력이 남는다
  #     레거시 이관  : --apply-legacy 를 명시해야만 실행되고 --undo 로 되돌린다
  #   확인을 받고 싶으면 --ask 를 준다.
  # 주의: `[ … ] && return 0` 형태를 쓰지 않는다 — 조건이 거짓이면 AND 목록 전체가
  #       실패로 끝나 set -e 가 스크립트를 죽인다.
  if [ "$ASK" -eq 0 ]; then return 0; fi
  if [ ! -t 0 ]; then
    warn "대화형이 아니라 건너뜁니다"
    return 1
  fi
  local reply=""
  printf '   %s [y/N] ' "$1"
  read -r reply || true
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ── 인자 ────────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --ask)           ASK=1; shift ;;
    --yes|-y)        ASK=0; shift ;;          # 기본값. 옛 사용법 호환용으로 남긴다
    --no-commit)     DO_COMMIT=0; shift ;;
    --no-push)       DO_PUSH=0; shift ;;
    --no-vault-commit) DO_VAULT_COMMIT=0; shift ;;
    --apply-legacy)  APPLY_LEGACY=1; shift ;;
    --legacy-root)   [ $# -ge 2 ] || die "--legacy-root 에 경로가 필요합니다"
                     LEGACY_ROOTS="${LEGACY_ROOTS}${LEGACY_ROOTS:+$NL}$2"; shift 2 ;;
    --vault)         [ $# -ge 2 ] || die "--vault 에 경로가 필요합니다"
                     VAULT="$2"; shift 2 ;;
    -h|--help)       sed -n '2,31p' "$SELF"; exit 0 ;;
    *)               die "알 수 없는 인자: $1" ;;
  esac
done

# 레거시 기본 후보 — 실제로 있는 것만 쓴다. 없는 경로를 지어내지 않는다.
if [ -z "$LEGACY_ROOTS" ]; then
  for cand in "$HOME/Desktop" "$HOME/볼트상위/노트볼트" "$HOME/Documents"; do
    if [ -d "$cand" ]; then
      LEGACY_ROOTS="${LEGACY_ROOTS}${LEGACY_ROOTS:+$NL}$cand"
    fi
  done
fi

printf '\n\033[1m── herald-vault 세션기록 파이프라인 설치 (v0.2.28) ──\033[0m\n'
info "저장소  $REPO_DIR"
info "vault   $VAULT"

# ── 0. 전제 확인 ────────────────────────────────────────────────────────
say "0. 전제 확인"
command -v git     >/dev/null 2>&1 || die "git 이 필요합니다"
command -v python3 >/dev/null 2>&1 || die "python3 이 필요합니다"
info "python3  $(python3 -V 2>&1)"
if command -v rg >/dev/null 2>&1; then info "검색      ripgrep"
else info "검색      grep (ripgrep 이 있으면 훨씬 빠릅니다)"; fi

if [ ! -d "$VAULT/sessions" ]; then
  die "vault 를 찾을 수 없습니다: $VAULT
   이 스크립트는 **관리 호스트**(vault 클론 보유)에서 실행합니다.
   일반 호스트는 vault 를 읽지 못하므로 필요하지 않습니다.
   위치가 다르면 --vault <경로> 또는 HERALD_VAULT 로 지정하십시오."
fi
ok "vault 확인"

# ── 1. 실행 권한 + 커밋 ─────────────────────────────────────────────────
say "1. bin/ 실행 권한"
chmod 755 "$REPO_DIR"/bin/herald-* 2>/dev/null || true
ls -l "$REPO_DIR/bin/" | sed 's/^/   /'

if [ "$DO_COMMIT" -eq 1 ] && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
    info "커밋할 변경이 있습니다:"
    git -C "$REPO_DIR" status --short | sed 's/^/     /'
    if confirm "커밋하시겠습니까?"; then
      git -C "$REPO_DIR" add -A
      git -C "$REPO_DIR" commit -F - <<'EOF'
v0.2.28 chore: bin/ 실행 권한 부여

새 도구 4종(herald-index·find·sort·legacy-import)이 100644 로 들어가 있었다.
install.sh 는 install -m 755 로 깔므로 동작에는 지장이 없으나,
저장소에서 직접 실행할 수 있도록 실행 권한을 맞춘다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
      ok "커밋 완료"
      add_done "커밋"
      if [ "$DO_PUSH" -eq 1 ] && git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
        if confirm "push 하시겠습니까?"; then
          git -C "$REPO_DIR" push
          ok "push 완료"
          add_done "push"
        else
          add_skipped "push (사용자 보류)"
        fi
      else
        add_skipped "push (--no-push 또는 remote 없음)"
      fi
    else
      add_skipped "커밋 (사용자 보류)"
    fi
  else
    ok "변경 없음 — 커밋할 것이 없습니다"
  fi
else
  add_skipped "커밋 (--no-commit 또는 git 저장소 아님)"
fi

# ── 2. 도구 설치 ────────────────────────────────────────────────────────
say "2. 도구 설치 (install.sh)"
[ -f "$REPO_DIR/install.sh" ] || die "install.sh 를 찾을 수 없습니다"
bash "$REPO_DIR/install.sh"
add_done "install.sh"

[ -x "$HERALD_BIN/herald-index" ] || die "$HERALD_BIN/herald-index 가 설치되지 않았습니다"
PATH="$HERALD_BIN:$PATH"
export PATH
ok "PATH 에 $HERALD_BIN 추가 (이 스크립트 안에서만)"

# ── 3. 셸 설정에 PATH 심기 ──────────────────────────────────────────────
say "3. 셸 설정에 PATH 등록"
# ~/.profile 이 필수다 — 우분투 기본 ~/.bashrc 는 맨 앞에서 비대화형이면 즉시 return 한다.
PATH_LINE='export PATH="$HOME/.herald/bin:$PATH"'
rc_touched=0
for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ ! -f "$rc" ]; then
    [ "$rc" = "$HOME/.profile" ] || continue
    : > "$rc"
  fi
  if grep -q '\.herald/bin' "$rc" 2>/dev/null; then
    info "이미 있음 — $rc"
    rc_touched=$((rc_touched + 1))
    continue
  fi
  cp -a "$rc" "$rc.herald-bak.$(date +%Y%m%dT%H%M%S)"
  {
    printf '\n# herald-vault 도구\n'
    printf '%s\n' "$PATH_LINE"
  } >> "$rc"
  ok "추가됨 — $rc (원본 백업 있음)"
  rc_touched=$((rc_touched + 1))
done
[ "$rc_touched" -gt 0 ] || warn "셸 설정을 찾지 못했습니다 — 직접 넣으십시오: $PATH_LINE"

# ── 4. vault 최신화 ─────────────────────────────────────────────────────
# 이걸 빼먹으면 수집기가 서버에 올려 둔 회수분이 로컬에 없어 herald-sort 가 0건을 보고한다.
# (2026-08-16 실측: _inbox/general-host 에 73개가 있는데 로컬은 비어 있었다)
say "4. vault 최신화 (git pull)"
if git -C "$VAULT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$VAULT" remote get-url origin >/dev/null 2>&1; then
    if git -C "$VAULT" pull --ff-only; then
      ok "최신 상태"
      add_done "vault pull"
    else
      warn "pull 실패 — 로컬 변경이나 충돌이 있는지 확인하십시오"
      warn "이대로 진행하면 서버의 회수분이 빠진 채로 정리·색인됩니다"
      add_skipped "vault pull (실패)"
    fi
  else
    info "remote 가 없습니다 — 건너뜁니다"
  fi
else
  info "git 저장소가 아닙니다 — 건너뜁니다"
fi

# ── 5. _inbox 정리 ──────────────────────────────────────────────────────
say "5. _inbox 회수분 정리 (herald-sort)"
if [ -d "$VAULT/_inbox" ]; then
  info "먼저 모의 실행으로 무엇이 어디로 갈지 봅니다."
  sort_rc=0
  herald-sort --vault "$VAULT" || sort_rc=$?
  if [ "$sort_rc" -ne 0 ]; then
    warn "충돌이 있습니다 — 덮어쓰지 않고 남겨 두었습니다. 위 목록을 확인하십시오"
  fi
  if confirm "실제로 정리하시겠습니까? (덮어쓰지 않고, 꾸러미는 _done 으로 보존됩니다)"; then
    herald-sort --vault "$VAULT" --apply || warn "일부 충돌이 남았습니다"
    add_done "herald-sort --apply"
  else
    add_skipped "herald-sort --apply (사용자 보류)"
  fi
else
  info "_inbox 가 없습니다 — 건너뜁니다"
fi

# ── 6. 색인 ─────────────────────────────────────────────────────────────
say "6. 색인 재생성 (herald-index)"
herald-index --vault "$VAULT"
add_done "herald-index"

# ── 7. 확인 ─────────────────────────────────────────────────────────────
say "7. 확인 (herald-find)"
herald-find --vault "$VAULT" --list || true

# ── 8. 레거시 이관 ──────────────────────────────────────────────────────
say "8. 과거 기록 이관 (herald-legacy-import)"
if [ -z "$LEGACY_ROOTS" ]; then
  warn "찾을 경로가 없습니다 — --legacy-root 로 지정하십시오"
  add_skipped "레거시 이관 (경로 없음)"
else
  info "대상 경로:"
  printf '%s\n' "$LEGACY_ROOTS" | while IFS= read -r r; do
    if [ -n "$r" ]; then printf '     · %s\n' "$r"; fi
  done

  # 줄바꿈 구분 문자열을 위치인자로 펼친다 (glob 확장 차단)
  old_ifs="$IFS"; IFS="$NL"; set -f
  # shellcheck disable=SC2086
  set -- $LEGACY_ROOTS
  set +f; IFS="$old_ifs"

  info "먼저 모의 실행합니다 — 파일은 움직이지 않습니다."
  herald-legacy-import --vault "$VAULT" "$@" || true

  if [ "$APPLY_LEGACY" -eq 1 ]; then
    if confirm "위 목록을 sessions/_legacy/ 로 **이동**하시겠습니까? (원본 위치에서 사라집니다)"; then
      herald-legacy-import --vault "$VAULT" "$@" --apply
      herald-index --vault "$VAULT"
      add_done "레거시 이관 + 색인 갱신"
      info "되돌리려면: herald-legacy-import --vault \"$VAULT\" --undo --apply"
    else
      add_skipped "레거시 이관 (사용자 보류)"
    fi
  else
    info "실제로 옮기려면 --apply-legacy 를 주고 다시 실행하십시오:"
    printf '     bash %s --apply-legacy' "$SELF"
    for r in "$@"; do printf ' --legacy-root "%s"' "$r"; done
    printf '\n'
    add_skipped "레거시 이관 (--apply-legacy 미지정)"
  fi
fi

# ── 9. vault 커밋·push ──────────────────────────────────────────────────
# 정리·색인 결과가 로컬에만 남으면 다른 컴퓨터에서 찾을 수 없다. 여기까지가 한 벌이다.
say "9. vault 커밋·push"
if [ "$DO_VAULT_COMMIT" -eq 0 ]; then
  add_skipped "vault 커밋 (--no-vault-commit)"
elif ! git -C "$VAULT" rev-parse --git-dir >/dev/null 2>&1; then
  info "git 저장소가 아닙니다 — 건너뜁니다"
elif [ -z "$(git -C "$VAULT" status --porcelain)" ]; then
  ok "변경 없음"
else
  git -C "$VAULT" status --short | head -20 | sed 's/^/     /'
  vault_n=$(git -C "$VAULT" status --porcelain | wc -l | tr -d ' ')
  info "변경 $vault_n 건"
  if confirm "vault 에 커밋하시겠습니까?"; then
    git -C "$VAULT" add -A
    git -C "$VAULT" commit -F - <<EOF
chore(vault): 회수분 정리·색인 반영 ($vault_n 건)

herald-sort 로 _inbox 회수분을 제자리로 옮기고 herald-index 로 색인을 다시 만들었다.
herald-vault-setup.sh 자동 실행.
EOF
    ok "커밋 완료"
    add_done "vault 커밋 ($vault_n 건)"
    if [ "$DO_PUSH" -eq 1 ] && git -C "$VAULT" remote get-url origin >/dev/null 2>&1; then
      if git -C "$VAULT" push; then
        ok "push 완료"
        add_done "vault push"
      else
        warn "push 실패 — 나중에 직접 push 하십시오"
        add_skipped "vault push (실패)"
      fi
    else
      add_skipped "vault push (--no-push 또는 remote 없음)"
    fi
  else
    add_skipped "vault 커밋 (사용자 보류)"
  fi
fi

# ── 요약 ────────────────────────────────────────────────────────────────
say "요약"
if [ -n "$DONE_STEPS" ]; then
  printf '%s\n' "$DONE_STEPS" | while IFS= read -r s; do
    if [ -n "$s" ]; then ok "$s"; fi
  done
fi
if [ -n "$SKIPPED_STEPS" ]; then
  printf '%s\n' "$SKIPPED_STEPS" | while IFS= read -r s; do
    if [ -n "$s" ]; then warn "건너뜀 — $s"; fi
  done
fi

cat <<EOF

   이제 이렇게 씁니다 (새 셸부터 PATH 가 잡힙니다):

     herald-find "검색어"
     herald-find --list
     herald-find --project herald-ai --since 2026-08-01
     herald-find --open <id>

   상태 확인:

     git -C "$VAULT" status --short
EOF
