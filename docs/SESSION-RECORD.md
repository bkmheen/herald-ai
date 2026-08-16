# 세션기록 형식과 색인

스키마 판본: **`herald.session-record/1.0.0`** · **`herald.session-index/1.0.0`**

설계 배경은 [`DESIGN.md`](DESIGN.md), 설치·운영은 [`VAULT-SETUP.md`](VAULT-SETUP.md).

---

## 0. 무엇을 바꾸는가

`/session-save` 산출물이 바탕화면이나 여기저기 흩어지면, 나중에 찾을 때 어디를 뒤져야 할지
알 수 없다. **한곳에 모으고 색인해, 무엇을 찾든 vault 를 먼저 뒤지면 나오게** 한다.

```
/session-save → vault(sessions/YYYY/MM/) → herald-index 로 색인 → herald-find 로 검색
                                         → 외부 도구가 프론트매터·index.json 으로 참조
```

---

## 1. 핵심 결정 — 「쓰기는 한 곳, 색인은 파생」

| 안 | 내용 | 판정 |
|---|---|---|
| **ⓐ 색인 파생** | `/session-save` 는 **기록 파일 하나만** 쓴다. 색인은 전체를 훑어 **재생성** | **채택** |
| ⓑ 저장 시 즉시 append | 저장할 때 타임라인에 한 줄 덧붙인다 | **불가** — 일반 호스트는 vault 를 읽지 못한다 |
| ⓒ 하이브리드 | 관리 호스트는 즉시, 나머지는 나중에 | 두 경로가 갈려 색인이 어긋난다 |

**ⓐ 를 택한 이유는 멱등성이다.** 색인이 파생물이면 이관·회수·수동 편집 어느 쪽이 끼어들어도
한 번 다시 돌리면 정합이 회복된다. 정렬을 UTC 로 고정했으므로 어디서 돌려도 결과가 같다.

---

## 2. 기록 파일 — `herald.session-record/1.0.0`

### 2.1 프론트매터

```yaml
---
schema: herald.session-record/1.0.0
id: 260816-일--laptop--myproject--0930
host: laptop
machine_id: <불변 식별자>
project: myproject
cwd: /home/you/Code/myproject
branch: main
started: 2026-08-16T06:22:02+09:00
ended: 2026-08-16T09:30:00+09:00
tags: [개발, 문서, git]
versions: {from: "0.2.23", to: "0.2.28"}
commits: [a1b2c3d, e4f5g6h]
filter: null
summary: "한 줄 요약 — 타임라인에 그대로 실린다"
---
```

| 열쇠 | 필수 | 뜻 |
|---|---|---|
| `schema` | ✅ | **이 기록이 어느 판본 규약으로 쓰였는지.** 읽는 쪽이 판본을 보고 해석한다 |
| `id` | ✅ | 파일명에서 확장자를 뺀 값. 색인의 1차 키 |
| `host` | ✅ | 호스트 이름. 알 수 없으면 `unknown` |
| `machine_id` | | 호스트 대장의 1차 키. 이름·주소가 바뀌어도 불변 |
| `project` | ✅ | 작업 디렉토리 basename |
| `cwd` | ✅ | 작업 디렉토리 절대경로 |
| `branch` | | git 브랜치 (저장소면) |
| `started`·`ended` | ✅ | ISO 8601, 오프셋 포함. 색인 정렬은 UTC 로 환산해 쓴다 |
| `tags` | | 카테고리 태그 |
| `versions` | | `{from, to}` — 이 세션 동안의 버전 변화 |
| `commits` | | 짧은 해시 목록 |
| `filter` | ✅ | 필터를 걸었으면 원문, 없으면 `null` |
| `summary` | ✅ | 한 줄 요약 |

값에 `:`·`#` 이 들어가면 큰따옴표로 감싼다. **줄바꿈이 들어가는 값은 쓰지 않는다** —
파서를 단순하게 유지하기 위한 규약이다.

### 2.2 본문

요약 → 작업 목록 → 세부 내용. 프론트매터가 그 앞에 붙을 뿐이다.

### 2.3 판본 관리

- 각 파일이 `schema:` 로 **자기 판본을 스스로 밝힌다**
- 정본은 vault `conventions/versions.json` 의 `session_record` 값
- 판본이 올라가도 **옛 기록을 고치지 않는다.** 읽는 쪽이 분기한다

---

## 3. 저장 위치·파일명

```
1. $HERALD_LOG_DIR 가 설정돼 있으면  → 그 경로              (일반 호스트의 staging)
2. ~/herald-vault 클론이 있으면      → sessions/{YYYY}/{MM}/ (관리 호스트)
3. 둘 다 없으면                      → ~/Desktop/            (폴백)
```

> ⚠ **관리 호스트에는 `HERALD_LOG_DIR` 를 설정하지 않는다.** 설정하면 2번을 건너뛴다.

```
260816-일--laptop--myproject--0930.md
└날짜┘ └요일┘ └호스트┘ └프로젝트┘ └시각┘
```

**호스트를 파일명에 넣는 것이 핵심이다** — 여러 컴퓨터의 기록이 한 디렉토리에 모여도
파일명만으로 구분된다. 필터를 걸었으면 프로젝트 뒤에 `·범위` 를 붙인다.

---

## 4. 색인 — 두 벌

`herald-index` 가 `sessions/**/*.md` 를 훑어 **매번 새로 쓴다.**

### 4.1 `sessions/INDEX.md` — 사람용 타임라인

```
2026-08-16 06:22 | laptop | myproject | [요약](<2026/08/260816-일--laptop--myproject--0930.md>) | 0.2.23→0.2.28
```

**이 파일은 전부 생성물이다.** 머리말까지 매번 다시 쓰므로 직접 편집하지 않는다 —
고칠 것은 원본 기록의 프론트매터다.

### 4.2 `sessions/index.json` — 기계용

```json
{
  "schema": "herald.session-index/1.0.0",
  "record_schema": "herald.session-record/1.0.0",
  "display_tz": "Asia/Seoul",
  "count": 27,
  "records": [
    {"id": "…", "path": "sessions/2026/08/….md",
     "host": "laptop", "project": "myproject",
     "started": "2026-08-16T06:22:02+09:00", "started_utc": "2026-08-15T21:22Z",
     "tags": ["개발"], "summary": "…", "inferred": false, "time_known": true}
  ]
}
```

외부 도구가 파싱해 바로 참조한다. **기계용 값은 언제나 `started_utc`(UTC)** 다.

---

## 4.3 시각 표시 — 저장은 UTC, 표시는 현지시각

여러 나라의 기록을 한 줄로 세우려면 기준이 하나여야 한다. 그러나 사람이 읽을 때는
자기가 있는 곳의 시각이라야 뜻이 통한다. **저장된 값은 건드리지 않고 표시 단계에서만 바꾼다.**

```
시간대 결정 순서
  1. --tz 인자            herald-find --tz Asia/Tokyo · --tz UTC · --tz local
  2. 환경변수 HERALD_TZ   해외에서 셸에 한 번만 export 하면 전부 따라온다
  3. vault.conf 의 DISPLAY_TZ
  4. 기본값 Asia/Seoul
```

`local` 은 그 컴퓨터의 시스템 시간대다 — 노트북을 들고 이동하면 따라간다.
알 수 없는 지역 이름을 주면 **지어내지 않고 UTC 로 물러난다.**

### 시각을 모르는 기록

옛 파일명에서 날짜만 건진 기록은 `time_known: false` 로 표시하고 **날짜만 보여 준다.**
`00:00 UTC` 로 채워 둔 값을 시간대 변환하면 없는 시각이 생기거나 날짜가 하루 밀린다.

---

## 5. 옛 기록 이관 — 원본을 손대지 않는다

| 원칙 | 내용 |
|---|---|
| 파일명·내용 | **고치지 않는다.** 프론트매터도 넣지 않는다 |
| 호스트 | 옛 파일엔 정보가 없다. **추정하지 않고** `unknown` |
| 색인 | 파일명에서 날짜·프로젝트·필터만 뽑아 `inferred: true` 로 넣는다 |
| 되돌리기 | `_legacy/MANIFEST.json` 에 원본 경로·sha256·시각을 남긴다 |
| 기본 동작 | **모의 실행이 기본.** `--apply` 를 줘야 옮긴다 |

### 남의 프론트매터는 읽어 쓴다

레거시라도 **파일에 이미 적혀 있는 사실은 가져온다** — 지어내는 것이 아니다.
노트 가공 도구가 붙여 둔 프론트매터가 흔한 예다.

| 색인 항목 | 가져오는 곳 |
|---|---|
| `summary` | `source_name` → 본문 첫 `# ` 제목 → `title` → 파일명.<br>**파일명과 같은 후보는 건너뛴다** — 가공본이 파일명을 그대로 옮겨 둔 경우가 많다 |
| `started` | `event_date` → `date` → **파일명의 날짜** → `created` → `compiled_at`.<br>`created` 계열은 노트를 만든 시각이라 세션 날짜와 다르다 |
| `tags` | `tags` (블록 목록도 해석한다) |
| `foreign_schema` | `type` — 출처를 남긴다 |

그래도 **호스트는 `unknown` 으로 둔다.** 옛 파일 어디에도 적혀 있지 않기 때문이다.

---

## 6. 도구

| 도구 | 하는 일 | 실행 호스트 |
|---|---|---|
| `herald-index` | `INDEX.md`·`index.json` 재생성 (멱등) | 관리 호스트 |
| `herald-find` | 검색. 로컬 clone 이 있으면 ripgrep, 없으면 API | 읽기 권한이 있는 호스트 |
| `herald-sort` | `_inbox/<host>/` 회수분을 제자리로 | 관리 호스트 |
| `herald-legacy-import` | 옛 기록을 `_legacy/` 로 (원본 불변·`--undo`) | 관리 호스트 |
| `herald-send`·`herald-env` | 투입 전송·환경 스냅샷 | 일반 호스트 |

---

## 7. 전체 흐름

```
관리 호스트                          일반 호스트
  /session-save                        /session-save
      ↓                                    ↓
  vault/sessions/YYYY/MM/*.md        $HERALD_LOG_DIR/*.md
      ↓                                    ↓ herald-send docs
  herald-index                       투입구 → inbox → 수집기 → vault/_inbox/<host>/
      ↓                                    ↓
  INDEX.md · index.json  ←────────  herald-sort (관리 호스트에서 제자리로)
      ↓
  herald-find / 외부 도구
```
