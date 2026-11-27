#!/usr/bin/env python3
"""Prepare a staged recording (hr.csv, rr.csv) for publication.

Only the clock time is changed. Every timestamp (`rx_unix_ms`) in both files
is shifted by one constant so that the earliest one falls exactly on
00:00:00.000 UTC of the --date given. Differences between timestamps, and
therefore elapsed time, are preserved to the millisecond. Every other column
(heart rate, R-R intervals, frame counters, flags) is copied byte for byte.

What is removed or never read:
  * the real recording start time (the shift is not written anywhere);
  * the sensor ID and the archive name (the output files are named hr.csv and
    rr.csv; the input names are not copied);
  * session.json and markers.csv (not read at all).

After writing, the output is re-read and checked: same headers, same number
of rows, every non-timestamp value identical, every timestamp difference
identical. The tool refuses to overwrite its input.

Usage:
    python3 tools/deidentify_recording.py --date 2026-11-26 IN_DIR OUT_DIR

IN_DIR holds hr.csv and rr.csv as staged by scripts/sleep_import.
Standard library only.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

HEADERS = {
    "hr.csv": "rx_unix_ms,frame,hr_bpm,corrected_hr_bpm,ppg_quality,rr_available,contact,contact_supported",
    "rr.csv": "rx_unix_ms,frame,rr_ms",
}


def read(path: Path) -> tuple[str, list[list[str]]]:
    text = path.read_bytes().decode("utf-8")
    if "\r" in text:
        raise SystemExit(f"{path.name}: unexpected CR line endings")
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    header, body = lines[0], [line.split(",") for line in lines[1:]]
    if header != HEADERS[path.name]:
        raise SystemExit(f"{path.name}: unexpected header: {header}")
    width = header.count(",") + 1
    for number, row in enumerate(body, start=2):
        if len(row) != width or not row[0].isdigit():
            raise SystemExit(f"{path.name}: malformed line {number}")
    return header, body


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--date", required=True, help="publication date label, YYYY-MM-DD (UTC)")
    parser.add_argument("in_dir", type=Path)
    parser.add_argument("out_dir", type=Path)
    args = parser.parse_args()

    if args.in_dir.resolve() == args.out_dir.resolve():
        print("OUT_DIR must differ from IN_DIR", file=sys.stderr)
        return 2
    anchor_day = datetime.strptime(args.date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    anchor_ms = int(anchor_day.timestamp() * 1000)

    data = {name: read(args.in_dir / name) for name in HEADERS}
    earliest = min(int(row[0]) for _, body in data.values() for row in body)
    shift = earliest - anchor_ms

    args.out_dir.mkdir(parents=True, exist_ok=True)
    for name, (header, body) in data.items():
        out = [header] + [",".join([str(int(row[0]) - shift)] + row[1:]) for row in body]
        (args.out_dir / name).write_bytes(("\n".join(out) + "\n").encode("utf-8"))

    # --- verification ------------------------------------------------------
    for name, (header, body) in data.items():
        new_header, new_body = read(args.out_dir / name)
        assert new_header == header, name
        assert len(new_body) == len(body), name
        assert all(a[1:] == b[1:] for a, b in zip(body, new_body)), f"{name}: values changed"
        old_t = [int(r[0]) for r in body]
        new_t = [int(r[0]) for r in new_body]
        assert all(o - n == shift for o, n in zip(old_t, new_t)), f"{name}: elapsed time changed"
        span = (new_t[-1] - new_t[0]) / 60000
        print(f"{name}: {len(new_body)} rows; values identical; elapsed time preserved "
              f"({span:.2f} min from first to last row)")
    first = min(int(r[0]) for _, b in (read(args.out_dir / n) for n in HEADERS) for r in b)
    print(f"earliest timestamp now {datetime.fromtimestamp(first / 1000, timezone.utc):%Y-%m-%d %H:%M:%S} UTC")
    return 0


if __name__ == "__main__":
    sys.exit(main())
