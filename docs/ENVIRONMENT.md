# 동반 환경 — 새 Mac 에서 같은 작업 환경 만들기

herald-ai 는 알림 훅만이 아니라 **"이 저장소를 clone 하면 그 맥이 어떤 환경이어야 하는지"** 를
함께 들고 다닙니다. 이 문서는 herald-ai 가 직접 설치하지 않지만 같은 작업 환경을 이루는
**동반 구성요소**를 정리한 것입니다.

| 층 | 무엇 | 누가 설치하나 |
|---|---|---|
| herald-ai 본체 | 알림 훅 · task-tracker·telegram-notify·trip-ledger 스킬 · `/session-log`·`/session-save` · vault 도구 | [`install.sh`](../install.sh) |
| **동반 구성요소** | **oh-my-claudecode(OMC) 플러그인 · OMC HUD 상태줄 설정 · 권장 전역 설정** | **[`bootstrap/herald-env-setup.sh`](../bootstrap/herald-env-setup.sh)** |

> **값의 단일 출처는 [`config/environment.manifest.json`](../config/environment.manifest.json) 입니다.**
> 이 문서와 설치 스크립트는 모두 그 파일을 읽습니다. 버전·URL 을 여기에 옮겨 적지 않습니다 —
> 두 곳에 적으면 반드시 한쪽이 낡습니다.

---

## 0. 그 맥에 아직 아무것도 없다면

herald-ai 는 Claude Code 위에서 돕니다. **Claude Code 자체가 먼저** 있어야 합니다.

```bash
# 1) 시스템 의존성 (Homebrew 가 없으면 https://brew.sh 먼저)
brew install bc jq node git

# 2) Claude Code
npm install -g @anthropic-ai/claude-code   # 또는 https://claude.ai/download (데스크톱 앱)
claude --version                            # 확인
```

`claude` 가 PATH 에 없으면 아래 설치 스크립트들은 **플러그인 설치만 건너뛰고** 나머지는
정상 진행합니다(설정 병합·스킬 복사). 나중에 `claude` 를 깔고 다시 돌리면 됩니다.

## 30초 요약 — 새 맥에서 할 일

**순서를 외울 필요가 없습니다.** 단일 진입점이 전체를 점검하고 빠진 것을 안내합니다.

```bash
git clone https://github.com/bkmheen/herald-ai.git ~/Code/herald-ai
bash ~/Code/herald-ai/bootstrap/herald-onboard.sh           # 전체 점검 (아무것도 안 바꿈)
bash ~/Code/herald-ai/bootstrap/herald-onboard.sh --apply   # 자동으로 되는 것 실행
```

이후 **Claude Code 를 재시작**하고, 새 세션에서 `/oh-my-claudecode:hud setup` 을 한 번
실행하면 상태줄까지 완성됩니다. 마지막으로 점검을 다시 돌려 **전 항목 ✅** 을 확인합니다
(남은 항목이 있으면 exit 1).

<details>
<summary>온보딩이 안에서 부르는 단계별 명령 (직접 돌려도 됩니다)</summary>

```bash
cd ~/Code/herald-ai
bash install.sh                                    # 1) herald-ai 본체(알림·스킬·vault 도구)
bash bootstrap/herald-env-setup.sh                 # 2) 동반 환경 점검
bash bootstrap/herald-env-setup.sh --apply         # 3) OMC 플러그인 + HUD 설정
bash bootstrap/herald-convention-register.sh       # 4) "v3.1 커밋 체계" 호출어 등록
```

</details>

> **clone 위치는 자유입니다.** 스크립트들은 자기 위치를 기준으로 저장소를 찾습니다.
> 다만 호출어 등록 블록에는 **그때의 실제 경로**가 들어가므로, 나중에 저장소를 옮기면
> `bash bootstrap/herald-convention-register.sh` 를 다시 돌려 경로를 갱신하십시오.

| 명령 | 하는 일 |
|---|---|
| `bash bootstrap/herald-env-setup.sh` | **점검만.** 아무것도 바꾸지 않고 기준과의 차이를 표로 출력. 필수 항목이 빠졌으면 exit 1 |
| `… --list-skills` | 지금 이 맥에 로드된 스킬·에이전트 목록 (herald-ai · OMC · superpowers) → [SKILLS.md](SKILLS.md) |
| `… --apply` | 필수 마켓플레이스·플러그인 설치 + HUD 설정 병합 |
| `… --apply --all` | 선택 플러그인까지 함께 |
| `… --apply --with-settings` | 권장 전역 설정(`env`·`tui` 등)도 병합 |
| `… --apply --no-hud` | HUD 설정은 건드리지 않음 |
| `… --hud-only` | **HUD 설정만** 기준값으로. 플러그인은 건드리지 않는다 (이미 OMC 가 깔린 맥) |

커밋 규약 쪽은 별도 스크립트입니다.

| 명령 | 하는 일 |
|---|---|
| `bash bootstrap/herald-convention-register.sh` | **"v3.1 커밋 체계"** 호출어를 이 맥의 글로벌 지침에 등록 (`--check` · `--revert`) |
| `bash bootstrap/herald-convention-init.sh <저장소>` | 새 저장소에 규약 도입 — `VERSION`·`CHANGELOG`·`DEVLOG`·`CLAUDE.md` 스캐폴딩 (기본 모의 실행, `--apply` 로 생성) |

규약 자체는 [COMMIT-CONVENTION.md](COMMIT-CONVENTION.md) 에 있습니다.

`settings.json` 은 변경 직전 `settings.json.bak.<epoch>` 로 백업됩니다.

---

## 1. oh-my-claudecode (OMC) — 필수

Claude Code 플러그인. herald-ai 세션에서 실제로 쓰는 **작업 엔진**입니다.
계획·실행·검증 에이전트, 병렬 실행 스킬, LSP·wiki·notepad·state MCP 툴, 그리고 아래의 HUD 상태줄을
제공합니다. **이것이 없어도 herald-ai 알림은 동작하지만, 일하는 방식이 달라집니다.**

```bash
claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode.git
claude plugin install oh-my-claudecode@omc --scope user
```

검증:

```bash
claude plugin list | grep -A2 oh-my-claudecode    # enabled 인지 확인
```

- 마켓플레이스 이름은 `omc` 로 등록됩니다 (플러그인 매니페스트가 정하는 이름).
- 설치 위치: `~/.claude/plugins/cache/omc/oh-my-claudecode/<버전>/`
- 업데이트: `claude plugin update oh-my-claudecode@omc` → **Claude Code 재시작**
- 전역 `omc` CLI(npm)는 **별개**입니다. 플러그인만으로 스킬·에이전트·HUD 는 모두 동작하고,
  `omc ask` 로 외부 모델(Codex·Gemini 등)을 부르는 `/ask`·`/ccg`·`/omc-teams` 계열만
  추가로 필요합니다: `npm install -g oh-my-claudecode`

## 2. HUD (상태줄) — 기준 설정

OMC HUD 는 Claude Code 하단 상태줄에 현재 모드·브랜치·컨텍스트 사용률·실행 중 에이전트를
표시합니다. **기준 스냅샷(관리 맥)의 설정을 그대로 옮겨 둡니다.**

```jsonc
// ~/.claude/settings.json 에 병합되는 조각
{
  "statusLine": {
    "type": "command",
    "command": "node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hud/omc-hud.mjs"
  },
  "omcHud": {
    "preset": "full",
    "elements": { "cwd": true, "cwdFormat": "folder", "hostname": true }
  }
}
```

왜 이 값인가:

| 항목 | 값 | 이유 |
|---|---|---|
| `preset` | `full` | 실행 중 에이전트 목록까지 여러 줄로 보이는 최대 표시. (`minimal` · `focused` · `full`) |
| `elements.cwd` + `cwdFormat` | `true` · `folder` | 창을 여러 개 띄우고 일하므로 현재 위치를 늘 본다. 전체 경로가 아니라 **마지막 폴더명만** 표시 |
| `elements.hostname` | `true` | 여러 맥에서 같은 저장소를 다룬다. **어느 기계인지 상태줄에서 즉시 구분** — herald-ai 알림 라벨의 호스트 구분과 같은 목적 |

이미 OMC 가 깔린 맥에서 **상태줄만** 기준값으로 맞추려면:

```bash
bash bootstrap/herald-env-setup.sh --hud-only
```

### 설치 순서 (중요)

1. **OMC 플러그인 먼저** — HUD 는 플러그인 코드를 불러 쓰는 얇은 래퍼일 뿐입니다.
2. Claude Code 새 세션에서 **`/oh-my-claudecode:hud setup`** 1회 →
   `~/.claude/hud/omc-hud.mjs` 와 `hud/lib/config-dir.mjs` 가 플러그인 템플릿에서 생성됩니다.
   **이 래퍼를 손으로 쓰지 않습니다** — 단일 출처는 플러그인 쪽 템플릿입니다.
3. `bash bootstrap/herald-env-setup.sh --apply` 로 위 설정 조각 병합.
4. Claude Code 재시작.

### 선택 — cwd 색상 패치

기본값이 `dim` 이라 어두운 터미널에서 현재 디렉토리가 거의 읽히지 않습니다.

```bash
bash bootstrap/omc-hud-cwd-color-patch.sh            # dim → brightCyan
bash bootstrap/omc-hud-cwd-color-patch.sh --revert   # 되돌리기
```

> ⚠️ 플러그인 **캐시 파일을 직접 고치는** 패치입니다. OMC 를 업데이트하면 새 버전 디렉토리로
> 갈아타므로 **업데이트할 때마다 다시 실행**해야 합니다. 원본은 `.bak` 으로 남습니다.

## 3. 선택 플러그인

`--apply --all` 을 줄 때만 설치됩니다. 그 맥에서 하는 일에 따라 고르십시오.

| 플러그인 | 언제 필요한가 |
|---|---|
| `frontend-design@claude-plugins-official` | 웹/UI 작업을 하는 맥 |
| `swift-lsp@claude-plugins-official` | iOS/macOS 앱 작업을 하는 맥 |
| `superpowers` | brainstorming · TDD · systematic-debugging 등 작업 규율 스킬 |

`superpowers` 는 기준 스냅샷에서 마켓플레이스 설치가 아니라 `~/.claude/skills/superpowers/` 에
놓인 **skills-dir 플러그인**으로 로드되고 있습니다. 두 경로 중 하나만 씁니다 — 둘 다 두면 중복 로드됩니다.

## 4. 권장 전역 설정 (선택)

`--with-settings` 를 줄 때만 병합됩니다. 사전(`env`)은 **덮어쓰지 않고 병합**합니다.

| 키 | 값 | 이유 |
|---|---|---|
| `env.CLAUDE_CODE_MAX_RETRIES` | `15` | 장시간 작업 중 API 흔들림에서 세션을 잃지 않기 위해 |
| `env.CLAUDE_CODE_RETRY_WATCHDOG` | `1` | 재시도 감시 활성 |
| `env.API_TIMEOUT_MS` | `1200000` | 긴 에이전트 실행(20분)이 타임아웃으로 끊기지 않게 |
| `tui` | `fullscreen` | 전체화면 TUI |
| `cleanupPeriodDays` | `365` | 트랜스크립트 보관 — `/session-save`·`ccusage` 가 과거를 읽을 수 있어야 한다 |

**옮기지 않는 것** — `additionalDirectories`(맥마다 경로가 다름) · `permissions`(맥마다 다루는
저장소가 달라 그대로 옮기면 과대 허용) · `hooks`(herald-ai `install.sh` 가 관리).

## 5. 시스템 의존성

| | 항목 |
|---|---|
| 필수 | `bash` · `python3` · `node` |
| 권장 | `curl` · `bc` · `jq` · `git` |

```bash
brew install bc jq node git                                    # macOS
sudo apt install -y python3 curl bc jq nodejs npm git          # Debian/Ubuntu
```

`node` 는 herald-ai 의 비용 추적(`ccusage`)과 **HUD 상태줄 양쪽에** 필요합니다.
herald-ai 만 쓸 때는 없어도 폴백되지만, HUD 는 `node` 없이 동작하지 않습니다.

---

## 이 명세를 갱신하는 법

기준 맥의 설정을 바꿨다면 **저장소에도 옮겨야** 다음 맥이 같은 상태로 시작합니다.

1. `config/environment.manifest.json` 의 해당 값을 고칩니다 (여기가 단일 출처).
2. `captured_at` 을 갱신합니다.
3. 이 문서의 **설명**(왜 그 값인가)을 함께 고칩니다. 값 자체는 매니페스트에만 둡니다.
4. `bash bootstrap/herald-env-setup.sh` 로 기준 맥에서 다시 점검해 ✅ 만 나오는지 확인합니다.

## 이 저장소에 담지 않는 것

herald-ai 는 공개 저장소입니다 ([CLAUDE.md](../CLAUDE.md) 「공개 저장소 원칙」).
**호스트 이름 · IP · 개인 홈 경로 · 사용 금액 · 토큰**은 이 명세에 넣지 않습니다.
기준 맥을 가리킬 때도 이름 대신 "기준 스냅샷" 이라 적습니다.
기계마다 다른 실제 값은 `~/.herald/vault.conf` 와 각자의 vault 에 둡니다.

현재 맥의 실제 상태를 기록으로 남기려면 `herald-env` 를 씁니다 — 비밀은 이름과 존재 여부만 남깁니다.

```bash
herald-env -o ~/env-snapshot.json
```
