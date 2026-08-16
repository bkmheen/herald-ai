#!/usr/bin/env bash
# 일반 호스트를 투입구에 등록한다 — **vault 서버에서** 실행
#
#   sudo bash herald-host-add.sh <호스트이름> '<ssh 공개키 한 줄>'
#   예) sudo bash herald-host-add.sh laptop 'ssh-ed25519 AAAA... herald-drop@laptop'
#
#   공개키는 각 호스트에서 bootstrap/herald-init.sh 를 돌리면 마지막에 출력된다.
#
#   호스트 이름은 이 서버의 authorized_keys 에 박힌다. 클라이언트는 위조할 수 없다.
#   계통(docs|raw|env)만 클라이언트가 고르며, 서버가 화이트리스트로 검증한다.
#
#   회수: /var/lib/herald/drop-home/.ssh/authorized_keys 에서 해당 줄을 지우면 즉시 차단된다.
set -eu

HOST="${1:-}"
KEY="${2:-}"
DROP_HOME=/var/lib/herald/drop-home
AK="$DROP_HOME/.ssh/authorized_keys"

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
[[ $EUID -eq 0 ]] || { echo "root 로 실행해야 합니다"; exit 1; }
[[ -n "$HOST" && -n "$KEY" ]] || {
  echo "사용법: sudo bash $0 <호스트이름> '<ssh 공개키 한 줄>'"; exit 1; }
case "$HOST" in *[!a-z0-9._-]*) echo "호스트 이름은 소문자·숫자·.·_·- 만 됩니다"; exit 1 ;; esac
case "$KEY" in ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) ;; *) echo "공개키 형식이 아닙니다"; exit 1 ;; esac

say "1. herald-drop 갱신 — 계통을 요청 명령에서 받되 검증한다"
[[ -f /usr/local/bin/herald-drop ]] && \
  cp -a /usr/local/bin/herald-drop "/usr/local/bin/herald-drop.bak-$(date +%Y%m%dT%H%M%S)"
cat > /usr/local/bin/herald-drop <<'DROP'
#!/bin/bash
# 투입구 수신 — 받기만 한다. 파일을 내보내는 코드 경로가 존재하지 않는다.
#
#   authorized_keys 에서 다음 형태로 호출된다:
#     command="/usr/local/bin/herald-drop <host>",restrict <공개키>
#
#   <host>  서버가 키에 박아 둔 값 → 클라이언트가 위조할 수 없다
#   <kind>  클라이언트가 SSH 명령으로 요청 → 서버가 화이트리스트로 검증한다
#           (계통 선택은 저장 위치만 정하므로 위조되어도 피해가 없다)
#           authorized_keys 에 2번째 인자를 주면 그 값으로 고정된다.
set -eu
HOST="${1:?host required}"
KIND="${2:-}"
if [[ -z "$KIND" ]]; then
  KIND="${SSH_ORIGINAL_COMMAND:-docs}"
  KIND="${KIND%% *}"                  # 첫 낱말만 — 뒤에 무엇이 붙어도 무시
fi
case "$KIND" in docs|raw|env) ;; *) echo "bad kind" >&2; exit 2 ;; esac
case "$HOST" in *[!a-z0-9._-]*|'') echo "bad host" >&2; exit 2 ;; esac

MAX=$((2 * 1024 * 1024 * 1024))       # 한 꾸러미 상한 2GB
INBOX=/var/lib/herald/inbox
DIR="$INBOX/$HOST/$KIND"
mkdir -p "$DIR"
STAMP=$(date -u +%Y%m%dT%H%M%S%NZ)
TMP="$DIR/.$STAMP.part"
DST="$DIR/$STAMP.tar.zst"

umask 007
# head -c 로 상한을 강제한다. 표준입력을 파일로 옮기는 것 외의 동작은 없다.
head -c "$MAX" > "$TMP"
SIZE=$(stat -c%s "$TMP")
if [[ "$SIZE" -eq 0 ]]; then rm -f "$TMP"; echo "ERR empty" >&2; exit 3; fi
SUM=$(sha256sum "$TMP" | cut -d' ' -f1)
mv "$TMP" "$DST"

# 수집기를 즉시 깨운다 (systemd PathChanged 는 하위 디렉토리를 감시하지 못한다).
# 꾸러미가 완성된 뒤에만 실행되므로 미완성 파일이 처리되지 않는다.
: > "$INBOX/.trigger" 2>/dev/null || true

echo "OK $HOST/$KIND $STAMP $SIZE $SUM"
DROP
chmod 0755 /usr/local/bin/herald-drop
chown root:root /usr/local/bin/herald-drop
bash -n /usr/local/bin/herald-drop && echo "  ✓ 갱신·문법 검사 통과"

say "2. hdrop 의 authorized_keys 준비"
install -d -o hdrop -g hdrop -m 0700 "$DROP_HOME/.ssh"
[[ -f "$AK" ]] || install -o hdrop -g hdrop -m 0600 /dev/null "$AK"
# sshd 는 홈·.ssh 가 그룹/기타 쓰기 가능하면 키를 무시한다
chown hdrop:hdrop "$DROP_HOME"; chmod 0755 "$DROP_HOME"
ls -ld "$DROP_HOME" "$DROP_HOME/.ssh" "$AK" | sed 's/^/  /'

say "3. 호스트 '$HOST' 등록"
KEYB64=$(awk '{print $2}' <<<"$KEY")
if grep -qF "$KEYB64" "$AK" 2>/dev/null; then
  echo "  이 공개키는 이미 등록되어 있습니다 — 해당 줄을 교체합니다"
  grep -vF "$KEYB64" "$AK" > "$AK.new" || true
  mv "$AK.new" "$AK"
  chown hdrop:hdrop "$AK"; chmod 0600 "$AK"
fi
# restrict = 셸·scp·sftp·포트포워딩·X11·에이전트전달 전부 차단 (OpenSSH 7.2+)
printf 'command="/usr/local/bin/herald-drop %s",restrict %s\n' "$HOST" "$KEY" >> "$AK"
chown hdrop:hdrop "$AK"; chmod 0600 "$AK"
echo "  ✓ 등록됨"

say "4. 등록 현황 (공개키는 줄여서 표시)"
nl -ba "$AK" | sed 's/\(AAAA[A-Za-z0-9+/=]\{12\}\)[A-Za-z0-9+/=]*/\1…/' | sed 's/^/  /'

say "5. 투입 대상 디렉토리 준비"
for k in docs raw env; do
  install -d -o hdrop -g herald -m 2770 "/var/lib/herald/inbox/$HOST/$k"
done
ls -ld /var/lib/herald/inbox/"$HOST"/* | sed 's/^/  /'

say "완료"
cat <<EOF
  호스트 이름 : $HOST   (서버가 결정 — 클라이언트가 바꿀 수 없음)
  투입 방법   : tar | zstd | ssh -i <키> hdrop@<서버> <docs|raw|env>
  회수 방법   : $AK 에서 해당 줄 삭제 (즉시 차단)
  수신 위치   : /var/lib/herald/inbox/$HOST/<계통>/

  등록 뒤 해당 호스트에서:
    ~/.herald/bin/herald-send docs env --dry-run
    ~/.herald/bin/herald-send docs env
EOF
