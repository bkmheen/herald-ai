# 변경 이력 (Changelog)

이 프로젝트의 모든 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며,
버전은 [유의적 버전(SemVer)](https://semver.org/lang/ko/) `major.minor.patch` 규칙을 사용합니다(1.0.0 이전 단계).

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
