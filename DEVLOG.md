# 개발 기록 (DEVLOG)

날짜별 개발 의사결정·작업 내역을 시간순으로 남깁니다.
사용자용 변경 요약은 [CHANGELOG.md](CHANGELOG.md), 코드 변경의 배경·근거는 본 문서에 기록합니다.

---

## 2026-08-01 — trip-ledger 스킬 신설: 작업 경험의 다중 Mac 공유 (v0.2.18)

### 배경 (요구)
여행·출장 지출을 볼트 노트 + 구글시트 + 구글맵으로 정리하는 작업을 여러 Mac 에서 반복하게 됐다.
문제는 기능이 아니라 **경험의 휘발**이었다. 예: 구글맵 저장 대화상자가 안 뜨는 벽을 한 Mac 에서
4회 시도 끝에 우회로를 찾았는데, 그 지식이 그 세션에만 남아 다른 Mac 은 같은 벽을 처음부터 다시 만난다.

요구는 명확했다 — **발견한 방법을 먼저 적용하고, 변동이 있으면 새 방법을 찾아 다시 기록해서,
이전에 막혔던 방법을 두 번 시도하지 않게 한다.**

### 설계 판단 — 3층 분리

| 층 | 위치 | 담는 것 | 전파 |
|----|------|---------|------|
| 방법(노하우) | **herald-ai** (공개 git) | 절차·검증된 기법·금지된 기법 | `git pull` + `install.sh` |
| 대상(레지스트리) | **볼트** `Dossier/Registry/` | 시트 ID·맵 목록명·앤솔로지 UID | 서버 맥 → 미러 |
| 일회성 지시 | `~/Desktop` md | 리모트 맥 → 서버 맥 인계 | iCloud 데스크톱 동기화 |

방법과 대상을 가른 이유는 **herald-ai 가 공개 저장소**이기 때문이다. 시트 ID 는 링크만 알면
접근되는 값이라 공개 커밋하면 안 된다. 반대로 노하우는 공개해도 무해하고, 공개라서 clone 이 쉽다.

머신 로컬 메모리(`~/.claude/.../memory/`)에 두는 선택지는 배제했다 — 전파가 안 된다.
이번 문제의 본질이 "전파" 였으므로 저장 위치가 곧 설계의 핵심이었다.

### 놓쳤다가 사용자 지적으로 보강한 것 — 볼트 단방향 미러

초안에서 맥 판정 규칙을 "부가 규칙" 정도로 다뤘는데, 실제로는 **파이프라인의 구조적 관문**이었다.
실측으로 확인한 사실:

- 서버 맥: `~/볼트상위` = 실디렉토리(정본). 리모트 맥: 심볼릭 링크 → `~/Documents/볼트상위`(수신본).
- `노트볼트/scripts/미러스크립트.sh` 가 `--delete` 로 정본 → iCloud 사본을 rsync.
- 스크립트 자체에 "이 맥이 미러 원본이 아니면 skip" 가드가 있다 → **역방향 채널이 아예 없다.**

결론: 리모트 맥의 볼트 수정은 충돌(merge conflict)이 아니라 **다음 미러 때 조용한 소실**이다.
그래서 `SKILL.md` 0단계에 판정 절차와 **대상별 쓰기 권한 매트릭스**를 넣었다.

핵심은 비대칭이다 — 리모트 맥에서 **클라우드(시트·맵)는 전부 쓰기 가능**하고 **볼트만 읽기 전용**이다.
"리모트 맥이면 아무것도 못 한다" 가 아니라 단계별로 실행 가능 맥이 다르다. 이 구분이 없으면
할 수 있는 일까지 서버 맥으로 미루거나, 하면 안 되는 일을 리모트에서 해서 잃는다.

인계 채널이 실제로 동작하는지도 확인했다 —
`~/Library/Mobile Documents/com~apple~CloudDocs/Desktop → ~/Desktop` 심볼릭이 있어
데스크톱이 iCloud 동기화 대상이다. 즉 바탕화면 지시서는 별도 전송 없이 서버 맥에 도착한다.

### LESSONS.md 형식
항목마다 `상태(✅검증됨/⛔회피/⚠️조건부/🕒재확인필요)` · **최종확인 날짜** · 증상 · **실패한 시도** ·
✅대체경로 · 재확인 트리거를 남긴다. "실패한 시도" 를 명시적으로 적는 게 요구의 핵심 —
다음 세션이 그 경로를 건너뛰게 하는 장치다. 날짜는 외부 UI 개편에 대비한 재검증 기준선이다.

초판 9건은 전부 2026-07~08 네덜란드 지출 정리 작업에서 실제로 겪은 것이다
(첫 글자 유실 · 이름상자 무음 실패 · 합성 클립보드 붕괴 · 맵 저장 대화상자 미렌더 등).

---

## 2026-07-14 — Windows/WSL CRLF 로 install.sh 실패 수정 (v0.2.17)

### 배경 (증상)
Windows 사용자가 `bash install.sh` 실행 시 `: invalid option nameet: pipefail` 로 즉시 종료.
1차로 PowerShell 에서 시도(→ `bash` 없음), WSL 로 전환 후에도 위 에러가 재현.

### 원인 규명
- 에러 문자열 `nameet: pipefail` 이 결정적 단서. `set -euo pipefail` 줄 끝에 `\r`(CR) 이 붙어
  bash 가 `pipefail\r` 을 옵션명으로 오인. 즉 **파일이 CRLF 줄바꿈**.
- 원인: Windows 의 Git(`core.autocrlf=true`) 또는 GitHub ZIP 다운로드가 LF→CRLF 로 변환.
  `/mnt/c/...`(Windows 파일)를 WSL 이 그대로 읽으니 CR 이 남아 있었다.
- 파급: install.sh 뿐 아니라 설치되는 `skills/.../*.sh`(런타임 훅) 도 CRLF 면 알림이 깨진다.

### 해결 (3중 방어)
1. **`.gitattributes`** — `*.sh` 등을 `eol=lf` 로 강제. 어느 OS 에서 clone 해도 LF 유지(근본 차단).
   단, ZIP 다운로드에는 적용 안 됨 → 아래 2로 보완.
2. **install.sh 방어 로직** — 설치되는 `*.sh` 의 `\r` 을 제거. `sed -i` 는 BSD(macOS)/GNU 문법이
   달라, 양쪽 기본 탑재인 **`perl -i -pe 's/\r$//'`** 사용(이 저장소의 timeout 폴백과 동일 근거).
   `command -v perl` 가드로 perl 없으면 조용히 건너뜀.
3. **README/FAQ** — Windows 는 **WSL 안에서** Claude Code 실행 필수(PowerShell 네이티브는
   POSIX 훅 미실행), `/mnt/c` 말고 **WSL 홈에 clone** 권장, CRLF 증상·수정법 명시.

### 검증
- `bash -n install.sh` 구문 정상. `printf 'set -euo pipefail\r\n...'` → `perl -i -pe` 후 CR 제거 확인.

---

## 2026-07-13 — ccusage 토큰/비용 조회 견고화 + git 규칙 문서화 (v0.2.16)

### 배경 (증상)
`task-tracker.sh start` 가 `⚠️ 토큰 조회 실패`, `stop` 의 한 줄 요약이 `월누적 $0.0 (-%)`
로 나왔다. 텔레그램 연결은 정상(별도 확인)인데 토큰/비용만 비었다.

### 원인 규명
1. **root 소유 npm 캐시** — `npx --yes ccusage@latest daily …` 를 직접 실행하니
   `npm error EEXIST … EACCES: permission denied, mkdir '~/.npm/_cacache/…'`.
   `find ~/.npm ! -user $(whoami)` → **509개 파일이 root 소유**. 과거 `sudo npm` 흔적으로
   공용 캐시가 오염돼, 일반 사용자로 도는 훅/추적기의 `npx` 가 캐시를 못 써서 실패.
2. **콜드 다운로드 + 타임아웃 부재** — 깨끗한 캐시로 돌려도 `ccusage` 최초 설치가 2분+.
   `get_token_usage` 에 상한이 없어, 느리면 `start` 전체가 멈춘다(macOS 는 `timeout` 미탑재).
3. **스캔 자체가 느림** — 캐시를 데운 뒤 `--offline` 으로 재실행해도 **33초**. 즉 npm 이
   아니라 `ccusage` 가 전체 트랜스크립트(이 머신 누적 수천만 토큰)를 매번 스캔하는 게 병목.

### 해결 (여러 Mac 에서 동일 동작 목표)
- **격리 npm 캐시**: `npm_config_cache=$SKILL_DIR/.cache/npm` (env `HERALD_NPM_CACHE`).
  손상된 `~/.npm` 을 통째로 우회 → **sudo 로 소유권 복구 불필요**, 어느 Mac 이든 동일.
- **이식성 타임아웃** `run_with_timeout`: `timeout`→`gtimeout`→`perl`(macOS 기본) 폴백.
  perl 폴백은 alarm+`kill TERM` 후 timeout 시 exit 124. 상한 초과해도 추적기는 계속 진행.
- **결과 TTL 캐시** `run_ccusage`: 인자별 캐시키(`$*` → 영숫자화)로 결과를 `HERALD_CCUSAGE_TTL`
  (기본 300초) 동안 재사용. `start`(오늘) / `stop`·훅(월초·59일) 인자가 다르므로 키가 갈리며,
  같은 인자 반복은 즉시 응답. 조회 실패/타임아웃 시 **만료된 캐시라도 반환**(0 대신 마지막값).
  `file_mtime` 는 `stat -f %m`(BSD)·`stat -c %Y`(GNU) 양쪽 대응.
- `setup` 연결 테스트가 격리 캐시를 prime 하고, 실패 시 격리 캐시 우회를 안내.

### 검증
- 1차 `start`(캐시 미스): 45초, `Input/Output/Total/Cost` 정상 출력.
- 2차 `start`(같은 인자, 캐시 히트): **0초**, 동일 값.
- `stop`: `월누적 $금액` (기존 `$0.0` → 정상). 59일 인자는 첫 호출이라 스캔(캐시 미스) 후 캐시.
- `bash -n` 문법 검사 통과. 편집한 repo 원본을 설치본(`~/.claude/...`)에 동기화.

### 병행 결정 — git 규칙 단일 출처
저장소·프로젝트 메모리 어디에도 명문화된 git 규칙이 없었다. 사용자가 규칙(버전 bump·커밋·
개발기록·푸시)을 확정해, **다른 Mac 설치 시에도 동일 적용되도록 저장소에 커밋**해야 함을 근거로
`CLAUDE.md`(Claude Code 자동 로드 + git 전파)를 단일 출처로 채택. 프로젝트 메모리는 머신 로컬
경로라 전파되지 않으므로 규칙 본문을 두지 않고 포인터만 둔다. 이번 작업은 직전(v0.2.15,
session-log)과 다른 주제 → 규칙에 따라 minor 증가(0.2.16).

## 2026-07-12 — `/session-log`·`/session-save` 2-커맨드 분리 이식 (v0.2.15)

### 배경
개인 환경의 `/session-log` 이 v0.2.14 동봉 이후 진화해 **미리보기(`/session-log`)와
파일저장(`/session-save`) 두 커맨드로 분리**됐다. `/session-log` 은 화면에 차례만
표시하고 필터 결과를 상태 파일로 남기며, `/session-save` 가 그 범위를 인계받아
저장한다. 공개 패키지에는 여전히 구버전 단일 커맨드(저장형)만 있어, 다른 머신·
디렉토리에서도 현재 워크플로를 쓰도록 이식하기로 결정.

### 적절성 판단
개인용 `/session-save` 원본은 사적 노트 분류 엔진에 다시 결합돼 있었다:
- `<!-- NOTE_KIND: session-log -->` 센티넬 → 사적 분류 엔진 귀속.
- "Atelier 제목 표준"·"노트가공도구·노트볼트 규정" 등 사적 명명 규정 참조.
- 출력 경로 `~/Desktop/` 하드코딩.

→ 메모리 지침(session-log 공개/개인 구분)에 따라 공개본은 **탈개인화 범용**을
유지해야 한다. 그래서 센티넬·사적 명명 규정을 제거하고 출력 위치를
`HERALD_LOG_DIR`(기본 `~/Desktop`)로 일반화한 버전으로 동봉.

### 조치
- `commands/session-log.md`: 구버전 저장형 → **미리보기+상태 인계**형으로 교체.
  카테고리 필터·상태 파일(cwd 해시 키, `instance-resolve.sh`) 도입. 저장 로직 제거.
- `commands/session-save.md` 신규: 저장 역할 이관. 센티넬·사적 명명 규정 제거,
  출력 위치 `HERALD_LOG_DIR` 일반화, `/session-log` 상태 파일 인계 우선순위 구현.
- 두 커맨드 모두 herald-ai 의 `task-tracker` 스킬(`instance-resolve.sh`)에만 의존 —
  개인 엔진 무의존.
- `install.sh`/`uninstall.sh`: 안내·제거 로직을 두 커맨드로 반영(rsync 는 이미
  `commands/` 전체 복사이므로 신규 파일 자동 포함, 제거는 루프로 둘 다 삭제).
- README: 특징 목록·설치 단계표·전용 섹션을 2-커맨드 워크플로로 갱신.
  VERSION/CHANGELOG 0.2.15 반영.
- 원본 개인용 버전은 사용자 로컬 `~/.claude/commands/` 에 그대로 유지(공개본과 별개).

### 우분투 설치 호환성 점검·보강
"다른 시스템(우분투)에서 설치되냐"는 확인 요청에 따라 Ubuntu 20.04 실호스트
(<general-host>)에서 읽기 전용으로 명령 가용성을 점검하고 두 지점을 보강했다.
- **상태 파일 해시 폴백 크로스OS 보강**: 커맨드 내 cwd 해시 체인이
  `shasum → md5 → default` 로, `md5` 는 macOS 전용이라 shasum 없는 최소 Linux 에서
  폴백이 무의미했다. `sha256sum`·`md5sum`(Linux coreutils)을 사이에 끼워
  `shasum → sha256sum → md5sum → md5 → default` 로 확장(실호스트에서 12자리
  해시 산출 검증).
- **`install.sh` rsync → cp 전환**: 복사에 `rsync` 를 쓰는데 의존성 점검·README apt
  줄에 없어, rsync 미포함 최소 서버 이미지에서 설치가 복사 단계에서 실패할 수
  있었다. coreutils `cp` 로 바꿔 의존성 자체를 제거. `rsync --exclude`(개인 파일
  보존) 는 "복사 전 개인 파일 백업 → 트리 복사 → 복원, 원래 없던 repo 샘플은 삭제"
  로 동등 재현. 임시 CLAUDE_CONFIG_DIR 신규설치·멱등 재설치·개인 파일(task_history)
  보존·telegram-notify 중첩 방지를 로컬에서 검증.

---

## 2026-06-21 — `/session-log` 커맨드 동봉 (v0.2.14)

### 배경
개인 환경에만 있던 `/session-log` 슬래시 커맨드(세션 작업기록 MD 생성)를 herald-ai
설치만으로 함께 쓸 수 있는지 검토. 실체는 코드·의존성 없는 **프롬프트 1개 파일**
(`~/.claude/commands/session-log.md`)이라 동봉 자체는 사소하다.

### 적절성 판단
원본은 개인용 노트 분류 엔진에 강하게 결합돼 있었다:
- `<!-- NOTE_KIND: session-log -->` 센티넬 → 사적 분류 엔진이 노트를 특정 영역에 귀속.
- "제목 표준"·"note-compiler 규정" 등 공개 사용자가 갖지 않은 사적 명명 규정 참조.
- 출력 경로 `~/Desktop/` 하드코딩.

→ 그대로 공개하면 공개 사용자에게 무의미한 주석·혼란을 주고, herald-ai 의 초점
(알림+비용추적)도 흐려진다. 그래서 **탈개인화한 범용 버전**으로 동봉하기로 결정.

### 조치
- `commands/session-log.md` 신규: 센티넬·사적 명명 규정 제거, 출력 위치를
  `HERALD_LOG_DIR`(기본 `~/Desktop`)로 설정 가능하게 일반화.
- `install.sh`: `commands/` → `~/.claude/commands/` 복사 단계 추가(5→6단계), 완료
  안내에 `/session-log` 한 줄 추가.
- `uninstall.sh`: `session-log.md` 제거 로직 추가.
- README: 특징 목록·설치 단계표·전용 섹션 추가. VERSION/CHANGELOG 0.2.14 반영.
- 원본 개인용 버전은 사용자 로컬에 그대로 유지(공개본과 별개).

---

## 2026-06-21 — Ubuntu `stop` 연쇄 실패 수정 (v0.2.13)

### 배경
"응답 종료 시 텔레그램 전송 기능" 정상 설치 여부를 확인하던 중, 검증 절차로 돌린
`task-tracker.sh stop` 이 Ubuntu(Linux 5.15)에서 **exit 3** 으로 실패하는 것을 발견.
텔레그램 알림(`notify.sh`) 경로는 정상이며, 본 결함은 `task-tracker.sh` 의 `stop`
(작업 요약 기록)에 국한된다.

### 문제 (macOS 전제 코드 × `set -euo pipefail`)
`cmd_stop` 의 IP 라벨 탐지 블록이 macOS 전용 명령으로 시작하는데, 그 뒤에 Linux 폴백
(`hostname -I`)이 있어도 앞단이 죽어 도달하지 못했다. 한 결함을 고치면 다음이 드러나는
**3단계 연쇄 실패**였다(각각 `bash -x` 로 확인):
1. `route -n get default` — Linux net-tools `route` 는 usage 에러 → **exit 3**,
   `pipefail`+`set -e` 로 stop 전체 중단.
2. `local ip_addr` 미초기화 — Linux 는 `def_if` 가 비어 `ip_addr` 가 한 번도 대입되지
   않음 → `[[ -z "$ip_addr" ]]` 에서 **`set -u` unbound variable (exit 1)**.
3. `ipconfig getifaddr en0/en1` — Linux 에 없는 명령 → **command not found (exit 127)**.
   (`2>/dev/null` 은 메시지만 숨기고 종료 코드는 전파)
   → macOS 에서는 `def_if`/`ipconfig` 가 채워져 1·2·3 모두 가려져 있었다.

### 해결
- 한 줄씩 `|| true` 를 흩뿌리지 않고, 동일 뿌리(플랫폼 전용 명령 × set -e)이므로
  **IP 탐지 블록 동안만** `set +e +o pipefail` 후 `set -e -o pipefail` 로 복원.
- `local ip_addr="" def_if="" ip_oct=""` 로 초기화하여 `set -u` 차단.
- `instance-resolve.sh` 의 동일 `route` 라인은 `source` 되는 파일 특성상 set 옵션을
  건드리지 않고 `|| true` 방어 가드만 추가(현재 호출 경로는 미발현, 잠재 위험 대비).

### 검증
| 항목 | 결과 |
|------|------|
| `stop` 종료 코드 | exit 3 → **exit 0** |
| 한 줄 요약 출력 | `[herald-ai@42·…] ✅ … | ⏱️ … | 월누적 $… (-%)` 정상 |
| IP 라벨 | `hostname -I` 폴백으로 `@42` 정상(텔레그램 라벨과 일치) |
| `bash -n` | 통과 |

### 원칙
- `set -euo pipefail` + 플랫폼 종속 명령은 위험 조합. 폴백 체인을 둬도 앞단이 죽으면
  도달 못 함 → 명시적 가드(`|| true`)나 국소 옵션 해제(`set +e`)로 감싼다.
- `set -u` 환경의 `local` 변수는 반드시 초기값과 함께 선언.

### 영향 파일
- `skills/task-tracker/scripts/task-tracker.sh`,
  `skills/task-tracker/scripts/instance-resolve.sh`, `VERSION`, `CHANGELOG.md`,
  `README.md`(버전 표기).
- 로컬 스킬(`~/.claude/skills/task-tracker`)과 배포본 `cp` 동기화, `diff` 무차이 확인.

---

## 2026-06-20 — 설치 설명서 확장 및 함수 주석 보강 (v0.2.12)

### 작업
- 사용자 요청: "설치 설명서 및 주석 등을 모두 추가하라". 범위 확인 결과
  ① README 설치 섹션 확장(별도 INSTALL.md 미생성), ② 부족한 함수 주석만 보강.
- README: 사전 요구사항(macOS/Ubuntu)·설치 5단계 표·검증·업데이트/제거·FAQ 추가.
- 스크립트: 헤더 docblock 은 이미 충분 → 주석 누락 함수에만 한 줄 역할 주석 추가.
  `notify.sh` 4함수, `task-tracker.sh` 헬퍼 7함수.

### 원칙
- 동작(로직) 변경 0 — 주석/문서만. `bash -n` 통과.
- 로컬 스킬(`~/.claude/skills/task-tracker`)과 배포본 스크립트를 `cp` 로 동기화,
  `diff` 무차이 확인(재설치 시에도 동일 보장).

### 영향 파일
- `README.md`, `skills/task-tracker/scripts/task-tracker.sh`,
  `skills/task-tracker/scripts/notify.sh`, `VERSION`, `CHANGELOG.md`.

---

## 2026-06-20 — 비용 증감률 계산 정규화 (v0.2.11)

### 배경
알림 한 줄 요약의 `월누적 $X (±N %)` 에서 증감률이 `+1817%` 처럼 비현실적으로 크게
표시되는 현상 발견. 원인 추적 결과, 토큰/비용 데이터(`ccusage`)의 기록 시작이
약 35일 전(2026-05-17)이라 "직전 30일" 구간에 실제로는 5일치만 존재했다.

### 문제 (기존 `get_rolling_30d`)
- `last30` = 최근 30일 **합계**, `prev30` = 직전 구간 **합계** 를 직접 비교:
  `pct = (last30 - prev30) / prev30 * 100`.
- 직전 구간이 5일치면 `prev30` 이 30일치 대비 과소 → 분모가 작아 비율 폭증.

### 해결
- 양 구간을 **일평균**(`합계 / 실제 기록일수`)으로 환산해 비교한다.
  일평균 × 30 으로 30일 기준 환산해도 비율은 동일하므로 일평균끼리 비교한다.
- `span_days`(가장 오래된 기록 ~ 오늘) ≤ 31 이면 비교 대상이 없으므로 `(-%)` 표시.
- 한쪽 구간이 비거나 직전 일평균이 0 이하이면 `(-%)`.

### 검증
| 케이스 | 결과 |
|--------|------|
| 실제 데이터(35일, 직전 5일) | +1817% → **+242%** |
| 직전 10일·일평균 동일 | (기존 +200%) → **+0%** |
| 가상 60일·최근 일평균 2배 | **+100%** |
| 총 31일 / 10일 | **(-%)** |
| ccusage 빈 응답 | **(-%)** 폴백 |

`bash -n` 문법 검사 통과. 로컬 스킬(`~/.claude/skills/task-tracker`)과 배포본(`herald-ai`)
양쪽에 동일 반영, 두 `get_rolling_30d` 함수 diff 일치 확인.

### 영향 파일
- `skills/task-tracker/scripts/task-tracker.sh` — `get_rolling_30d`, 표시부(`chg_str`), 주석.
