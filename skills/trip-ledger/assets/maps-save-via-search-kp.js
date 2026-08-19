/*
 * maps-save-via-search-kp.js — 구글 "검색" 지식패널로 장소를 컬렉션에 저장한다.
 *
 * 왜 이 경로인가: 구글 "지도" 의 저장 대화상자는 렌더링되지 않는다 (LESSONS.md L-004).
 *                 검색 지식패널의 「컬렉션에 저장」 은 정상 동작한다.
 *
 * 사용법: 구글 검색에서 `<상호> <도시>` 를 검색해 지식패널이 뜬 상태에서 실행.
 * 반환:   {title, before, after} — title 로 엉뚱한 가게가 아닌지 반드시 확인할 것.
 * 성질:   멱등. 이미 체크돼 있으면 클릭하지 않는다.
 *
 * 주의:   한 배치에 1~3건까지만 (L-006). 타임아웃 시 재실행 말고 이 스니펫으로 상태만 조회.
 */
const T = '<여기에 컬렉션 이름>';          // 예: '델프트 2026 여름'

const sleep = ms => new Promise(r => setTimeout(r, ms));

// 지식패널 제목 — 저장 대상이 맞는지 확인하는 용도
const title = (document.querySelector('[data-attrid="title"]') || {}).innerText || '(noKP)';

// 저장 버튼: 미저장이면 "컬렉션에 저장", 저장돼 있으면 "저장됨"
// 라벨은 UI 언어를 따른다 — 한국어/영문 양쪽을 본다 (L-010).
// 저장·저장됨 두 버튼이 동시에 DOM 에 있으므로 보이는 쪽을 고르고, 없으면 첫 번째로 폴백한다.
const SAVE_RE = /컬렉션에 저장|저장됨|to collection|^Saved\b/;
const _vis = e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
const _cands = [...document.querySelectorAll('[role="button"],button,span')]
  .filter(e => SAVE_RE.test(e.getAttribute('aria-label') || ''));
let btn = _cands.find(_vis) || _cands[0];
if (!btn) throw 'no save button';   // → 라벨 목록을 덤프해 언어·구조를 먼저 확인할 것 (L-010)

btn.click();
await sleep(3500);                          // 대화상자 마운트 대기 — 짧으면 행을 못 찾는다

const cb = [...document.querySelectorAll('[role="checkbox"]')]
  .find(e => (e.textContent || '').includes(T));
if (!cb) throw 'no collection row';

const before = cb.getAttribute('aria-checked');
if (before !== 'true') cb.click();          // 멱등 — 이미 저장돼 있으면 건드리지 않는다
await sleep(3000);

const x = [...document.querySelectorAll('[role="button"],button')]
  .find(e => /닫기|^Close$/.test(e.getAttribute('aria-label') || '') && _vis(e));
if (x) x.click();

JSON.stringify({ title, before, after: cb.getAttribute('aria-checked') })
