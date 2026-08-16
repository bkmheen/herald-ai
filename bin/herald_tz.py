#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""표시용 시간대 — **정렬·저장은 UTC, 보여줄 때만 현지시각.**

  왜 나누는가
    여러 호스트·여러 나라의 기록을 한 줄로 세우려면 기준이 하나여야 한다(UTC).
    그러나 사람이 읽을 때는 자기가 있는 곳의 시각이라야 뜻이 통한다.
    그래서 **저장된 값은 건드리지 않고 표시 단계에서만 바꾼다.**

  시간대 결정 순서
    1. `--tz` 인자          예) --tz Asia/Tokyo · --tz UTC · --tz local
    2. 환경변수 HERALD_TZ   해외에서 셸 한 번만 export 하면 전부 따라온다
    3. ~/.herald/vault.conf 의 DISPLAY_TZ
    4. 기본값 Asia/Seoul    주 작업지가 한국이다

  `local` 은 이 컴퓨터의 시스템 시간대를 쓴다 — 노트북을 들고 이동하면 그대로 따라간다.

  herald-index · herald-find 가 함께 쓴다. 실행 파일이 아니라 모듈이다.
"""
from __future__ import print_function

import datetime
import os

DEFAULT_TZ = "Asia/Seoul"
CONF = os.path.join(os.path.expanduser("~"), ".herald", "vault.conf")

try:                                  # 3.9+
    from zoneinfo import ZoneInfo
except ImportError:                   # 3.8 이하 — UTC 로만 보여 준다
    ZoneInfo = None


def _conf_tz():
    try:
        with open(CONF, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("DISPLAY_TZ="):
                    return line.partition("=")[2].strip().strip('"').strip("'")
    except (IOError, OSError):
        pass
    return None


def resolve(cli_tz=None):
    """쓸 시간대 이름을 정한다. 값을 검증하지는 않는다 (tzinfo 에서 판정)."""
    return (cli_tz or os.environ.get("HERALD_TZ") or _conf_tz() or DEFAULT_TZ)


def tzinfo(name):
    """(tzinfo, 표시이름) 을 돌려준다. 알 수 없는 이름이면 UTC 로 물러난다."""
    if not name or name.upper() == "UTC":
        return datetime.timezone.utc, "UTC"
    if name.lower() == "local":
        # 시스템 시간대. 이동 중인 노트북에서 가장 자연스럽다.
        local = datetime.datetime.now().astimezone().tzinfo
        return local, (datetime.datetime.now().astimezone().tzname() or "local")
    if ZoneInfo is None:
        return datetime.timezone.utc, "UTC"
    try:
        zone = ZoneInfo(name)
    except Exception:                 # 알 수 없는 지역 이름 — 지어내지 않고 UTC 로 둔다
        return datetime.timezone.utc, "UTC"
    label = name.rsplit("/", 1)[-1]   # Asia/Seoul → Seoul
    return zone, label


def label(name):
    """머리말·열 이름에 쓸 짧은 표기. 예) Asia/Seoul → KST"""
    zone, short = tzinfo(name)
    now = datetime.datetime.now(datetime.timezone.utc).astimezone(zone)
    abbr = now.tzname() or short
    # 숫자 오프셋(+09)만 나오는 환경도 있어 그때는 지역 이름을 쓴다
    if abbr.startswith(("+", "-")):
        abbr = short
    return abbr


def fmt(utc_text, name, with_tz=False, date_only=False):
    """'YYYY-MM-DDTHH:MMZ' → 지정 시간대의 'YYYY-MM-DD HH:MM'.

    값을 알 수 없으면 원문을 그대로 돌려준다 — 지어내지 않는다.

    `date_only` 는 **시각을 모르는 기록**(옛 파일명에서 날짜만 건진 경우)에 쓴다.
    그런 값은 00:00 UTC 로 채워 두었을 뿐이라 시간대를 옮기면 없는 시각이
    생기거나(09:00) 날짜가 하루 밀린다. 그래서 **변환하지 않고 날짜만** 보여 준다.
    """
    if not utc_text:
        return ""
    text = str(utc_text).strip()
    try:
        naive = datetime.datetime.strptime(text[:16], "%Y-%m-%dT%H:%M")
    except ValueError:
        return text
    if date_only:
        return naive.strftime("%Y-%m-%d")
    aware = naive.replace(tzinfo=datetime.timezone.utc)
    zone, _short = tzinfo(name)
    shown = aware.astimezone(zone)
    out = shown.strftime("%Y-%m-%d %H:%M")
    return "%s %s" % (out, label(name)) if with_tz else out
