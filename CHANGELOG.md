# 변경 이력 (Changelog)

이 프로젝트의 모든 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 를 따르며,
버전은 [유의적 버전(SemVer)](https://semver.org/lang/ko/) `major.minor.patch` 규칙을 사용합니다(1.0.0 이전 단계).

## [0.2.39] - 2026-08-16

### Added
- **`CLAUDE.md` 에 「도구는 공개, 구성은 비공개」 원칙을 명문화.** 문서를 쓰기 전에
  **성격을 먼저 판정**하도록 했다 — 패키지를 쓰는 법이면 여기, 내 서버 주소·호스트 이름·
  구축 이력이면 vault. 예시는 자리표시자, 실제 값은 설정 항목으로 안내한다.
  **스크립트에 내 환경 값을 기본값으로 박지 않는다.**
- **커밋 트레일러 방침 확정** — 이 공개 저장소는 `Co-Authored-By` 한 줄만 둔다.
  규약 v2.0.0 §3.3 의 `Worked-On`·`Committed-To` 는 호스트 이름과 IP 를 커밋에 남기므로
  비공개 저장소에만 적용한다.
- `DEVLOG.md` 에 이번 정리의 배경·실태·조치·교훈 기록.

### 마무리
- 1차 치환이 놓친 **대역 표기**(`사설대역`)를 2차 패스로 제거. 전 이력 재검사 결과
  **파일 내용·커밋 메시지 모두 검출 없음.**

## [0.2.38] - 2026-08-16

**herald-ai 는 배포되는 패키지다.** 서버 주소·호스트 이름·개인 경로는 그 패키지를 쓰는 사람의
설정이지 패키지의 내용이 아니다. 그런데 구축 과정에서 내 환경의 값이 그대로 공개돼 있었다 —
IP 18곳, 개인 계정·경로 19곳, 호스트 이름 142곳. 걷어낸다.

### Changed
- **구축 기록을 vault 로 이관.** `docs/vault/{HANDOVER,DECISIONS}.md` 는 패키지 설명서가 아니라
  "내가 어떻게 깔았는가" 의 기록이라 **애초에 공개 저장소에 있을 물건이 아니었다.**
- **`docs/vault/RUNBOOK.md` → `docs/VAULT-SETUP.md` 로 일반화.** 특정 주소를 적지 않고
  "서버 주소를 `DROP_HOST` 에 넣으십시오" 형태로만 안내한다.
- **`docs/vault/SESSION-RECORD.md` → `docs/SESSION-RECORD.md`**, 예시를 일반 이름으로.
- **`herald-init.sh` 의 서버 주소 기본값 제거.** 남의 주소가 기본값이면 처음 쓰는 사람이
  엉뚱한 곳으로 붙는다. 설정에 있으면 제안하고, 없으면 반드시 입력받는다.
- **`herald-vault-setup.sh` 의 개인 경로 후보 제거** — `--legacy-root` 로 받는다.
- 스크립트·커맨드·README 의 예시에서 실제 호스트 이름·경로·금액 제거.

### Added
- **`docs/DESIGN.md`** — 왜 이런 구조인가(투입구·증분·계통 분리·정체성·색인 파생)만 남긴 설계 문서.
- **`config/vault.conf.example`** — 값을 비운 설정 표본. `config/telegram.conf.example` 로
  자격증명을 다루던 **이미 검증된 관례**를 그대로 확장한 것이다.

### Removed
- **공개 이력에서 내부 구성 정보 제거.** 현재 파일뿐 아니라 **과거 커밋의 파일 내용과
  커밋 메시지까지** 치환하고, `docs/vault/` 는 전 이력에서 들어냈다.
  아직 clone 한 사람이 없어 지금이 마지막 기회였다 (사용자 판단).
  재작성 전 번들 백업을 남겼다.

## [0.2.37] - 2026-08-16

> **묶음 01 — 버전 체계 개정** (slug: `convention`)

### Changed
- **버전 체계를 규약 v2.0.0 으로 개정한다** (사용자 지시). vault `conventions/git/v2.0.0.md` §4.1 이
  2026-08-15 자로 정한 체계를 herald-ai 에도 적용한다. 지금까지 herald-ai 는 옛 체계
  (`patch` 를 단순 증가)를 쓰고 있었다.

  ```
  patch = 묶음 × 100 + 커밋          예)  0.9.203  =  묶음 02 · 커밋 03
          └ 01~99 ┘   └ 00~99 ┘
  ```

  - 백의 자리 = **묶음**(patch) — Claude 판단, 작업 주제가 바뀔 때
  - 끝 두 자리 = **커밋**(subpatch) — 커밋마다 +1
  - 묶음 첫 커밋은 `x00` · 커밋 99 도달 시 묶음 강제 전환 · 묶음 99 도달 시 minor 승격 요청
  - `minor` 는 **사용자 허락**, `major` 는 사용자 지시

- **시작점을 `0.2.37` 으로 잡는다** — 직전 `0.2.36` 에서 minor 를 하나 올리고 묶음 01·커밋 00 으로 연다.
- **커밋 제목에 slug 를 넣는다** — `v<버전> [<slug>] <한국어 요약>`.
- `CLAUDE.md` 의 버전 절을 위 체계로 다시 썼다. `DEVLOG.md` 상단에 "현재 묶음" 줄을 신설했다.

## [0.2.36] - 2026-08-16

### Fixed
- **`install.sh` 의 설치 목록에 `__pycache__` 가 끼어들었다.** 공용 모듈(`herald_tz.py`)이
  생기면서 파이썬이 `bin/__pycache__/` 를 만드는데, 안내 문구가 `ls bin/` 을 그대로 찍고 있었다.
  실제로 설치한 것만 세도록 고쳤다 (디렉토리·`.pyc` 는 애초에 설치되지 않았다).
- **모듈은 실행 권한 없이 설치한다.** `herald_tz.py` 는 실행 파일이 아니라 `import` 대상이므로
  `644` 로 둔다. 실행 도구만 `755` 다.

## [0.2.35] - 2026-08-16

### Added
- **시각을 한국시간으로 보여 준다.** 타임라인이 UTC 라 08-16 06:22 KST 세션이 `2026-08-15T21:22Z`
  로 표시돼, 파일명(`260816`)과 어긋나 보였다. **정렬·저장은 UTC 그대로 두고 표시만 바꾼다.**
- **`bin/herald_tz.py` 신설** — `herald-index`·`herald-find` 가 함께 쓰는 표시 시간대 helper.
  결정 순서: `--tz` → `HERALD_TZ` → `vault.conf` 의 `DISPLAY_TZ` → `Asia/Seoul`.
- **해외 체류 대응.** `--tz Asia/Tokyo`·`--tz Europe/Paris` 로 그 지역 시각으로 보고,
  `--tz local` 은 그 컴퓨터의 시스템 시간대를 따른다(노트북을 들고 이동하면 그대로 따라간다).
  `export HERALD_TZ=…` 한 줄이면 이후 모든 명령에 적용된다.
  `herald-vault-setup.sh --tz …` 로 `INDEX.md` 자체를 다른 시각으로 다시 만들 수도 있다.
- `index.json` 에 **`display_tz`** 를 남긴다 — `INDEX.md` 가 어느 시각으로 쓰였는지 알린다.
  **기계용 값은 언제나 `started_utc`(UTC)** 이므로 소비자의 해석은 달라지지 않는다.
- `herald-init.sh` 가 `vault.conf` 에 `DISPLAY_TZ=Asia/Seoul` 을 넣는다.

### Fixed
- **시각을 모르는 기록은 날짜만 보여 준다.** 옛 파일명에서 날짜만 건진 기록은 `00:00 UTC` 로
  채워 두었을 뿐인데, 시간대를 옮기니 **없는 시각(`09:00`)이 생겼다.** `time_known: false` 로
  표시하고 변환 없이 날짜만 낸다 — 지어내지 않는다. (해외 시간대에서는 날짜가 하루 밀리기도 했다)
- 알 수 없는 지역 이름을 주면 **UTC 로 물러난다.** 조용히 엉뚱한 시각을 보여 주지 않는다.

## [0.2.34] - 2026-08-16

v0.2.33 로 색인을 다시 만들어 보니 **가공본 형식이 하나가 아니었다.** 26건 중 9건의 요약이
여전히 파일명으로 떨어졌고, 한 건은 날짜가 2026-08-07 대신 2026-08-14 로 잡혔다.

### Fixed
- **파일명과 같은 요약 후보는 건너뛴다.** 가공본이 `title`·`source_name` 에 **파일명을 그대로**
  옮겨 둔 경우가 많아, 그 값을 먼저 쓰면 요약이 파일명으로 되돌아갔다.
  이제 `source_name` → 본문 첫 `# ` 제목 → `title` 순으로 보되 **파일명 같은 값은 넘긴다.**
- **세션 날짜를 `created`·`compiled_at` 보다 파일명에서 먼저 찾는다.** 그 두 값은
  **노트를 만든 시각**이라 세션 날짜와 다르다. 실제로 `260807-금 [pp]` 기록이
  `2026-08-14T10:39Z` 로 잡혔다. 우선순위: `event_date` → `date` → 파일명 → `created` → `compiled_at`.
- 형식 ②(`type: log`)의 `date` 열쇠를 읽는다.

## [0.2.33] - 2026-08-16

과거 기록 26개를 이관해 본 결과 색인 품질 문제 세 가지가 드러났다.
**옛 기록에 이미 적혀 있는 사실을 읽지 못하고 버리던 것**을 고친다.

### Fixed
- **Atelier·Dossier 가공본의 프론트매터를 읽는다.** 그 파일들은 `source_name`·`event_date`·
  `tags` 를 이미 갖고 있는데, 우리 `schema:` 가 없다는 이유로 전부 버리고 파일명만 썼다.
  결과적으로 요약이 파일명으로, 날짜가 파일명의 날짜로 떨어졌다.
  이제 **있는 것을 읽는다** — 요약은 `source_name`, 날짜는 `event_date`, 태그는 `tags`.
  `herald-find --tag Flutter` 처럼 옛 기록의 태그로도 찾을 수 있다. (지어내는 것이 아니라
  적힌 것을 옮기므로 `inferred: true` 표시는 유지한다. 출처는 `foreign_schema` 로 남긴다)
- **프론트매터 블록 목록(`tags:` 아래 `- 항목`)을 해석한다.** 한 줄 값만 읽던 파서가
  가공본의 목록을 통째로 놓쳤다.
- **파일명 파서를 느슨하게 했다.** 대괄호 뒤에 `-HHMM` 이 없거나(`… [pension-jsf·개발·버그] 세션 작업기록`)
  그 뒤에 다른 말이 붙는 경우(`…-0855 improve 미완 노트 처리계획 …`)를 놓쳐 프로젝트가 `-` 로 비었다.
  규약이 느슨했으므로 파서도 느슨하게 둔다 — 대괄호 안만 확실히 건진다.
- **`first_heading` 이 프론트매터를 건너뛴다.** 가공본은 앞머리 20여 줄이 전부 메타데이터라
  제목에 닿지 못하고 파일명으로 되돌아갔다.

### Changed
- **설치 스크립트의 중복 출력 제거.** 묻지 않게 된 뒤로 모의 실행과 실제 실행이 같은 목록을
  두 번 찍었다. 확인을 받지 않으면 미리보기에 결정 가치가 없으므로 실제 실행만 한다
  (`--ask` 일 때는 종전대로 미리 보여 준다).

## [0.2.32] - 2026-08-16

### Fixed
- **`sessions/INDEX.md` 의 머리말이 실제 동작과 어긋났다.** 옛 파일의 머리말을 보존하다 보니
  "저장할 때마다 **맨 끝에 한 줄씩 덧붙인다**" 는 설명이 남아, append 방식인 것처럼 읽혔다.
  실제로는 `herald-index` 가 **매번 전부 새로 만든다.** 이 파일은 전부 생성물이므로
  **머리말도 매번 다시 쓴다.** 고칠 것은 이 파일이 아니라 원본 기록의 프론트매터다.

## [0.2.31] - 2026-08-16

### Changed
- **설치 스크립트가 더 이상 묻지 않는다** (사용자 지시). 확인 프롬프트 없이 끝까지 진행한다.
  자동으로 하는 것은 **전부 되돌릴 수 있는 동작**뿐이다 — `herald-sort` 는 덮어쓰지 않고
  꾸러미를 `_done` 으로 보존하며, 커밋은 git 이력에 남는다. **파일을 원래 자리에서 없애는
  유일한 동작**인 레거시 이관만은 여전히 `--apply-legacy` 를 명시해야 실행된다.
  단계마다 확인을 받고 싶으면 `--ask` 를 준다.
- **`herald-index` 출력이 vault 상태를 제대로 보인다.** 색인 대상은 `sessions/` 뿐이라
  기억·환경만 들어온 상태에서 「기록 0개」로 나와 vault 가 빈 것처럼 보였다.
  이제 `세션기록 N개` 와 함께 `기억 N개`·`환경 N개 (색인 대상 아님)` 를 표시한다.

### Added
- **설치 스크립트 9단계 — vault 커밋·push.** 정리·색인 결과가 로컬에만 남으면 다른
  컴퓨터에서 찾을 수 없다. 거기까지가 한 벌이므로 자동으로 올린다 (`--no-vault-commit` 로 생략).

## [0.2.30] - 2026-08-16

첫 실행(맥, 2026-08-16 08:50경)에서 드러난 결함 두 가지를 고친다.

### Fixed
- **설치 스크립트가 vault 를 당기지 않았다.** 수집기가 서버에 올려 둔 회수분이 로컬 클론에
  없어 `herald-sort` 가 `꾸러미 0개`, `herald-index` 가 `기록 0개` 를 보고했다
  (Forgejo 에는 `_inbox/general-host` 항목 73개가 있었다). **4단계로 `git pull --ff-only` 를 넣고**
  실패하면 "서버의 회수분이 빠진 채로 정리·색인된다"고 경고한다.
- **`herald-legacy-import` 의 집계가 오해를 낳았다.** 여러 경로에 있는 **같은 내용의 사본**을
  `이미 이관됨` 으로 세어, MANIFEST 가 비어 있는데도 "이미 이관됨 33개" 로 보였다.
  `이미 이관됨`(MANIFEST 에 있음)과 `같은 내용 사본`(이번 실행 안 중복)을 나눠 센다.
- **모의 실행의 목적지가 실제와 달랐다.** 같은 이름의 파일이 여럿이면 실제로는 ` (2)`·` (3)` 이
  붙는데 모의 실행은 전부 같은 목적지로 보여 줬다. **목적지를 계획 단계에서 배정**해
  모의 실행이 실제 결과와 일치하게 했다.

## [0.2.29] - 2026-08-16

### Added
- **`bootstrap/herald-vault-setup.sh`** — v0.2.28 파이프라인을 관리 호스트에 **한 번에** 올린다.
  실행 권한 부여·커밋·push → `install.sh` → 셸 PATH 등록 → `herald-sort` → `herald-index`
  → `herald-find` 확인 → 레거시 이관(모의)까지 순서대로 수행하고 마지막에 요약한다.
  - 되돌리기 어려운 단계(이동·커밋·push)는 **묻고 나서** 한다. `--yes` 로 생략, 비대화형이면 자동 보류
  - 레거시 이관은 `--apply-legacy` 를 명시해야 실제로 옮긴다
  - `--legacy-root` 를 주지 않으면 **실재하는 경로만** 후보로 삼는다 (없는 경로를 지어내지 않는다)

### Fixed
- 셸 호환 함정 두 가지를 처음부터 피해 작성했다.
  - **배열을 쓰지 않는다** — macOS 기본 bash 3.2 는 `set -u` 에서 빈 배열을 펼치면
    `unbound variable` 로 죽는다. 줄바꿈 구분 문자열 + 위치인자로 처리한다
  - **`[ … ] && cmd` 를 문장 단위로 쓰지 않는다** — 조건이 거짓이면 AND 목록 전체가 실패로 끝나
    `set -e` 가 스크립트를 조용히 죽인다. `if … then … fi` 로 바꿨다

## [0.2.28] - 2026-08-16

세션기록을 **바탕화면이 아니라 herald-vault 로** 모은다. 무엇을 찾든 vault 를 가장 먼저 뒤지면 나온다.

### Added
- **스키마 `herald.session-record/1.0.0` 신설.** 세션기록 MD 맨 앞에 YAML 프론트매터를 붙여
  `schema`·`host`·`project`·`started`·`tags`·`versions`·`commits`·`summary` 를 기계 판독 가능하게 남긴다.
  **각 파일이 `schema:` 로 자기 판본을 밝히므로**, Atelier·Dossier 가 어느 규약으로 쓰인 기록인지
  항상 알 수 있다. 판본이 올라가도 **옛 기록은 고치지 않고** 읽는 쪽이 분기한다.
- **`bin/herald-index`** — `sessions/**/*.md` 를 훑어 `sessions/INDEX.md`(사람용 타임라인)와
  `sessions/index.json`(기계용 색인, 스키마 `herald.session-index/1.0.0`)을 **재생성**한다.
  **멱등** — `generated` 시각만 달라진 경우는 변경으로 치지 않는다.
- **`bin/herald-find`** — vault 검색. 로컬 clone 이 있으면 `ripgrep`(없으면 `grep`),
  없으면 Forgejo API 로 색인·파일을 받아 훑는다. `--host`·`--project`·`--tag`·`--since`·`--until`·
  `--no-legacy`·`--list`·`--open`·`--raw` 지원.
- **`bin/herald-sort`** — `_inbox/<host>/` 회수분을 `sessions/{YYYY}/{MM}`·`handover/{host}`·
  `memory/{slug}`·`env/{host}` 제자리로 옮긴다. **덮어쓰지 않고**(같은 이름·다른 내용이면 충돌 보고),
  처리한 꾸러미는 지우지 않고 `_inbox/{host}/_done/` 으로 옮긴다. 기본은 모의 실행.
- **`bin/herald-legacy-import`** — 흩어진 옛 `*세션 작업기록*.md` 를 `sessions/_legacy/` 로 모은다.
  **파일명·내용을 고치지 않고**, 원본 경로·sha256·시각을 `_legacy/MANIFEST.json` 에 남겨
  `--undo` 로 되돌릴 수 있다. 기본은 모의 실행이며 `--apply` 를 줘야 옮긴다.
- **`docs/vault/SESSION-RECORD.md`** — 이 파이프라인의 설계 단일 출처.
- **`install.sh` 가 `bin/` 을 `~/.herald/bin/` 에 설치**하고 PATH 안내를 띄운다.

### Changed
- **`/session-save` 를 vault 규약으로 개정.** 저장 위치는 `HERALD_LOG_DIR` → `~/herald-vault/sessions/{YYYY}/{MM}`
  → `~/Desktop` 순으로 정하고, 파일명에 **호스트를 넣는다**(`260816-일--admin-host--herald-ai--0930.md`).
  저장 뒤 관리 호스트는 `herald-index` 로 색인을 갱신한다. `/session-log` 는 바뀌지 않는다.

### 설계 결정
- **「쓰기는 한 곳, 색인은 파생」**. 저장 시 INDEX 에 append 하는 방식은 폐기했다 —
  일반 호스트는 vault 를 읽지 못해 INDEX 를 갱신할 수 없기 때문이다. 색인을 파생물로 두면
  레거시 이관·`_inbox` 회수·수동 편집 뒤에 **한 번 다시 돌리면 정합이 회복된다.**
- **사실을 지어내지 않는다.** 옛 기록엔 호스트 정보가 없으므로 `unknown` 으로 두고 `inferred: true` 로
  표시한다. 옛 파일명 끝 4자리가 `HHMM` 인지 `끝MMDD` 인지 규약상 구분되지 않아 **추정하지 않는다.**

### 미검증
- `herald-sort --apply` 와 `herald-legacy-import` 는 하네스 분류기가 실행을 차단해
  **런타임 검증을 하지 못했다.** 나머지(`herald-index` 전체 경로, `herald-find` 목록·검색·필터·열기,
  `herald-sort` 모의 실행)는 임시 vault 로 실측 통과했다.

## [0.2.27] - 2026-08-16

### Added
- **증분 전송 실증.** general-host 설치본을 v0.2.25 로 갱신한 뒤 `herald-send docs --dry-run` 을
  재실행하니 `후보 54개 / 보낼 것 없음`. **서버에 「무엇을 갖고 있나」를 묻지 않고**
  로컬 대장(`~/.herald/sent-docs.json`)만으로 중복을 걸렀고 해시 재계산도 건너뛰었다.
  읽기 통로를 만들지 않는 증분이라는 설계의 핵심 주장이 실측으로 성립했다.

### Changed
- `HANDOVER.md`·`DECISIONS.md` — 증분 전송 실증 기록, general-host 설치본 v0.2.25 반영,
  「지금 바로 실행할 명령」을 비움(남은 명령 없음)

## [0.2.26] - 2026-08-16

### Added
- **herald-vault 전 경로 실증 완료 (07:37 KST).** general-host → 투입구 → inbox → 수집기 → vault
  가 실제 데이터로 통과했다. 문서 54건(48,186B)·환경 1건(1,522B)이 전송되어 vault 에
  커밋 2건으로 반영됐고, 원본은 `done/general-host/{docs,env}/` 에 보관됐다. `_inbox/general-host` 항목 73개.
  수집기는 `.trigger` 로 즉시 기동해 **전송부터 push 까지 1초 내**에 끝났다 — 5분 타이머는 안전망이다.

### Changed
- **`docs/vault/` 3종을 실증 결과로 갱신**
  - `RUNBOOK.md` — 1~4단계 전부 완료 표시, 실증 기록표, Forgejo API 확인 절차 추가,
    「그 다음」에 general-host 설치본 v0.2.25 갱신을 0번으로 추가
  - `HANDOVER.md` — 상태·검증표·다음 할 일·한 줄 요약을 실증 후 기준으로 재작성
  - `DECISIONS.md` — 진행 현황 갱신, 실측 4건 추가
- **`inbox` 조회 방법 정정.** `ssh vault-server 'ls -R /var/lib/herald/inbox/...'` 의
  `Permission denied` 는 **정상**이다(`2770 hdrop:herald`, 관리 계정은 두 그룹에 속하지 않는다).
  상태 확인은 `journalctl -u herald-collect` 또는 Forgejo API 로 한다.

### 알려진 문제
- general-host 에 설치된 `herald-send` 는 v0.2.24 판이라 파일 목록의 `memory/` 접두가 `emory/`·`mory/`
  로 잘려 보인다. **표시만의 문제이고 전송·수집에는 영향이 없다.** v0.2.25 로 재설치하면 사라진다.
- vault 에 들어간 54건은 전부 `memory/` 다. `staging/sessions` 가 비어 있기 때문이며,
  `/session-save` 가 `HERALD_LOG_DIR` 로 저장하도록 고쳐야 세션기록이 쌓이기 시작한다.

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
