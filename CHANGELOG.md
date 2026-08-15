# 변경 이력 (Changelog)

이 프로젝트의 모든 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며,
버전은 [유의적 버전(SemVer)](https://semver.org/lang/ko/) `major.minor.patch` 규칙을 사용합니다(1.0.0 이전 단계).

## [0.2.25] - 2026-08-16

### Added
- **`herald-init.sh` 가 `HERALD_LOG_DIR` 을 셸 설정에 직접 넣는다** (멱등·백업).
  `~/.profile`·`~/.bashrc`·`~/.zshrc` 세 곳을 함께 갱신한다. 우분투 기본 `~/.bashrc` 는
  맨 앞에서 `case $- in *i*) ;; *) return;; esac` 로 **비대화형 셸이면 즉시 return** 하므로
  `.bashrc` 에만 넣으면 `bash -lc` 에서 값이 비어 있다 — general-host 에서 실측으로 확인했다.

### Changed
- **`herald-send` 의 파일 목록 표시 수정.** 긴 경로를 `rel[-60:]` 로 잘라 `memory/` 접두가
  `emory/`·`mory/` 로 보였다. `ellipsize()` 로 잘린 자리에 `…` 를 붙인다.
- **문서에 2단계 실측 반영** (`RUNBOOK.md`·`HANDOVER.md`·`DECISIONS.md`)
  - 1단계(push)·2단계(general-host 참여) 완료, general-host 공개키 기록, 3단계는 사용자 직접 실행
  - 새 함정 4건: 우분투 `.bashrc` 비대화형 return · vault-server sudo 비밀번호 요구 ·
    general-host python 이중(3.8.10/3.9.13) · 하네스 Bash 차단 재발

### 미검증
- 이 판의 `herald-init.sh`·`herald-send` 는 하네스가 `bash -n`·`py_compile` 을 차단해
  **구문 검사를 하지 못했다.** 다음 세션 첫 작업으로 검사한다.

## [0.2.24] - 2026-08-16

### Changed
- **general-host 의 VPN 참여 사유를 기록.** general-host 은 내부 호스트이나 **내부시스템 가 VPN 을 거쳐 아마존 내부
  MySQL 서버에 접속하는 기능** 때문에 L2TP 클라이언트로 붙어 있다. 이 경로는 herald-vault 와
  무관하며, vault 전송은 사내망 직결(`사내 대역`)로 충분하다. VPN 구성 변경이 필요해지면
  부분 수정이 아니라 전체를 한꺼번에 손보기로 한다. (`docs/vault/DECISIONS.md`·`HANDOVER.md`)

## [0.2.23] - 2026-08-16

### Added
- **herald-vault 참여 도구 3종 신설.** 세션 기록·기억·환경을 사설 Forgejo(`vault-server`)의
  `vault/herald-vault` 로 모으는 파이프라인의 클라이언트 측이다.
  - `bin/herald-env` — 실행 환경 스냅샷을 JSON 으로 남긴다. 머신 식별자(맥 `IOPlatformUUID`,
    리눅스 `/etc/machine-id`)·작업 디렉토리·git 상태·Claude Code 판본/모델/플러그인/스킬/MCP/훅·
    `CLAUDE.md` 해시·도구 판본을 담는다. **토큰·키는 이름과 존재 여부만 남기고 값은 넣지 않는다.**
    맥(Python 3.13)·general-host(3.8) 양쪽 실행 확인, 0.29초.
  - `bin/herald-send` — **보내지 않은 것만** 골라 투입구로 올린다. 서버에 "무엇을 갖고 있나"를
    묻지 않고(물으면 그것이 읽기 통로가 된다) 로컬 대장 `~/.herald/sent-<계통>.json` 과 대조한다.
    계통을 `docs`/`env`/`raw` 로 나눠 한쪽이 고장 나도 나머지가 돌게 했다. 전송 실패분은
    `~/.herald/outbox/` 에 쌓아 다음 회차에 재전송한다. `zstd` 가 없으면 `gzip` 으로 자동 대체.
  - `bootstrap/herald-init.sh` — 호스트를 참여시킨다. 투입구 전용 키 발급(호스트 단위 회수 가능)·
    설정 작성·도구 설치·등록용 공개키 출력.
  - `bootstrap/herald-host-add.sh` — 서버(vault-server)에서 호스트를 투입구에 등록한다.
    `command="…herald-drop <host>",restrict` 형태로 넣어 **호스트 이름을 서버가 결정**하고,
    계통(`docs`/`raw`/`env`)만 클라이언트가 고르되 화이트리스트로 검증한다.
    회수는 `authorized_keys` 에서 해당 줄 삭제로 끝난다.
- **`docs/vault/` 문서 3종 신설**
  - `DECISIONS.md` — 설계 문서(바탕화면 ①②)와 달라진 실측 결과, 확정 결정과 근거, 진행 현황
  - `RUNBOOK.md` — 실행 절차(1~4단계)·기대 출력·문제 대응표
  - `HANDOVER.md` — 세션 인계용. 상태·다음 할 일·부딪힌 함정·자격증명 위치

### Changed
- **읽기 차단 방식을 저장소 분리에서 「업로드 전용 투입구」로 전환.** git 호스팅은
  쓰기 권한이 읽기 권한을 포함하므로, 저장소를 호스트별로 쪼개도 「자기 기록조차 못 읽는」
  요구를 달성할 수 없다. SSH `command=` + `restrict` 로 받기 전용 프로그램만 실행되게 하고,
  호스트 이름은 서버가 키에 박아 위조를 막는다.
- **전송을 파일 단위 증분으로 확정.** 실측 결과 세션 원문의 99.2%(507/511)가 종료 후 불변이라
  바이트 단위 델타의 이득이 0.8%에 그치고, 대신 inbox 원본을 영구 보관해야 하는 의존이 생긴다.
  「완료된 세션만 전송」 규칙과 합치면 각 파일이 평생 한 번만 전송된다.

## [0.2.22] - 2026-08-05

### Added
- **README FAQ: VM 게스트 Windows 에서 WSL 불가 시 우회로.** Parallels 등 VM 안 Windows(작업
  관리자 "가상 컴퓨터: 예")는 중첩 가상화가 꺼져 있으면 `wsl --install` 이
  `HCS_E_HYPERV_NOT_INSTALLED`, WSL1 폴백도 구성요소 Enabled·재부팅 후에도
  `WSL_E_WSL1_NOT_SUPPORTED` 로 막힌다(스토어판 WSL 2.7.x + 빌드 26200 실측). 이때는 WSL 을
  포기하고 **Claude Code 네이티브 설치**(`install.ps1` → 사용자 PATH 등록 → Git for Windows)로
  직행하는 경로를 FAQ 에 기록 — 단 herald-ai 훅(bash 전용)은 네이티브에서 미동작.
  실측: VM게스트 Parallels Win11 VM (2026-08-05).

## [0.2.21] - 2026-08-02

### Changed
- **앤솔로지 영역 부여 = 실측으로 「지원됨」 확인** (0.2.20 의 "엔진 미지원일 수 있다" 우려 해소).
  노트볼트 에서 `AR_시스템-지출원장` 을 앤솔로지 2건에 부여한 결과, Atlas 에 전용 노드
  (`Atlas/Areas/AR_시스템/AR_시스템-지출원장.md`)가 생성되고 상위 목록에 `note_count: 2` 로
  정확히 집계됐다. `link-group render` 후에도 frontmatter 의 `areas` 는 보존된다.
- **성립 조건 명시**: 앤솔로지 트리가 Atlas **콘텐츠 루트로 등록**돼 있어야 한다. 이 볼트는
  0.73.0 에서 `Dossier/Archive/Anthologies` → `Dossier/Anthologies` 승격 +
  `content_roots.atlas_source_roots` 등록으로 성립했다. 스캔 루트 밖인 볼트에서는 여전히
  백링크로만 보일 수 있으므로 **다른 볼트에서는 확인 절차를 유지**한다.
- `kb_areas.json` 에 `keywords: []` 로 등록하면 자동 배정 없이 **수동 귀속 전용**이 된다는 점을
  SKILL.md 에 명시(선례 `AR_시스템-세션로그`).

## [0.2.20] - 2026-08-01

### Added
- **볼트 안에서의 표시 규약을 `SKILL.md` §1 에 명문화.** 앤솔로지 frontmatter 에만
  `areas: [[AR_시스템-지출원장]]` + `tags: 지출원장` 을 달고, 영역은 **하나만** 두어
  여행별로 쪼개지 않는다(어느 여행인지는 앤솔로지 자신이 말한다).
  개별 영수증 노트에는 붙이지 않는다 — 다른 provenance 영역에 단독 귀속돼 있을 수 있어
  겹쳐 달면 그 규칙이 깨진다. 영역 신설 시 어휘 등록 파일에도 등록하고, 자동 배정을
  원하지 않으면 키워드는 비워 수동 귀속 전용으로 만든다.
- `registry.example.yaml` 의 `vault:` 에 `area:` 필드 추가(앤솔로지 areas 와 동일 값).

### Notes
- 볼트에 따라 앤솔로지에 영역을 다는 것이 **엔진 미지원 용법**일 수 있다. 그 경우 자동
  목록에는 안 뜨지만 위키링크이므로 **백링크로는 보인다.** 그걸로 충분한지 먼저 확인하고
  엔진 변경은 별도 건으로 분리하도록 안내를 넣었다.

## [0.2.19] - 2026-08-01

### Changed
- **`trip-ledger` L-008 에 「추정사항」 열 작성 규칙 추가.** 해당 사항이 있는 행에만 쓰고
  없으면 공란, 한 줄로 무엇이 불확실한지 바로 알 수 있게 `<무엇이 미상> · <어떻게 판단>` 형식.
  좋은 예/나쁜 예 표와, 원본 셀에 `(추정)`·`(가정)` 괄호 표기가 있으면 그 행에는 추정사항이
  반드시 있어야 한다는 누락 판정 기준을 명시. (2026-08-01 사용자 확정)

## [0.2.18] - 2026-08-01

### Added
- **`trip-ledger` 스킬 추가** — 여행·출장 지출을 볼트 노트 → 구글시트 원장 → 구글맵 목록으로
  잇는 파이프라인. 목적은 기능 자체보다 **작업 경험을 여러 Mac 이 공유**하는 데 있다.
  git 배포이므로 `git pull && bash install.sh` 만으로 다른 Mac 이 같은 노하우를 갖는다.
  - `SKILL.md` — 0단계 **실행 맥 판정**(볼트 단방향 미러 가드) + 6단계 파이프라인
  - `LESSONS.md` — ⛔재시도 금지 / ✅검증된 우회로 9건(L-001~L-009). 각 항목에 최종확인 날짜
  - `playbooks/10-notes · 20-sheets · 30-maps · 40-chrome`
  - `assets/maps-save-via-search-kp.js` — 구글맵 저장 대화상자 미렌더(L-004) 우회 스니펫(멱등)
  - `assets/sheet-columns.md` — 시트 열·폭·서식 스펙(복사용)
  - `registry.example.yaml` — 레지스트리 스키마. **실제 식별자는 공개 repo 에 두지 않는다**
- **`install.sh` 가 `trip-ledger` 를 설치**한다(문서 전용, 런타임 상태 없어 덮어쓰기 안전).

### Notes
- 볼트(`노트볼트`)는 **서버 맥 → 타 맥 단방향 미러**(`rsync --delete`)다. 리모트 맥의
  볼트 수정은 충돌이 아니라 **다음 미러 때 소실**된다. 이 판정과 인계 절차를 `SKILL.md` 에
  0단계·§5 로 명문화했다 — 종전에는 머신 로컬 메모리에만 있어 타 Mac 에 전파되지 않았다.
- 시트 ID·구글맵 컬렉션 ID 등 개인 식별자는 볼트 `Dossier/Registry/` 에 두고,
  herald-ai(공개 저장소)에는 **스키마만** 둔다.


## [0.2.17] - 2026-07-14

### Fixed
- **Windows/WSL 에서 `install.sh` 가 `: invalid option nameet: pipefail` 로 죽던 문제.**
  Windows 에서 clone(`autocrlf`) 하거나 ZIP 로 받으면 셸 스크립트가 CRLF 로 변환돼,
  bash 가 `set -euo pipefail\r` 을 잘못 해석해 실행 자체가 실패했다.

### Added
- **`.gitattributes` 추가.** `*.sh`·`*.json`·`*.md` 등을 `eol=lf` 로 강제해, 어느 OS 에서
  clone 하든 셸 스크립트가 LF 로 유지된다(Windows CRLF 오염 근본 차단).
- **`install.sh` CRLF 방어 로직.** 설치되는 `*.sh` 의 `\r` 을 `perl`(macOS·Linux 기본 탑재,
  BSD/GNU `sed -i` 비호환 회피)로 제거한다. `.gitattributes` 가 적용되지 않는 **ZIP 다운로드**
  경로에서도 런타임 훅이 깨지지 않는다.
- **README Windows/WSL 안내.** herald-ai 는 bash 전용이므로 Windows 에선 **WSL 안에서**
  Claude Code 를 실행해야 훅이 동작함을 명시. CRLF 증상·해결(WSL 홈 re-clone) FAQ 추가.

## [0.2.16] - 2026-07-13

### Fixed
- **토큰/비용 조회가 실패하던 문제 수정 (여러 Mac 공통).** `ccusage` 를 `npx` 로 실행할 때
  사용자 공용 npm 캐시(`~/.npm`)를 쓰다가, 과거 `sudo npm` 등으로 캐시가 root 소유가 된
  머신에서 `EACCES`/`EEXIST` 로 실패해 `📊 토큰 조회 실패` / `월누적 $0.0` 가 나오던 문제.
  - **격리 npm 캐시**(`skills/task-tracker/.cache/npm`, `HERALD_NPM_CACHE` 로 변경 가능)를
    사용해 손상된 `~/.npm` 과 무관하게 동작. **sudo 로 소유권을 고칠 필요 없음.**

### Added
- **이식성 타임아웃 래퍼.** macOS 는 coreutils `timeout` 이 없어, `gtimeout`→`perl`(기본 탑재)
  순으로 폴백. 콜드 다운로드/네트워크 지연/대용량 스캔에도 추적기가 무한정 멈추지 않는다.
  상한: 런타임 `HERALD_CCUSAGE_TIMEOUT`(기본 60초), setup 최초 다운로드 `HERALD_CCUSAGE_SETUP_TIMEOUT`(기본 180초).
- **조회 결과 TTL 캐시.** `ccusage` 는 매번 전체 트랜스크립트를 스캔해 기록이 많은 머신에선
  수십 초가 걸린다. 같은 인자의 결과를 `HERALD_CCUSAGE_TTL`(기본 300초) 동안 캐시해
  `start→stop`·훅의 반복 조회를 즉시 응답하고, 조회 실패/타임아웃 시 마지막 캐시값을 반환한다.
- **`CLAUDE.md` 추가.** 저장소 git 운영 규칙(버전·커밋·개발기록·푸시)의 단일 출처.
  Claude Code 가 자동 로드하며 git 으로 배포돼 어느 Mac 에서든 동일하게 적용된다.
- `setup` 의 ccusage 연결 테스트가 격리 캐시를 미리 채워(prime), 이후 첫 실행을 빠르게 한다.

### Changed
- `README.md`: 현재 버전 표기 `0.2.14 → 0.2.16` 정정(단일 출처 `VERSION` 과 불일치 해소),
  `CLAUDE.md` 링크 추가, 조회 실패/느림 FAQ 항목 보강.

## [0.2.15] - 2026-07-12

### Added
- **`/session-save` 슬래시 커맨드 추가.** 세션 작업기록 마크다운을 파일로
  생성·저장한다(기존 `/session-log` 의 저장 역할을 분리·이관).
  - 출력 위치는 환경변수 `HERALD_LOG_DIR`(기본 `~/Desktop/`)로 설정 가능.
  - 필터 인자를 주면 카테고리 태그 규칙으로 다시 추리고, 인자가 없으면 직전
    `/session-log` 의 필터 범위를 상태 파일로 인계받아 동일 범위로 저장한다.

### Changed
- **`/session-log` 커맨드를 "미리보기+인계" 역할로 재정의.** 이제 파일을 만들지
  않고 세션 작업을 **일자·시간별 차례로 화면에 표시**하며, 추린 결과를 인스턴스별
  상태 파일(`instance-resolve.sh` 기반, cwd 해시 키)로 남겨 `/session-save` 가
  그대로 이어받게 한다.
  - 자연어 필터를 표준 카테고리(`개발`·`버그`·`테스트`·`문서`·`리서치`·`git`·
    `설정`·`기타`)의 포함/제외로 환산하는 필터 규칙 도입.
  - 공개 배포용으로 개인 노트 분류 엔진 의존(센티넬·사적 명명 규정)은 계속 배제한
    탈개인화 버전 유지.
  - **크로스OS 견고화**: 상태 파일 cwd 해시 폴백 체인에 `sha256sum`·`md5sum`
    (Linux coreutils)을 추가해, `md5`(macOS 전용)만 있던 폴백을 우분투에서도
    커버(Ubuntu 20.04 실호스트 검증).
- `install.sh`·`uninstall.sh`: 커맨드 복사/제거 안내를 두 커맨드로 반영.
- **`install.sh` 의 `rsync` 의존성 제거 → `cp`(coreutils) 전환.** 최소 우분투
  서버 이미지처럼 `rsync` 미설치 환경에서도 추가 설치 없이 설치되도록 개선.
  `rsync --exclude`(개인·런타임 파일 보존) 의미는 복사 전 백업→복사→복원 방식으로
  동등하게 재현(개인 `telegram.conf`·`task_history.jsonl`·`config` 보존, 멱등성 유지).
- README: 특징 목록·설치 단계표·전용 섹션을 두 커맨드 워크플로로 갱신.

## [0.2.14] - 2026-06-21

### Added
- **`/session-log` 슬래시 커맨드 추가.** 이번 세션 작업을 일자·시간별로 정리한
  개발기록 마크다운을 생성한다(작업 디렉토리·요약을 맨 앞에). 알림·비용추적 훅과
  독립적으로 동작하는 선택 기능.
  - 출력 위치는 환경변수 `HERALD_LOG_DIR`(기본 `~/Desktop/`)로 설정 가능.
  - `install.sh` 가 `commands/` → `~/.claude/commands/` 로 복사(설치 5→6단계),
    `uninstall.sh` 가 `session-log.md` 제거.
  - 공개 배포를 위해 개인용 노트 분류 엔진 의존(센티넬·사적 명명 규정)을 제거한
    범용 버전으로 동봉.

## [0.2.13] - 2026-06-21

### Fixed
- **Ubuntu(Linux)에서 `task-tracker.sh stop` 이 통째로 실패하던 문제 수정.**
  `cmd_stop` 의 IP 라벨 탐지 블록이 macOS 전용 명령으로 시작해, `set -euo pipefail`
  환경의 Linux 에서 3단계로 연쇄 실패했다:
  - `route -n get default` → Linux net-tools 는 usage 에러로 **exit 3** → `set -e` 로 중단.
  - `local ip_addr` 미초기화 → Linux 에서 `def_if` 가 비면 **`set -u` unbound variable**.
  - `ipconfig getifaddr en0/en1` → Linux 에 없는 명령 **exit 127** → 중단.
  이제 IP 탐지 블록 동안만 `set +e +o pipefail` 후 복원하고, 변수를 빈 값으로 초기화해
  `hostname -I` 폴백으로 Linux 를 정상 커버한다. (`cmd_stop`)
- `instance-resolve.sh` 의 동일 `route` 패턴에 방어적 `|| true` 가드 추가
  (pipefail 을 켠 caller 가 source 할 경우 대비).

## [0.2.12] - 2026-06-20

### Documentation
- README **설치 섹션 대폭 확장**: 플랫폼별(macOS/Ubuntu) 사전 요구사항, 설치 5단계
  상세 표, 텔레그램 설정, **설치 검증**(DRY_RUN·훅 병합 확인), 업데이트·제거,
  **문제 해결(FAQ)** 추가.
- 스크립트 함수 주석 보강(부족한 곳): `task-tracker.sh`(`load_plan_limit`·`get_plan_name`·
  `get_token_usage`·`get_monthly_cost`·`parse_token_summary`·`json_field`·`cmd_start` 등),
  `notify.sh`(`format_elapsed`·`read_task_name`·`send_telegram`·`send_macos`).
- 코드 동작 변경 없음(주석·문서만). 로컬 스킬과 배포본 스크립트 동일성 유지.

## [0.2.11] - 2026-06-20

### Fixed
- **월누적 비용 증감률(`±N %`) 과대 표시 수정.** 기록 시작이 60일 미만일 때
  직전 30일 구간이 부분 데이터(예: 5일치)만 잡혀 분모가 과소해지고, 비정상적으로 큰
  값(예: `+1817%`)이 표시되던 문제. 이제 최근/직전 구간을 **일평균(= 30일 환산)** 으로
  맞춰 비교해 공정한 비율을 산출한다. (`get_rolling_30d`)
- 전체 데이터 기간이 **31일 이하**이면 비교할 직전 구간이 사실상 없으므로
  증감률을 `(-%)` 로 표시한다.
- 30일보다 짧은 기록도 일평균 환산을 통해 30일 기준으로 정규화하여 비교한다.

## [0.2.10] - 2026-06-20

### Added
- 최초 공개: Claude Code 작업 알림 + 토큰/비용 추적 훅 시스템.
  Telegram·데스크톱 멀티채널, 타입 분화(완료/진행/대기/오류), 다중 인스턴스 라벨,
  토큰 외부화(`telegram.conf`).

[0.2.13]: https://github.com/bkmheen/herald-ai/compare/v0.2.12...v0.2.13
[0.2.12]: https://github.com/bkmheen/herald-ai/compare/v0.2.11...v0.2.12
[0.2.11]: https://github.com/bkmheen/herald-ai/compare/v0.2.10...v0.2.11
[0.2.10]: https://github.com/bkmheen/herald-ai/releases/tag/v0.2.10
