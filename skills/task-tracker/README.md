# Task Tracker

Cowork 작업마다 시작/종료 시간과 토큰 사용량을 자동 추적하는 스킬.

## 설치

### 1. 아래 전체를 터미널에 복사-붙여넣기

```bash
cd ~/Downloads && \
unzip -o task-tracker-skill.zip && \
mkdir -p ~/.claude/skills/task-tracker && \
cp -r task-tracker-skill/* ~/.claude/skills/task-tracker/ && \
chmod +x ~/.claude/skills/task-tracker/scripts/task-tracker.sh && \
echo "✅ 설치 완료"
```

### 2. 초기 설정

```bash
~/.claude/skills/task-tracker/scripts/task-tracker.sh setup
```

플랜 선택 (Pro / Max 5x / Max 20x) → config 자동 저장.

### 3. 작업 폴더에 CLAUDE.md 추가

Cowork이 접근하는 **각 작업 폴더**에 `CLAUDE.md` 파일을 만든다.
Cowork은 작업 시작 시 이 파일을 자동으로 읽고 규칙을 따른다.

아래 명령으로 원하는 작업 폴더에 추가한다 (경로를 본인 폴더로 변경):

```bash
cat >> ~/your-work-folder/CLAUDE.md << 'EOF'

## 필수 규칙: 작업 추적 (Task Tracker)

모든 작업 수행 시 아래 절차를 반드시 따른다. 예외 없음.

### 작업 시작 전 (반드시 가장 먼저 실행):
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh start "작업에 대한 간결한 설명"
→ 출력된 시작 시간과 토큰 사용량을 사용자에게 보고한다.

### 작업 완료 후 (반드시 가장 마지막에 실행):
bash ~/.claude/skills/task-tracker/scripts/task-tracker.sh stop
→ 출력된 소요 시간, 토큰 사용량(절대값 및 퍼센트), 비용을 사용자에게 보고한다.

이 규칙은 파일 생성, 코드 작성, 분석, 리서치, 정리, 수정, 검토 등
어떤 작업이든 예외 없이 적용된다.
EOF
```

여러 작업 폴더를 사용한다면 각 폴더에 동일한 CLAUDE.md를 넣거나,
공통 상위 폴더에 하나만 두면 된다.

## 설치 후 구조

```
~/.claude/skills/task-tracker/
├── README.md
├── SKILL.md                   ← 스킬 지시문 (Cowork이 읽음)
├── config                     ← 플랜 설정 (setup으로 생성)
├── task_history.jsonl          ← 작업 히스토리 (자동 누적)
└── scripts/
    └── task-tracker.sh         ← 실행 스크립트
```

## 사용법

```bash
# 초기 설정 (최초 1회)
task-tracker.sh setup

# 작업 시작
task-tracker.sh start "PDF 보고서 생성"

# 작업 종료
task-tracker.sh stop

# 현재 상태 확인
task-tracker.sh status

# 최근 히스토리
task-tracker.sh history
task-tracker.sh history 20
```

## 의존성

- Node.js (npx ccusage@latest)
- jq (권장, `brew install jq`)
- bc (macOS 기본)
