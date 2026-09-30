#!/usr/bin/env python3
"""template_2609 — pptx 생성기 (md → pptx + pdf)

이 파일을 산출물 이름으로 복사하고 **맨 위 상수 여섯 개만** 고쳐 쓴다.

    cp template_2609.py "07. 어떤 제목_v0.1.py"
    cp template_2609.md "07. 어떤 제목_v0.1.md"      ← 내용은 md 에 쓴다
    python3 "07. 어떤 제목_v0.1.py"

만드는 것 — 동명 네 파일 (`.llm/memory/30_산출물_및_버전_규칙.md`)

    <번호>. <제목>_v<버전>.md     내용 원본 (이 스크립트의 입력)
    <번호>. <제목>_v<버전>.pptx   생성
    <번호>. <제목>_v<버전>.pdf    생성 (soffice 변환, 필수)
    <번호>. <제목>_v<버전>.py     이 파일

자동으로 하는 일
    - 표지·2쪽 개정 이력·머리말·꼬리말(제목 | v버전·일자 / 저자·소속 | n / N)
    - pdf 변환과 페이지 수 검증
    - 이전 버전 네 파일을 __history__/ 로 이동 (그 뒤 _CHANGE.md 는 사람이 쓴다)

md 문법
    첫 블록      : `# 제목` · `## 부제` · `@@ 메타`      → 표지
    `## 제목`    : 구분 슬라이드
    `### 제목`   : 본문 슬라이드
                   `- ` 불릿 (두 칸 들여쓰면 하위) · `|` 표 · ``` 코드 · `> 출처:` 캡션
    블록 구분자  : `===` 한 줄
    빈 줄 없이 이어진 줄은 앞 항목에 붙는다

서식을 바꾸려면 「디자인 상수」 절만 고친다. 레이아웃 규칙의 근거는 위 규칙 문서에 있다.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.util import Emu, Inches, Pt

# ─────────────────────────────────────────────────────────────── 산출물 식별
# ★ 새 자료를 만들 때 이 여섯 줄만 고친다
NUMBER = "00"                          # 자료 번호 (.llm/memory/25_번호_규칙.md)
TITLE = "제목을 여기에"                 # 파일명·머리말에 함께 쓰인다
VERSION = "0.1"                        # 표지·머리말·파일명에 함께 쓰인다
DATE = "2026-09-30"                    # 이 버전의 발행일
AUTHOR = "<저자>"                       # ⛔ 사용자에게 묻고 고정한다. 추측하지 않는다
AFFIL = "<소속>"                        # ⛔ 사용자에게 묻는다

BASE = f"{NUMBER}. {TITLE}_v{VERSION}"

HERE = Path(__file__).resolve().parent
HISTORY = HERE / "__history__"

# ─────────────────────────────────────────────────────────────── 디자인 상수
FONT = "Apple SD Gothic Neo"          # 없으면 여기만 바꾼다
NAVY = RGBColor(0x1F, 0x38, 0x64)
ACCENT = RGBColor(0x2E, 0x75, 0xB6)
INK = RGBColor(0x26, 0x26, 0x26)
MUTED = RGBColor(0x70, 0x70, 0x70)
RULE = RGBColor(0xD9, 0xDD, 0xE3)
HEADFILL = RGBColor(0xEE, 0xF2, 0xF7)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

W, H = Inches(13.333), Inches(7.5)
ML, MR = Inches(0.72), Inches(0.72)
BODY_W = W - ML - MR
TOP_TITLE = Inches(0.52)
TOP_BODY = Inches(1.42)
BOTTOM_LIMIT = Inches(6.72)


# ─────────────────────────────────────────────────────────────── md 파서
def parse(md_text):
    blocks = [b.strip("\n") for b in re.split(r"^===\s*$", md_text, flags=re.M)]
    blocks = [b for b in blocks if b.strip()]

    cover = {"title": "", "subtitle": "", "meta": []}
    for line in blocks[0].splitlines():
        s = line.strip()
        if s.startswith("## "):
            cover["subtitle"] = s[3:].strip()
        elif s.startswith("# "):
            cover["title"] = s[2:].strip()
        elif s.startswith("@@"):
            cover["meta"].append(s[2:].strip())

    slides = []
    for blk in blocks[1:]:
        lines = blk.splitlines()
        head = lines[0].strip()
        if head.startswith("### "):
            slide = {"kind": "body", "title": head[4:].strip(), "items": [], "source": ""}
        elif head.startswith("## "):
            slides.append({"kind": "section", "title": head[3:].strip()})
            continue
        else:
            raise ValueError(f"슬라이드 머리글을 찾지 못했습니다: {head!r}")

        table, code, in_code, prev_blank = [], [], False, True
        for raw in lines[1:]:
            s = raw.rstrip()
            if s.strip().startswith("```"):
                if in_code:
                    if table:                       # 앞선 표를 먼저 비운다 (순서 보존)
                        slide["items"].append(("table", table)); table = []
                    slide["items"].append(("code", code)); code, in_code = [], False
                else:
                    if table:
                        slide["items"].append(("table", table)); table = []
                    in_code = True
                continue
            if in_code:
                code.append(s)
                continue
            if not s.strip():
                prev_blank = True
                continue
            if s.lstrip().startswith("|"):
                cells = [c.strip() for c in s.strip().strip("|").split("|")]
                if all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    continue          # 구분 행
                table.append(cells)
                prev_blank = False
                continue
            if table:
                slide["items"].append(("table", table))
                table = []
            if s.lstrip().startswith("> "):
                slide["source"] = s.lstrip()[2:].strip()
            elif s.lstrip().startswith("- "):
                indent = len(s) - len(s.lstrip())
                slide["items"].append(("bullet", (1 if indent >= 2 else 0, s.lstrip()[2:].strip())))
            elif (not prev_blank) and slide["items"] and slide["items"][-1][0] in ("bullet", "para"):
                # 빈 줄 없이 이어진 줄은 앞 항목에 붙인다
                kind_prev, payload_prev = slide["items"][-1]
                if kind_prev == "bullet":
                    lvl, prev = payload_prev
                    slide["items"][-1] = ("bullet", (lvl, prev + " " + s.strip()))
                else:
                    slide["items"][-1] = ("para", payload_prev + " " + s.strip())
            else:
                slide["items"].append(("para", s.strip()))
            prev_blank = False
        if table:
            slide["items"].append(("table", table))
        slides.append(slide)
    return cover, slides


# ─────────────────────────────────────────────────────────────── 서식 도우미
def inline(paragraph, text, size, color=INK, bold_all=False):
    """**굵게** · *기울임* · `코드` 를 런으로 나눈다."""
    text = text.replace("⛔ ", "⛔ ").replace("★", "★")
    for chunk in re.split(r"(\*\*[^*]+\*\*|\*[^*\n]+\*|`[^`]+`)", text):
        if not chunk:
            continue
        run = paragraph.add_run()
        bold, italic = bold_all, False
        if chunk.startswith("**") and chunk.endswith("**"):
            run.text = chunk[2:-2]
            bold = True
        elif chunk.startswith("*") and chunk.endswith("*") and len(chunk) > 2:
            run.text = chunk[1:-1]
            italic = True
        elif chunk.startswith("`") and chunk.endswith("`"):
            run.text = chunk[1:-1]
        else:
            run.text = chunk
        run.font.size = Pt(size)
        run.font.bold = bold
        run.font.italic = italic
        run.font.name = FONT
        run.font.color.rgb = color


def add_line(slide, y, width=BODY_W, color=RULE, height=Pt(1.2)):
    bar = slide.shapes.add_shape(1, ML, y, width, height)   # 1 = rectangle
    bar.fill.solid()
    bar.fill.fore_color.rgb = color
    bar.line.fill.background()
    bar.shadow.inherit = False
    return bar


def slide_title(slide, text):
    box = slide.shapes.add_textbox(ML, TOP_TITLE, BODY_W, Inches(0.72))
    tf = box.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    size = 27 if len(text) <= 26 else (24 if len(text) <= 36 else 21)
    inline(p, text, size, NAVY, bold_all=True)
    add_line(slide, Inches(1.24), Inches(1.6), ACCENT, Pt(3))


# ─────────────────────────────────────────────────────────────── 슬라이드 작성
def build_cover(prs, cover):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    band = slide.shapes.add_shape(1, Emu(0), Inches(2.28), W, Inches(0.10))
    band.fill.solid(); band.fill.fore_color.rgb = ACCENT
    band.line.fill.background(); band.shadow.inherit = False

    box = slide.shapes.add_textbox(ML, Inches(1.28), BODY_W, Inches(1.0))
    p = box.text_frame.paragraphs[0]
    inline(p, cover["title"], 42, NAVY, bold_all=True)

    box = slide.shapes.add_textbox(ML, Inches(2.56), BODY_W, Inches(0.8))
    box.text_frame.word_wrap = True
    p = box.text_frame.paragraphs[0]
    inline(p, cover["subtitle"], 21, ACCENT)

    box = slide.shapes.add_textbox(ML, Inches(3.30), BODY_W, Inches(0.44))
    p = box.text_frame.paragraphs[0]
    inline(p, f"버전 v{VERSION}  ·  {DATE}", 15, ACCENT)

    # 표지 아래 블록 — 저자를 머리로 두고 아래로 갈수록 작아진다
    SIZES = [21, 14, 12]                # 저자·소속 / AI 사용 고지 / 표기 원칙
    COLORS = [NAVY, MUTED, MUTED]       # 발행일은 부제 아래 버전 줄이 맡는다
    box = slide.shapes.add_textbox(ML, Inches(5.18), BODY_W, Inches(1.9))
    tf = box.text_frame
    tf.word_wrap = True
    for i, m in enumerate(cover["meta"]):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(7 if i == 0 else 3)
        size = SIZES[i] if i < len(SIZES) else SIZES[-1]
        color = COLORS[i] if i < len(COLORS) else COLORS[-1]
        inline(p, m, size, color, bold_all=(i == 0))


def build_section(prs, title):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    band = slide.shapes.add_shape(1, Emu(0), Inches(2.72), W, Inches(1.90))
    band.fill.solid(); band.fill.fore_color.rgb = NAVY
    band.line.fill.background(); band.shadow.inherit = False
    tf = band.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    inline(p, title, 32, WHITE, bold_all=True)


def build_body(prs, s):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    slide_title(slide, s["title"])

    # 분량에 따라 글자 크기를 낮춘다
    n_bul = sum(1 for k, _ in s["items"] if k in ("bullet", "para"))
    rows = sum(len(v) for k, v in s["items"] if k == "table")
    bsize = 15 if n_bul <= 5 else (13.5 if n_bul <= 8 else 12)
    tsize = 11.5 if rows <= 7 else (10.5 if rows <= 9 else 9.5)

    y = TOP_BODY
    for kind, payload in s["items"]:
        if kind in ("bullet", "para"):
            if kind == "bullet":
                level, text = payload
            else:
                level, text = 0, payload
            left = ML + Inches(0.26 * level)
            box = slide.shapes.add_textbox(left, y, BODY_W - Inches(0.26 * level), Inches(0.34))
            tf = box.text_frame
            tf.word_wrap = True
            tf.margin_top = tf.margin_bottom = 0
            p = tf.paragraphs[0]
            bullet = "· " if level else "— "
            inline(p, bullet + text, bsize, INK if not level else MUTED)
            est = 1 + int(len(text) * (bsize / 13.0) / 62)
            y += Inches(0.30 * est + 0.06)

        elif kind == "code":
            lines_c = [c for c in payload if c.strip()]
            h = Inches(0.26) * len(lines_c) + Inches(0.18)
            box = slide.shapes.add_shape(1, ML, y, BODY_W, h)
            box.fill.solid(); box.fill.fore_color.rgb = HEADFILL
            box.line.fill.background(); box.shadow.inherit = False
            tf = box.text_frame
            tf.word_wrap = True
            tf.margin_left = tf.margin_right = Inches(0.14)
            tf.margin_top = tf.margin_bottom = Inches(0.07)
            tf.vertical_anchor = MSO_ANCHOR.TOP
            tf.word_wrap = False
            for i, c in enumerate(lines_c):
                p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
                p.alignment = PP_ALIGN.LEFT
                p.space_after = Pt(1)
                run = p.add_run(); run.text = c
                run.font.size = Pt(12); run.font.name = "Menlo"
                run.font.color.rgb = NAVY
            y += h + Inches(0.14)

        elif kind == "table":
            data = payload
            ncol, nrow = len(data[0]), len(data)
            rh = Inches(0.30 if tsize >= 11 else 0.27)
            th = rh * nrow
            gtab = slide.shapes.add_table(nrow, ncol, ML, y, BODY_W, th).table
            widths = column_widths(data, ncol)
            for c, frac in enumerate(widths):
                gtab.columns[c].width = Emu(int(BODY_W * frac))
            for r, row in enumerate(data):
                gtab.rows[r].height = rh
                for c in range(ncol):
                    cell = gtab.cell(r, c)
                    cell.margin_left = cell.margin_right = Inches(0.06)
                    cell.margin_top = cell.margin_bottom = 0
                    cell.vertical_anchor = MSO_ANCHOR.MIDDLE
                    cell.fill.solid()
                    cell.fill.fore_color.rgb = HEADFILL if r == 0 else WHITE
                    tf = cell.text_frame
                    tf.word_wrap = True
                    p = tf.paragraphs[0]
                    txt = row[c] if c < len(row) else ""
                    inline(p, txt, tsize, NAVY if r == 0 else INK, bold_all=(r == 0))
            y += th + Inches(0.14)

    if s["source"]:
        box = slide.shapes.add_textbox(ML, Inches(6.74), BODY_W, Inches(0.34))
        tf = box.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        inline(p, s["source"], 10, MUTED)

    if y > BOTTOM_LIMIT:
        print(f"  ⚠️ 넘침 가능: {s['title'][:34]} (y={y/914400:.2f}in)")


def column_widths(data, ncol):
    """열 내용 길이에 비례해 폭을 나눈다 (최소 0.10)."""
    lens = []
    for c in range(ncol):
        m = max(len(row[c]) if c < len(row) else 0 for row in data)
        lens.append(max(m, 4))
    total = sum(lens)
    fr = [max(l / total, 0.10) for l in lens]
    scale = sum(fr)
    return [f / scale for f in fr]



# ─────────────────────────────────────────────────────────────── 머리말·꼬리말
def add_header_footer(prs):
    """표지를 제외한 모든 슬라이드에 머리말·꼬리말을 얹는다."""
    total = len(prs.slides._sldIdLst)
    for idx, slide in enumerate(prs.slides, start=1):
        if idx == 1:                      # 표지는 제외
            continue

        # 머리말 — 좌: 제목 / 우: 버전·일자
        box = slide.shapes.add_textbox(ML, Inches(0.13), BODY_W * 0.62, Inches(0.26))
        tf = box.text_frame; tf.margin_top = tf.margin_bottom = 0
        run = tf.paragraphs[0].add_run(); run.text = TITLE
        run.font.size = Pt(9); run.font.name = FONT; run.font.color.rgb = MUTED

        box = slide.shapes.add_textbox(ML + BODY_W * 0.62, Inches(0.13), BODY_W * 0.38, Inches(0.26))
        tf = box.text_frame; tf.margin_top = tf.margin_bottom = 0
        p = tf.paragraphs[0]; p.alignment = PP_ALIGN.RIGHT
        run = p.add_run(); run.text = f"v{VERSION}  ·  {DATE}"
        run.font.size = Pt(9); run.font.name = FONT; run.font.color.rgb = MUTED

        add_line(slide, Inches(0.40), BODY_W, RULE, Pt(0.75))

        # 꼬리말 — 좌: 저자·소속 / 우: 쪽수
        add_line(slide, Inches(7.08), BODY_W, RULE, Pt(0.75))

        box = slide.shapes.add_textbox(ML, Inches(7.14), BODY_W * 0.7, Inches(0.26))
        tf = box.text_frame; tf.margin_top = tf.margin_bottom = 0
        run = tf.paragraphs[0].add_run(); run.text = f"{AUTHOR}  ·  {AFFIL}"
        run.font.size = Pt(9); run.font.name = FONT; run.font.color.rgb = MUTED

        box = slide.shapes.add_textbox(ML + BODY_W * 0.7, Inches(7.14), BODY_W * 0.3, Inches(0.26))
        tf = box.text_frame; tf.margin_top = tf.margin_bottom = 0
        p = tf.paragraphs[0]; p.alignment = PP_ALIGN.RIGHT
        run = p.add_run(); run.text = f"{idx} / {total}"
        run.font.size = Pt(9); run.font.name = FONT; run.font.color.rgb = NAVY
        run.font.bold = True

# ─────────────────────────────────────────────────────────────── 이전 버전 보관
def archive_previous():
    moved = []
    for ext in ("pptx", "pdf", "md", "py"):
        for path in HERE.glob(f"{NUMBER}. *_v*.{ext}"):
            if path.name.startswith(BASE):
                continue
            HISTORY.mkdir(exist_ok=True)
            shutil.move(str(path), str(HISTORY / path.name))
            moved.append(path.name)
    if moved:
        print("  이전 버전을 __history__/ 로 옮겼습니다:", ", ".join(sorted(moved)))
        print("  ⛔ _CHANGE.md 를 작성하십시오 (직전 버전 대비 무엇을 왜 바꿨는가)")


# ─────────────────────────────────────────────────────────────── pdf 변환
def to_pdf(pptx_path, n_slides):
    exe = shutil.which("soffice") or "/Applications/LibreOffice.app/Contents/MacOS/soffice"
    if not Path(exe).exists():
        print("  ❌ soffice 를 찾지 못했습니다 — pdf 를 만들 수 없습니다.")
        print("     규칙상 pdf 없는 상태는 '완료' 가 아닙니다. 사용자에게 보고하십시오.")
        return False
    subprocess.run(
        [exe, "--headless", "--convert-to", "pdf", "--outdir", str(HERE), str(pptx_path)],
        check=True, capture_output=True,
    )
    pdf = HERE / f"{BASE}.pdf"
    if not pdf.exists():
        print("  ❌ pdf 가 생성되지 않았습니다.")
        return False
    pages = len(re.findall(rb"/Type\s*/Page[^s]", pdf.read_bytes()))
    print(f"  pdf: {pdf.name} ({pdf.stat().st_size/1024:.0f} KB, 페이지 추정 {pages})")
    if pages and pages != n_slides:
        print(f"  ⚠️ 페이지 수({pages}) 와 슬라이드 수({n_slides}) 가 다릅니다 — 변환 확인 필요")
    return True


# ─────────────────────────────────────────────────────────────── main
def main():
    md_path = HERE / f"{BASE}.md"
    if not md_path.exists():
        sys.exit(f"내용 원본이 없습니다: {md_path.name}")

    cover, slides = parse(md_path.read_text(encoding="utf-8"))
    archive_previous()

    prs = Presentation()
    prs.slide_width, prs.slide_height = W, H
    build_cover(prs, cover)
    for s in slides:
        if s["kind"] == "section":
            build_section(prs, s["title"])
        else:
            build_body(prs, s)

    add_header_footer(prs)

    pptx_path = HERE / f"{BASE}.pptx"
    prs.save(str(pptx_path))
    n = len(prs.slides.__iter__.__self__._sldIdLst)
    print(f"  pptx: {pptx_path.name} (슬라이드 {n}장)")
    ok = to_pdf(pptx_path, n)
    print("  동명 네 파일:", ", ".join(
        f".{e}{'' if (HERE / f'{BASE}.{e}').exists() else ' (없음)'}" for e in ("pptx", "pdf", "md", "py")))
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
