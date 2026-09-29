# ha-we — 작업환경 목록

> 기계가 읽는 단일 출처는 [`registry.json`](registry.json) 이다. 이 파일은 사람이 읽는 요약이며,
> **현재 버전은 각 환경의 `LATEST` 파일에서 확인한다** — 여기에 숫자를 옮겨 적지 않는다
> (두 곳에 적으면 반드시 한쪽이 낡는다).

체계 설명·사용법은 [`../docs/WORK-ENV.md`](../docs/WORK-ENV.md).

```bash
ha-we list                    # 목록 + 최신 버전
ha-we show <id>               # 구성 내용·인자
ha-we versions <id>           # 버전 목록
ha-we init <id> <대상>         # 뿌리기 (기본 모의 실행)
```

| 이름 | 무엇을 만드는가 | 산출물 | 생성 |
|------|-----------------|--------|------|
| **`ha-we-ppt_gen`** | `source/` 의 원본(이미지·PDF)으로 PPT 를 생성하는 작업 디렉토리. LLM 마다 자기 작업공간을 갖고, 공용 `.llm/` 로 서로의 진행과 판단을 읽고 이어받는다. 기억은 홈을 쓰지 않고 디렉토리 안에만 둔다. | `.pptx` + 동명 소스 | 2026-09-18 |

> `ppt_gen` 은 v0.1 까지 **`work_ppt`** 였다 (2026-09-29 개칭). v0.1 은 그대로 남아 있어 `-v 0.1` 로 꺼낼 수 있다.

## 새 환경을 더할 때

`docs/WORK-ENV.md` §7 을 따른다. 요약하면 — `work-env/<id>/0.1/` 에
`manifest.json`·`CHANGES.md`·`template/` 을 만들고, `LATEST` 를 적고,
`registry.json` 에 항목을 더하고, 빈 디렉토리에 `--apply` 로 검증한 뒤,
저장소의 `CHANGELOG`·`DEVLOG`·`VERSION` 을 규약대로 갱신한다.
