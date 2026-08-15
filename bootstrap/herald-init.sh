#!/usr/bin/env bash
# herald-init — 이 컴퓨터를 herald-vault 에 참여시킨다 (일반 호스트용)
#
#   하는 일
#     1. 도구 설치            ~/.herald/bin/{herald-send,herald-env}
#     2. 투입구 전용 키 발급   ~/.ssh/id_herald_drop   (이 호스트만의 키 — 개별 회수 가능)
#     3. 설정 작성            ~/.herald/vault.conf
#     4. 서버에 등록할 공개키를 화면에 출력
#
#   하지 않는 일
#     서버를 건드리지 않는다. 등록은 관리자가 vault-server 에서 herald-host-add.sh 로 한다.
#
#   사용
#     bash bootstrap/herald-init.sh                    # 대화형
#     bash bootstrap/herald-init.sh --host general-host --server <vault-server> --yes
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERALD="$HOME/.herald"
BIN="$HERALD/bin"
CONF="$HERALD/vault.conf"
KEY="$HOME/.ssh/id_herald_drop"

HOST_NAME=""
DROP_HOST=""
DROP_PORT=22
DROP_USER=hdrop
ASSUME_YES=0

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '\033[31m오류: %s\033[0m\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)   HOST_NAME="${2:?}"; shift 2 ;;
    --server) DROP_HOST="${2:?}"; shift 2 ;;
    --port)   DROP_PORT="${2:?}"; shift 2 ;;
    --user)   DROP_USER="${2:?}"; shift 2 ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "알 수 없는 인자: $1" ;;
  esac
done

say "0. 전제 확인"
command -v python3 >/dev/null || die "python3 가 필요합니다"
command -v ssh     >/dev/null || die "ssh 가 필요합니다"
command -v tar     >/dev/null || die "tar 가 필요합니다"
info "python3  $(python3 -V 2>&1)"
if command -v zstd >/dev/null; then
  info "압축      zstd ($(zstd --version 2>&1 | head -1 | tr -d '*' | xargs))"
else
  info "압축      gzip (zstd 없음 — 자동 대체. 설치하면 전송량이 줄어듭니다)"
fi

# 호스트 이름 기본값 — 소문자·안전문자만
default_host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)
default_host=$(printf '%s' "$default_host" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9._-' '-')
if [[ -z "$HOST_NAME" ]]; then
  if [[ $ASSUME_YES -eq 1 ]]; then HOST_NAME="$default_host"
  else
    read -r -p "  이 컴퓨터의 호스트 이름 [$default_host]: " HOST_NAME
    HOST_NAME="${HOST_NAME:-$default_host}"
  fi
fi
case "$HOST_NAME" in *[!a-z0-9._-]*|'') die "호스트 이름은 소문자·숫자·.·_·- 만 됩니다: $HOST_NAME" ;; esac

if [[ -z "$DROP_HOST" ]]; then
  if [[ $ASSUME_YES -eq 1 ]]; then die "--server 를 지정하십시오"
  else read -r -p "  vault 서버 주소 [<vault-server>]: " DROP_HOST; DROP_HOST="${DROP_HOST:-<vault-server>}"; fi
fi

say "1. 도구 설치"
mkdir -p "$BIN" "$HERALD/staging/sessions" "$HERALD/staging/handover" "$HERALD/outbox"
chmod 700 "$HERALD"
for t in herald-send herald-env; do
  [[ -f "$REPO_DIR/bin/$t" ]] || die "$REPO_DIR/bin/$t 가 없습니다 (herald-ai 저장소 안에서 실행하십시오)"
  install -m 755 "$REPO_DIR/bin/$t" "$BIN/$t"
  info "$BIN/$t"
done
python3 -c "import ast,sys; [ast.parse(open(p).read()) for p in sys.argv[1:]]" \
        "$BIN/herald-send" "$BIN/herald-env" && info "구문 검사 통과"

say "2. 투입구 전용 키"
if [[ -f "$KEY" ]]; then
  info "이미 있음 — 재사용 ($KEY)"
else
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -N '' -C "herald-drop@$HOST_NAME" -f "$KEY" >/dev/null
  info "발급됨 ($KEY)"
fi
chmod 600 "$KEY"; chmod 644 "$KEY.pub"

say "3. 설정 작성"
if [[ -f "$CONF" ]]; then
  cp -a "$CONF" "$CONF.bak.$(date +%Y%m%dT%H%M%S)"
  info "기존 설정 백업"
fi
cat > "$CONF" <<EOF
# herald-vault 참여 설정 — $(date -u +%FT%TZ) 생성
#   이 파일과 키는 git 에 들어가지 않는다.

HOST_NAME=$HOST_NAME
DROP_HOST=$DROP_HOST
DROP_PORT=$DROP_PORT
DROP_USER=$DROP_USER
DROP_KEY=$KEY

# 원문(jsonl)까지 보낼 것인가. 골격이 검증된 뒤 1 로 바꾼다.
SEND_RAW=0
EOF
chmod 600 "$CONF"
sed 's/^/  /' "$CONF"

say "4. 세션 기록 저장 위치"
info "다음 줄을 셸 설정(~/.bashrc 또는 ~/.zshrc)에 넣으십시오:"
printf '\n    export HERALD_LOG_DIR="%s/staging/sessions"\n\n' "$HERALD"
info "그러면 /session-save 산출물이 이 위치에 쌓이고, herald-send 가 집어 올립니다."

say "완료 — 관리자에게 아래 한 줄을 전달하십시오"
echo
printf '\033[1msudo bash herald-host-add.sh %s %s\033[0m\n' "$HOST_NAME" "'$(cat "$KEY.pub")'"
echo
cat <<EOF
  등록이 끝나면 이렇게 확인합니다:

    $BIN/herald-send docs env --dry-run    # 무엇이 갈지만 본다
    $BIN/herald-send docs env              # 실제 전송

  이 컴퓨터는 **올리기만** 할 수 있습니다. vault 를 읽을 수 없습니다.
EOF
