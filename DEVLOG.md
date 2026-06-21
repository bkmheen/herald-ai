# 개발 기록 (DEVLOG)

날짜별 개발 의사결정·작업 내역을 시간순으로 남깁니다.
사용자용 변경 요약은 [CHANGELOG.md](CHANGELOG.md), 코드 변경의 배경·근거는 본 문서에 기록합니다.

---

## 2026-06-21 — Ubuntu `stop` 연쇄 실패 수정 (v0.1.3)

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
| 한 줄 요약 출력 | `[herald-ai@201·…] ✅ … | ⏱️ … | 월누적 $… (-%)` 정상 |
| IP 라벨 | `hostname -I` 폴백으로 `@201` 정상(텔레그램 라벨과 일치) |
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

## 2026-06-20 — 설치 설명서 확장 및 함수 주석 보강 (v0.1.2)

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

## 2026-06-20 — 비용 증감률 계산 정규화 (v0.1.1)

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
