# 변경 이력 (Changelog)

이 프로젝트의 모든 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며,
버전은 [유의적 버전(SemVer)](https://semver.org/lang/ko/) `major.minor.patch` 규칙을 사용합니다(1.0.0 이전 단계).

## [0.4.1] - 2026-07-14

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

## [0.4.0] - 2026-07-13

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
- `README.md`: 현재 버전 표기 `0.2.0 → 0.4.0` 정정(단일 출처 `VERSION` 과 불일치 해소),
  `CLAUDE.md` 링크 추가, 조회 실패/느림 FAQ 항목 보강.

## [0.3.0] - 2026-07-12

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

## [0.2.0] - 2026-06-21

### Added
- **`/session-log` 슬래시 커맨드 추가.** 이번 세션 작업을 일자·시간별로 정리한
  개발기록 마크다운을 생성한다(작업 디렉토리·요약을 맨 앞에). 알림·비용추적 훅과
  독립적으로 동작하는 선택 기능.
  - 출력 위치는 환경변수 `HERALD_LOG_DIR`(기본 `~/Desktop/`)로 설정 가능.
  - `install.sh` 가 `commands/` → `~/.claude/commands/` 로 복사(설치 5→6단계),
    `uninstall.sh` 가 `session-log.md` 제거.
  - 공개 배포를 위해 개인용 노트 분류 엔진 의존(센티넬·사적 명명 규정)을 제거한
    범용 버전으로 동봉.

## [0.1.3] - 2026-06-21

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

## [0.1.2] - 2026-06-20

### Documentation
- README **설치 섹션 대폭 확장**: 플랫폼별(macOS/Ubuntu) 사전 요구사항, 설치 5단계
  상세 표, 텔레그램 설정, **설치 검증**(DRY_RUN·훅 병합 확인), 업데이트·제거,
  **문제 해결(FAQ)** 추가.
- 스크립트 함수 주석 보강(부족한 곳): `task-tracker.sh`(`load_plan_limit`·`get_plan_name`·
  `get_token_usage`·`get_monthly_cost`·`parse_token_summary`·`json_field`·`cmd_start` 등),
  `notify.sh`(`format_elapsed`·`read_task_name`·`send_telegram`·`send_macos`).
- 코드 동작 변경 없음(주석·문서만). 로컬 스킬과 배포본 스크립트 동일성 유지.

## [0.1.1] - 2026-06-20

### Fixed
- **월누적 비용 증감률(`±N %`) 과대 표시 수정.** 기록 시작이 60일 미만일 때
  직전 30일 구간이 부분 데이터(예: 5일치)만 잡혀 분모가 과소해지고, 비정상적으로 큰
  값(예: `+1817%`)이 표시되던 문제. 이제 최근/직전 구간을 **일평균(= 30일 환산)** 으로
  맞춰 비교해 공정한 비율을 산출한다. (`get_rolling_30d`)
- 전체 데이터 기간이 **31일 이하**이면 비교할 직전 구간이 사실상 없으므로
  증감률을 `(-%)` 로 표시한다.
- 30일보다 짧은 기록도 일평균 환산을 통해 30일 기준으로 정규화하여 비교한다.

## [0.1.0] - 2026-06-20

### Added
- 최초 공개: Claude Code 작업 알림 + 토큰/비용 추적 훅 시스템.
  Telegram·데스크톱 멀티채널, 타입 분화(완료/진행/대기/오류), 다중 인스턴스 라벨,
  토큰 외부화(`telegram.conf`).

[0.1.3]: https://github.com/bkmheen/herald-ai/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bkmheen/herald-ai/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bkmheen/herald-ai/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/bkmheen/herald-ai/releases/tag/v0.1.0
