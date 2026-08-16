#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""호스트 대장 입출력 — `herald-host` 와 `herald-find` 가 함께 쓴다.

  대장은 vault `conventions/hosts.yaml` 이다.
  machine_id 가 1차 키이고 이름·주소는 이력으로만 쌓인다 — 자세한 뜻은 herald-host 참조.

  YAML 전체를 다루지 않는다. **우리가 쓰는 형태만** 읽고 쓴다 —
  최상위 목록, 두 단계 들여쓰기, 인라인 사전. 외부 의존을 두지 않기 위해서다.
  실행 파일이 아니라 모듈이다.
"""
from __future__ import print_function

import os

LEDGER_REL = os.path.join("conventions", "hosts.yaml")

KNOWN_SCALARS = ("role", "tier_read", "platform", "first_seen", "last_seen")
LIST_KEYS = ("names", "addrs", "aliases")

HEADER = """# 참여 호스트 대장 — herald-host 가 관리한다
#
#   machine_id 가 1차 키다. 이름·주소는 바뀌므로 **이력으로만** 남긴다.
#   herald-host observe 가 관측한 값을 더하기만 하며, 옛 값을 지우지 않는다.
#
#   role       admin   = 전부 읽고 vault 를 직접 편집·push
#              general = 투입구로 올리기만 한다
#   tier_read  all | some | none
#   aliases    기기를 교체해 machine_id 가 바뀌었을 때, 사용자가 선언한 옛 식별자
#              (herald-host alias <옛> <새>) — 도구가 추정하지 않는다
#
#   이 파일은 herald-host 가 다시 쓴다. 손으로 고친 주석은 남지 않는다.
"""


def _scalar(raw):
    v = raw.strip()
    # 줄 끝 주석을 값에 섞지 않는다 (`role: admin   # 설명` → `admin`).
    if v and v[0] not in ("'", '"'):
        cut = v.find(" #")
        if cut >= 0:
            v = v[:cut].strip()
    if v == "" or v.lower() in ("null", "~"):
        return None
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        return v[1:-1]
    return v


def _inline_dict(text):
    out = {}
    inner = text.strip()
    if inner.startswith("{") and inner.endswith("}"):
        inner = inner[1:-1]
    for part in inner.split(","):
        if ":" not in part:
            continue
        k, _, v = part.partition(":")
        out[k.strip()] = _scalar(v)
    return out


def ledger_path(vault):
    return os.path.join(vault, LEDGER_REL)


def load(path):
    """대장을 읽어 항목 목록으로 돌려준다. 없으면 빈 목록."""
    if not os.path.isfile(path):
        return []
    entries, cur, pending = [], None, None
    try:
        fh = open(path, "r", encoding="utf-8")
    except (IOError, OSError):
        return []
    with fh:
        for raw in fh:
            line = raw.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if stripped.startswith("- ") and not line.startswith("    "):
                cur = {}
                entries.append(cur)
                pending = None
                stripped = stripped[2:]
            if cur is None:
                continue
            if stripped.startswith("- {") or (stripped.startswith("- ") and pending):
                if pending:
                    cur.setdefault(pending, []).append(_inline_dict(stripped[2:]))
                continue
            if ":" in stripped:
                k, _, v = stripped.partition(":")
                k = k.strip()
                if v.strip() == "":
                    pending = k
                    cur.setdefault(k, [])
                else:
                    pending = None
                    cur[k] = _scalar(v)
    return entries


def _emit_dict(d, order):
    keys = [k for k in order if k in d] + [k for k in d if k not in order]
    return "{%s}" % ", ".join("%s: %s" % (k, d[k]) for k in keys if d[k] is not None)


def save(path, entries):
    lines = [HEADER]
    for e in entries:
        lines.append("- machine_id: %s" % e.get("machine_id", ""))
        for key in KNOWN_SCALARS:
            if e.get(key):
                lines.append("  %s: %s" % (key, e[key]))
        # 모르는 열쇠도 그대로 살린다 — 도구가 이해하지 못한다고 사용자의 기록을 지우지 않는다
        for key in sorted(e):
            if key in KNOWN_SCALARS or key in LIST_KEYS or key == "machine_id":
                continue
            if isinstance(e[key], (list, dict)) or e[key] is None:
                continue
            lines.append("  %s: %s" % (key, e[key]))
        for key, order in (("names", ("name", "since")),
                           ("addrs", ("ip", "since", "iface", "net")),
                           ("aliases", ("machine_id", "since", "note"))):
            items = e.get(key) or []
            if not items:
                continue
            lines.append("  %s:" % key)
            for it in items:
                lines.append("    - %s" % _emit_dict(it, order))
        lines.append("")
    text = "\n".join(lines).rstrip("\n") + "\n"
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, path)


# ── 조회 ────────────────────────────────────────────────────────────────
def names_of(e):
    return [n.get("name") for n in (e.get("names") or []) if n.get("name")]


def ips_of(e):
    return [a.get("ip") for a in (e.get("addrs") or []) if a.get("ip")]


def alias_ids_of(e):
    return [a.get("machine_id") for a in (e.get("aliases") or []) if a.get("machine_id")]


def resolve(entries, query):
    """이름·IP·machine_id·옛 machine_id 무엇으로 물어도 같은 항목을 찾는다."""
    q = str(query).strip()
    ql = q.lower()
    hits = []
    for e in entries:
        if (e.get("machine_id") or "").lower() == ql:
            hits.append(e)
        elif ql in [a.lower() for a in alias_ids_of(e)]:
            hits.append(e)
        elif ql in [n.lower() for n in names_of(e)]:
            hits.append(e)
        elif q in ips_of(e):
            hits.append(e)
    return hits


def aliases_for(vault, query):
    """질의어와 **같은 호스트로 묶이는 이름 전부**를 소문자 집합으로 돌려준다.

    대장이 없거나 걸리지 않으면 질의어 자신만 담아 돌려준다 —
    대장이 없다고 검색이 실패하면 안 된다.
    """
    base = {str(query).strip().lower()}
    try:
        entries = load(ledger_path(vault))
    except Exception:
        return base
    for e in resolve(entries, query):
        for n in names_of(e):
            base.add(n.lower())
    return base
