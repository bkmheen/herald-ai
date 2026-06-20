---
name: task-tracker
description: >
  모든 Cowork 작업의 시작과 종료 시 시간 및 토큰 사용량을 자동으로 추적하는 스킬.
  이 스킬은 모든 작업, 모든 세션에 무조건 적용된다. 어떤 작업이든 시작하기 전에
  반드시 이 스킬의 절차를 따라야 한다. "작업", "task", "해줘", "만들어", "분석해",
  "수정해", "검토해", "정리해", "생성해", "조사해", "요약해" 등 모든 실행 요청에 적용.
  사용자가 어떤 종류의 작업을 요청하든 — 파일 생성, 코드 작성, 문서 정리, 분석,
  리서치, 스케줄링 — 이 스킬이 먼저 실행되어야 한다. 예외는 없다.
---

# Task Tracker 스킬

## 목적

모든 Cowork 작업의 시작과 끝에 시간 및 토큰 사용량을 기록·보고한다.

## 핵심 규칙 (절대 위반 금지)

1. **작업 시작 전**: 반드시 tracker start를 실행한다
2. **작업 완료 후**: 반드시 tracker stop을 실행한다
3. 이 두 단계 사이에 실제 작업을 수행한다
4. 이 규칙은 모든 작업에 예외 없이 적용된다

## 실행 절차

### STEP 1: 작업 시작 기록

```bash
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh start "작업 설명" <미션신호>
```

**미션신호 (세번째 인자, 필수 판단)** — 이번 user prompt 가 직전 턴과 같은 주제의 연장인지,
새로운 주제인지 Claude 가 매번 판단해 넘긴다. 이 신호로 알림 접두의 `[디렉토리:미션-대화]`
카운터(미션=주제 순번, 대화=그 주제 내 순번)가 갱신된다.

- `cont` — **직전 턴과 같은 주제의 연장** (기본). 대화 번호(T)만 +1.
- `new` — **새로운 주제의 업무 시작**. 미션 번호(M) +1, 대화 번호(T)=1 로 리셋.
- 세션의 **첫 작업**은 신호와 무관하게 항상 미션 1·대화 1 로 시작한다.

판단 기준: "직전 턴에서 하던 일과 본질적으로 같은 주제·작업의 이어짐인가?"
→ 예: `cont` / 아니오(주제 전환): `new`. 예시:
```bash
# 같은 주제 이어서 (예: 같은 버그 계속 수정)
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh start "마커 역순 수정 검증" cont
# 새 주제로 전환 (예: 전혀 다른 요청)
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh start "텔레그램 알림 포맷 변경" new
```

### STEP 2: 본 작업 수행

### STEP 3: 작업 종료 기록

```bash
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh stop
```

## 알림 시스템 개요

notify.sh 는 SessionStart / SessionEnd / Notification / Stop 훅에서 호출되어
텔레그램·macOS 알림을 전송한다.

### v5 (2026-04-17) — `[done]` 복원 + 사용 원칙 강화

| 훅 | notify 모드 | 메시지 타입 (조건) |
|----|-------------|---------------------|
| **SessionStart** | — (session-start.sh 실행) | 세션 시작 epoch / 턴 카운터 초기화 |
| **UserPromptSubmit** | — | task-tracker 리마인더 |
| **Notification** | `waiting` | ⏸️ 응답 대기 |
| **Stop** (턴 종료마다) | `done` | context 마커에 따라 분기 — 아래 표 |
| **SessionEnd** (세션 종료) | `session_end` | ✅ 완료 (안전망 — 마지막 턴이 [done] 이 아니었을 때만) |

Stop 훅 호출 시 context 마커별 결과:

| 마커 | 타입 | 사용 시점 |
|------|------|-----------|
| `[done]` 또는 마커 없음(기본) — 주의: **default 는 상황에 따라** | 아래 "판단 기준" 참조 | |
| `[done]` | ✅ 완료 | **이 턴의 답변이 자체 완결** — 사용자가 이 시점에 대화를 멈춰도 요청은 해결된 상태 |
| 마커 없음 (또는 `[progress]`) | 🔄 진행 보고 #N | **자동 파이프라인 중간** — 다음 턴에서 자동으로 연속 작업이 이어질 예정 |
| `[waiting]` | ⏸️ 응답 대기 | 사용자 입력/승인 필요 |
| `[error]` | ❌ 오류 | 사용자 조치 필요 |

> 💡 **Claude 의 [done] 판단 기준**:
> - 이 답변이 사용자 요청에 대한 **자체 완결 응답**이면 → `[done]` (✅)
> - 배치 1/4 완료처럼 **자동 연속 작업의 중간**이면 → 마커 없음 (🔄)
> - 사용자가 별도 프롬프트를 주지 않는 한 후속 작업이 없다면 → `[done]`

**MUTED 연동**: Stop 훅이 ✅ 완료 를 보내면 MUTED 가 설정되어, 뒤따르는 SessionEnd
훅의 중복 "완료" 는 자동 억제된다. 새 tracker start 또는 SessionStart 가 MUTED 해제.

### 경과 시간 기준

모든 알림의 `경과/소요` 시간은 **세션 시작 시각**(`.session_start_epoch`, SessionStart
훅이 기록)을 기준으로 계산된다. 매 턴의 tracker start 시각이 아니다.

### 다중 인스턴스 분리 (v6, 2026-05-09~) ⛔

여러 Claude Code 인스턴스가 동시에 실행될 때 알림이 서로 섞이지 않도록 **모든 상태가 인스턴스별 디렉토리** 로 분리된다.

- **런타임 루트**: `/tmp/task-tracker/<instance-id>/`  (예: `/tmp/task-tracker/claude-98166/`)
- **인스턴스 ID**: 프로세스 트리를 거슬러 올라가 찾은 부모 `claude` 프로세스 PID 기반.
  → 훅 스크립트와 Claude 의 Bash 툴 호출이 모두 같은 claude 프로세스의 자식이므로 같은 ID 로 수렴.
- **인스턴스 라벨**: `<디렉토리명>@<IP끝옥텟>·<세션시작 MM/DD HH:MM>` (예: `MarvisHome@221·06/20 17:07`).
  매 알림 헤더에 `🪪 [MarvisHome@221·…] Claude Code: ...` 형태로 표시되어 사용자가 어느 **디렉토리·머신**의 알림인지 즉시 구분.
  → 호스트명은 길어질 수 있어 로컬 IP 마지막 옥텟(최대 3자리)만 `@` 로 붙인다(2026-06-20 변경). 여러 머신에서 같은 디렉토리명을 써도 알림이 섞이지 않는다. 텔레그램 메시지·macOS 알림·채팅 한 줄 요약에 동일 적용.
  → IP 탐지: macOS `route`+`ipconfig getifaddr`, Linux `hostname -I`, 폴백 `ifconfig` 비루프백 inet.
- **단일 출처 헬퍼**: `~/.claude/skills/task-tracker/scripts/instance-resolve.sh` (모든 스크립트가 source 함). 직접 `RUNTIME_DIR` 을 하드코딩하지 않는다.

### 2단계 가드

1. **MUTED 가드**: `<RUNTIME_DIR>/.muted` 가 있으면 즉시 exit 0
   - SessionEnd 가 "완료" 를 발송할 때 설정됨 (중복 SessionEnd 방지)
   - SessionStart 훅 / 새 tracker start 가 해제
   - session_end 모드는 MUTED 가드를 통과하지 않고 스스로 체크
   - **인스턴스별로 독립** — 한 인스턴스의 mute 가 다른 인스턴스를 차단하지 않음

2. **CONTEXT 필수 가드**: `<RUNTIME_DIR>/.notify_context` 가 없으면 즉시 exit 0
   - Claude 가 명시적으로 context 를 쓰지 않은 턴은 알림 미발송
   - session_end 모드는 context 없어도 발송 (세션 요약)

### 기능 요약

| 기능 | 동작 |
|------|------|
| **타입 분화** | 🔄 진행 보고 (Stop) / ⏸️ 응답 대기 (Notification) / ❌ 오류 / ✅ 완료 (SessionEnd 전용) |
| **턴 카운터** | 진행 보고에 `#N` 표시 — 세션 내 몇 번째 응답인지 (SessionStart 에서만 리셋) |
| **경과 시간** | `.session_start_epoch` 기준 — 세션 시작부터의 누적 시간 |
| **중복 차단** | 같은 내용을 5초 이내 재발송하면 skip (hash 기반) |
| **MUTED 가드** | SessionEnd 발송 후 새 SessionStart 까지 모든 알림 suppress |
| **CONTEXT 가드** | context 파일 없으면 무조건 skip (session_end 제외) |
| **Telegram HTML** | `<b>` 볼드, `<code>` 코드 스타일 |
| **누적 통계** | SessionEnd 시 총 진행 보고 횟수 `📊 진행 보고: N회` 표시 |

### 테스트 시 주의

⚠️ **notify.sh를 직접 실행하여 테스트하면 실제 텔레그램 메시지가 전송된다.** 테스트는 반드시 `NOTIFY_DRY_RUN=1` 환경변수로 실행:

```bash
NOTIFY_DRY_RUN=1 bash ~/.claude/skills/task-tracker/scripts/notify.sh done
```

DRY_RUN 모드에서는 메시지를 stdout에만 출력하고 실제 전송은 skip한다. MUTED 상태 전환은 그대로 수행되어 후속 로직 테스트 가능.

## 알림 컨텍스트 (필수) ⛔

Notification/Stop 훅이 풍부한 메시지를 텔레그램으로 전송하려면, Claude가 **응답 종료 직전에** 컨텍스트 파일을 작성해야 한다.

### 메시지 타입 (v5)

| 타입 | 마커 | 이모지 | 사용 시점 |
|------|------|--------|-----------|
| **완료** | `[done]` | ✅ | 이 턴의 답변이 자체 완결 (사용자 요청 해결) |
| **진행 보고** | (마커 없음) | 🔄 | 자동 파이프라인의 중간 단계, 후속 작업이 이어질 예정 |
| **응답 대기** | `[waiting]` | ⏸️ | 사용자 입력/승인 필요 |
| **오류** | `[error]` | ❌ | 오류 발생, 사용자 조치 필요 |

> ⛔ **기준**: "사용자가 지금 세션을 끄더라도 요청이 해결된 상태인가?"
> - 예 → `[done]` (✅ 완료)
> - 아니오 (자동으로 다음 턴이 이어질 예정) → 마커 없음 (🔄 진행 보고)
>
> SessionEnd 훅은 마지막 턴이 `[done]` 이 아닌 상태로 세션이 종료될 때 안전망으로
> ✅ 완료 를 발송한다.

### 작성 규칙

**모든 응답 종료 직전** (마지막 출력 직전), 아래 명령을 실행한다:

```bash
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
[타입마커]      ← 선택, 첫 줄. 없으면 진행 보고
{10줄 이내 요약}
NOTIFY_EOF
```

> ⛔ **모든 응답에 예외 없이 작성한다.** 컨텍스트 파일이 없으면 텔레그램 알림에 상황 설명이 빠진다.
>
> ⛔ **반드시 `notify-ctx.sh` wrapper 를 사용한다.** 직접 `cat > /tmp/task-tracker/.notify_context` 를 쓰면 다중 Claude Code 인스턴스 환경에서 다른 인스턴스의 컨텍스트를 덮어쓰거나 자기 컨텍스트가 다른 인스턴스의 알림으로 발송되는 사고가 난다 (2026-05-09 수정). wrapper 가 자동으로 인스턴스별 디렉토리에 atomic 으로 기록한다.

### 타입 결정 가이드 (v5)

| 상황 | 마커 | 이유 |
|------|------|------|
| 사용자 요청을 이번 턴에 완전히 응답함 (질문 답변, 분석 리포트, 작업 완료 보고) | `[done]` | 자체 완결 → ✅ |
| 자동 파이프라인 중 한 단계 (배치 1/4 완료, 다음 배치 자동 진행) | (없음) | 연속 작업 중 → 🔄 |
| "이대로 진행할까요?" 같은 질문 | `[waiting]` | 입력 필요 → ⏸️ |
| 처리 불가/실패 | `[error]` | 조치 필요 → ❌ |

> 💡 **판단 기준 한 줄**: "사용자가 지금 세션을 끄더라도 요청이 해결된 상태인가?"
> → YES: `[done]` / NO: 마커 없음

### 예시

```bash
# 진행 중 (배치 완료, 다음 단계 진행) - 마커 없음
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
배치 4 처리 완료
- 53건 노트 생성
- 다음: hook 연결 → processed.json 갱신
NOTIFY_EOF

# 사용자 응답 대기 (질문 발송)
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
[waiting]
B2 분류 배정안 확인 필요
- 64건 분류 완료, 기존 그룹 62건, _Unclassified 2건
- 승인 시 frontmatter 반영 → B3 이동 진행
NOTIFY_EOF

# 전체 작업 완료 — 사용자 요청 해결됨 (자체 완결)
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
[done]
Dossier Task A+B 전체 완료
- Ingest: 64개 노트 생성
- Sort: 분류·이동·연결 완료
- Archive: 275건 (신규 64건)
NOTIFY_EOF

# 오류 발생
~/.claude/skills/task-tracker/scripts/notify-ctx.sh << 'NOTIFY_EOF'
[error]
hook-bidirectional.sh 실패 53건
- 모든 노트의 file: URL 비어있음
- 수동 보정 필요
NOTIFY_EOF
```

> ⛔ 10줄 초과 금지 (마커 줄 제외). 텔레그램 메시지 길이 제한 및 가독성을 위해 핵심만 기술한다.

## 초기 설정

설치 후 최초 1회:

```bash
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh setup
```

## 의존성

- `npx ccusage@latest` (Node.js) — 토큰 사용량 조회
- `jq` (권장) 또는 `node` — JSON 파싱
- `bc` — 소수점 계산 (macOS 기본)
