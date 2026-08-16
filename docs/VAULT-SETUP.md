# herald-vault 구성 절차

세션기록·기억·환경을 한 저장소로 모으는 파이프라인을 세우는 방법이다.
왜 이런 구조인지는 [`DESIGN.md`](DESIGN.md), 기록 형식은 [`SESSION-RECORD.md`](SESSION-RECORD.md).

> **여기에는 특정 서버의 주소가 나오지 않는다.** 모든 값은 `~/.herald/vault.conf` 의
> 설정 항목으로 넣는다 — 표본은 [`config/vault.conf.example`](../config/vault.conf.example).

---

## 0. 역할을 정한다

| 역할 | 하는 일 | 필요한 것 |
|---|---|---|
| **vault 서버** | 저장소를 담고, 투입구로 받아 수집한다 | git 호스팅(Forgejo 등)·SSH·상시 가동 |
| **관리 호스트** | vault 를 clone 해 정리·색인·검색한다 | vault 읽기·쓰기 권한 |
| **일반 호스트** | 자기 기록을 **올리기만** 한다 | 투입 전용 SSH 키 하나 |

한 대뿐이라면 vault 서버 = 관리 호스트여도 된다. 일반 호스트는 나중에 붙이면 된다.

---

## 1. vault 서버 준비

git 호스팅에 **비공개 저장소 두 개**를 만든다.

| 저장소 | 용도 |
|---|---|
| `herald-vault` | 본문 — 규약·세션기록·인계·기억·환경 |
| `herald-vault-raw` | 원문(`*.jsonl`) — Git LFS. 나중에 켜도 된다 |

그리고 **계정을 둘로 나눈다.**

| 계정 | 권한 | 왜 |
|---|---|---|
| 투입 계정 (`hdrop`) | SSH 로 받기만 함. **저장소 키 없음** | 투입 통로가 뚫려도 저장소를 얻지 못한다 |
| 수집 계정 (`herald`) | 저장소 배포키 보유 | inbox → vault 반영 |

수신 프로그램(`herald-drop`)과 수집기(`herald-collect`)는 서버에 둔다.
수집기는 파일 변경 감지(예: systemd path unit)로 깨우고, **주기 타이머를 안전망으로** 함께 건다.

> 감시 유닛이 **하위 디렉토리를 재귀로 보지 않는** 구현이 흔하다. 수신 프로그램이
> 감시 대상 디렉토리에 트리거 파일을 남기게 하면 확실하다.

---

## 2. 관리 호스트 연결

```bash
git clone <vault 저장소 주소> ~/herald-vault
cd ~/Code/herald-ai && bash install.sh
export PATH="$HOME/.herald/bin:$PATH"        # 셸 설정에도 넣는다
```

`install.sh` 가 `bin/` 의 도구를 `~/.herald/bin/` 에 설치한다.

**관리 호스트에는 `HERALD_LOG_DIR` 를 설정하지 않는다.** 설정하면 `/session-save` 가
vault 대신 그 경로에 쌓는다 (일반 호스트에서만 쓰는 값이다).

---

## 3. 일반 호스트 참여

참여할 컴퓨터에서:

```bash
git clone <herald-ai 주소> ~/Code/herald-ai
bash ~/Code/herald-ai/bootstrap/herald-init.sh --host <이 컴퓨터 이름> --server <vault 서버 주소>
```

이 스크립트는 **서버를 건드리지 않는다.** 다음만 한다.

1. `~/.herald/bin/` 에 도구 설치
2. 투입 전용 키 `~/.ssh/id_herald_drop` 발급 — **이 호스트만의 키라 개별 회수가 된다**
3. `~/.herald/vault.conf` 작성 (`config/vault.conf.example` 의 항목들)
4. `HERALD_LOG_DIR` 를 셸 설정에 등록
5. **등록용 공개키를 화면에 출력**

> `~/.profile` 에도 넣어야 한다. 배포판 기본 `~/.bashrc` 는 맨 앞에서
> `case $- in *i*) ;; *) return;; esac` 로 **비대화형 셸이면 즉시 return** 하므로,
> `.bashrc` 에만 넣으면 `bash -lc` 에서 값이 비어 있다.

---

## 4. 서버에 호스트 등록

출력된 공개키를 가지고 **vault 서버에서** 실행한다 (root 권한 필요).

```bash
sudo bash herald-host-add.sh <호스트이름> '<ssh 공개키 한 줄>'
```

1. 수신 프로그램을 갱신 — 계통(`docs`/`raw`/`env`)을 요청에서 받되 화이트리스트로 검증
2. 투입 계정의 `authorized_keys` 에 `command="…herald-drop <호스트>",restrict <키>` 추가
3. `inbox/<호스트>/{docs,raw,env}` 생성

**호스트 이름을 서버가 키에 박는다** — 클라이언트가 바꿀 수 없다.
회수는 `authorized_keys` 에서 그 줄을 지우면 끝난다.

---

## 5. 전송 확인

```bash
~/.herald/bin/herald-send docs env --dry-run     # 무엇이 갈지 먼저 본다
~/.herald/bin/herald-send docs env               # 실제 전송
```

기대 출력:

```
호스트 <이름> → <계정>@<서버>:<포트>
── docs ──
  후보 N개
  보낼 것 N개 · x.x MB
  ✓ 전송 완료 — OK <호스트>/docs <시각> <bytes> <sha256>
  대장 갱신: N개
```

**한 번 더 실행하면 `보낼 것 없음` 이 나와야 한다.** 로컬 대장이 중복을 걸러 준다는 뜻이다.

서버 쪽은 수집기 로그로 확인한다. `inbox` 를 `ls` 하면 **권한 거부가 정상**이다 —
투입 계정과 수집 계정만 접근하도록 되어 있고 관리 계정은 두 그룹에 속하지 않는다.

---

## 6. 관리 호스트에서 정리·색인

한 번에 하려면:

```bash
bash ~/Code/herald-ai/bootstrap/herald-vault-setup.sh
```

순서대로 수행한다 — 실행 권한 → 도구 설치 → PATH 등록 → **vault pull** →
`herald-sort` → `herald-index` → `herald-find` 확인 → 옛 기록 이관(모의) → vault 커밋·push.

**묻지 않고 끝까지 간다.** 자동으로 하는 것은 전부 되돌릴 수 있는 동작뿐이다 —
`herald-sort` 는 덮어쓰지 않고 꾸러미를 `_done` 에 보존하며, 커밋은 이력에 남는다.
단계마다 확인을 받으려면 `--ask`.

손으로 하려면:

```bash
git -C ~/herald-vault pull                 # 서버의 회수분을 먼저 받는다
herald-sort            # 모의 — 무엇이 어디로 갈지 본다
herald-sort --apply    # 실제 정리
herald-index           # 색인 재생성 (멱등)
herald-find --list
```

> `git pull` 을 빼먹으면 서버에 쌓인 회수분이 로컬에 없어 `herald-sort` 가 0건을 보고한다.

---

## 7. 옛 기록 모으기

흩어져 있던 예전 세션기록을 vault 로 모은다. **파일명·내용을 고치지 않고** 옮긴다.

```bash
herald-legacy-import ~/Desktop <다른 경로…>              # 모의 (기본)
herald-legacy-import ~/Desktop <다른 경로…> --apply      # 실제 이동
herald-index                                             # 이관 뒤 색인 갱신
herald-legacy-import --undo --apply                      # 되돌리기
```

- 같은 내용의 사본이 여러 경로에 있으면 **sha256 으로 판정해 하나만** 옮긴다
- 이름이 겹치면 ` (2)` 를 붙인다 — 덮어쓰지 않는다
- 원본 경로·해시·시각이 `sessions/_legacy/MANIFEST.json` 에 남아 `--undo` 로 되돌릴 수 있다

---

## 8. 호스트 대장

이름과 IP 는 바뀐다. 그래서 대장은 **바뀌지 않는 하드웨어 식별자**(`machine_id`)를 1차 키로 두고,
이름·주소는 이력으로만 쌓는다. `herald-host` 가 관리한다.

```bash
herald-host observe            # 이 컴퓨터를 관측해 대장에 더한다
herald-host observe --scan     # vault env/ 의 스냅샷을 전부 반영 (다른 호스트 포함)
herald-host list
herald-host show <이름|IP|machine_id>
```

**관측은 더하기만 한다.** 이름이 바뀌면 새 이름이 `since` 와 함께 추가되고 옛 이름은 남는다 —
그래야 옛 이름으로 남은 기록도 찾힌다. **vault 설치 스크립트**
(`bootstrap/herald-vault-setup.sh`)가 5단계에서 자동으로 돌린다 — 패키지 설치용 `install.sh`
가 아니다.

### 기기를 교체했을 때

`machine_id` 자체가 달라지면 도구가 알 방법이 없다. **추정하지 않는다.**
사용자가 선언하면 그때 과거와 미래가 한 호스트로 묶인다.

```bash
herald-host alias <옛 machine_id> <새 machine_id> --since 2027-03-01 --note "기기 교체"
```

선언 뒤에는 **옛 식별자·옛 이름·옛 주소 무엇으로 물어도** 같은 호스트로 해석되고,
`herald-find --host <새 이름>` 이 교체 전 기록까지 함께 찾는다.

---

## 9. 찾기

```bash
herald-find "검색어"
herald-find --list
herald-find --project <프로젝트> --since 2026-08-01
herald-find --host <호스트> --tag 버그
herald-find --open <id>
```

로컬 clone 이 있으면 `ripgrep`(없으면 `grep`), 없으면 Forgejo API 로 찾는다.
**일반 호스트는 읽기 권한이 없어 조회되지 않는다 — 설계대로다.**

시각은 `DISPLAY_TZ`(기본 `Asia/Seoul`)로 보여 준다. 해외에서는 `--tz local` 또는
`export HERALD_TZ=<지역>` 으로 바꾼다. 정렬·저장은 언제나 UTC 다.

---

## 문제가 생기면

| 증상 | 확인 |
|---|---|
| 전송 실패 | `ssh -i <투입키> <계정>@<서버> docs` 를 직접 실행해 응답을 본다 |
| 꾸러미가 inbox 에 쌓이기만 함 | 수집기 로그·타이머 상태 |
| vault 에 반영 안 됨 | 수집 계정으로 작업 클론의 `git status` |
| 전송이 큐에 밀림 | `~/.herald/outbox/<계통>/` — 다음 `herald-send` 가 먼저 비운다 |
| `herald-sort` 가 0건 | vault 를 pull 했는가 |
| `inbox` 를 `ls` 하니 권한 거부 | **정상이다.** 로그나 API 로 확인한다 |
