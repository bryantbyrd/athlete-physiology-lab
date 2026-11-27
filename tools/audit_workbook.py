#!/usr/bin/env python3
"""Audit an Excel workbook (.xlsx/.xlsm) for private residue before publication.

The workbook is opened read-only as a ZIP package; Excel is not required and
the file is never modified. Standard library only.

Checks (FAIL = must be fixed before the file is published):

  FAIL  author / last-modified-by names in document properties
  FAIL  absolute save path recorded in the workbook
  FAIL  absolute file paths anywhere, including Power Query source
  FAIL  sensor-ID-like names (queries, tables, connections, file names)
  FAIL  any term listed in the --terms file (one per line, case-insensitive)
  WARN  printer settings, comment authors, external links
  INFO  rows of cell data per sheet and cached chart points, for manual
        confirmation that only synthetic data remains
  FAIL  (with --expect-data) cached HR / RR columns that differ from the
        given synthetic hr.csv / rr.csv

Without --expect-data this tool cannot tell synthetic numbers from real ones.
With it, the cached recording is compared value for value against the
synthetic files the template was built from. Inspect the file in Excel too.

Usage:
    python3 tools/audit_workbook.py [--terms FILE] [--expect-data DIR] WORKBOOK

Exit status: 0 if no FAIL findings, 1 otherwise, 2 on usage errors.
"""

from __future__ import annotations

import argparse
import base64
import io
import re
import struct
import sys
import zipfile
from pathlib import Path

ABS_PATH = re.compile(
    r"""(?<![A-Za-z])[A-Za-z]:\\[^"<>|\r\n]{2,80}   # drive-letter path
      | \\\\[A-Za-z0-9._-]+\\[^"<>|\r\n]{2,80}      # \\server\share
      | /(?:home|Users|mnt|Volumes|media)/[^"<>\s]{2,80}
    """,
    re.VERBOSE,
)
# Eight hexadecimal characters attached to a stream suffix or a sensor name.
DEVICE_ID = re.compile(
    r"\b(?!0{8})[0-9A-Fa-f]{8}_(?:hr|rr|ecg|acc|ppg)\b"
    r"|Polar[ _-]?H10[ _-](?!0{8})[0-9A-Fa-f]{8}\b"
)
PLACEHOLDER_PATH = re.compile(r"\\path\\to\\|/path/to/", re.IGNORECASE)


class Report:
    def __init__(self) -> None:
        self.items: list[tuple[str, str]] = []

    def add(self, level: str, message: str) -> None:
        self.items.append((level, message))

    def count(self, level: str) -> int:
        return sum(1 for lvl, _ in self.items if lvl == level)


def snippet(text: str, start: int, end: int, pad: int = 12) -> str:
    return text[max(0, start - pad): end + pad].replace("\n", " ").strip()


def mashup_formulas(raw: bytes) -> dict[str, str]:
    """Return {part name: text} from a Power Query DataMashup item.

    Covers the M source of every query and the trailing metadata section
    (query settings, load targets), which can also carry names.
    """
    text = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8", "replace")
    match = re.search(r"<DataMashup[^>]*>(.*?)</DataMashup>", text, re.S)
    if not match:
        return {}
    blob = base64.b64decode(match.group(1))
    (length,) = struct.unpack_from("<I", blob, 4)
    package = zipfile.ZipFile(io.BytesIO(blob[8: 8 + length]))
    found = {
        name: package.read(name).decode("utf-8", "replace")
        for name in package.namelist()
        if name.endswith(".m")
    }
    found["metadata"] = blob[8 + length:].decode("utf-8", "ignore")
    return found


def scan_text(label: str, text: str, terms: list[str], report: Report) -> None:
    seen: set[str] = set()
    for match in ABS_PATH.finditer(text):
        found = match.group(0)
        if PLACEHOLDER_PATH.search(found) or found in seen:
            continue
        seen.add(found)
        report.add("FAIL", f"{label}: absolute path: {snippet(text, *match.span(), pad=0)}")
    for match in DEVICE_ID.finditer(text):
        found = match.group(0)
        if found in seen:
            continue
        seen.add(found)
        report.add("FAIL", f"{label}: sensor-ID-like name: {found}")
    lowered = text.lower()
    for term in terms:
        if term.lower() in lowered:
            report.add("FAIL", f"{label}: private term present: {term!r} ({lowered.count(term.lower())}x)")


def compare_cached_data(package: zipfile.ZipFile, workbook_xml: str, folder: Path, report: Report) -> None:
    """Compare the cached HR and RR query tables with synthetic CSV files."""
    import csv

    sheet_names = re.findall(r'<sheet name="([^"]+)"', workbook_xml)
    for sheet, filename, columns in (("RR", "rr.csv", (0, 2)), ("HR", "hr.csv", (0, 2))):
        source = folder / filename
        if sheet not in sheet_names or not source.is_file():
            report.add("FAIL", f"--expect-data: cannot compare sheet {sheet!r} with {filename}")
            continue
        xml = package.read(f"xl/worksheets/sheet{sheet_names.index(sheet) + 1}.xml").decode("utf-8", "replace")
        with source.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.reader(handle))[1:]
        for index in columns:
            letter = "ABCDEFGH"[index]
            cached = re.findall(rf'<c r="{letter}\d+"(?![^>]*t="s")[^>]*><v>([^<]+)</v>', xml)
            expected = [row[index] for row in rows]
            if cached == expected:
                report.add("PASS", f"sheet {sheet!r} column {letter}: {len(cached)} cached values identical to {filename}")
            else:
                report.add("FAIL", f"sheet {sheet!r} column {letter}: cached values differ from {filename} "
                                   f"({len(cached)} cached, {len(expected)} expected)")


def audit(path: Path, terms: list[str], expect_data: Path | None = None) -> Report:
    report = Report()
    with zipfile.ZipFile(path) as package:
        names = package.namelist()

        # --- document properties ------------------------------------------
        if "docProps/core.xml" in names:
            core = package.read("docProps/core.xml").decode("utf-8", "replace")
            for tag, label in (("dc:creator", "author"), ("cp:lastModifiedBy", "last modified by")):
                match = re.search(rf"<{tag}>(.*?)</{tag}>", core, re.S)
                if match and match.group(1).strip():
                    report.add("FAIL", f"document properties: {label} is set ({len(match.group(1).strip())} characters)")
        if "docProps/app.xml" in names:
            app = package.read("docProps/app.xml").decode("utf-8", "replace")
            for tag in ("Company", "Manager"):
                match = re.search(rf"<{tag}>(.*?)</{tag}>", app, re.S)
                if match and match.group(1).strip():
                    report.add("FAIL", f"document properties: {tag} is set")
        if any(n.startswith("docProps/custom") for n in names):
            report.add("WARN", "custom document properties present; review them")

        # --- workbook-level residue ---------------------------------------
        workbook = package.read("xl/workbook.xml").decode("utf-8", "replace")
        if "absPath" in workbook:
            report.add("FAIL", "workbook.xml records the absolute folder it was saved in (absPath)")

        # --- every text part ----------------------------------------------
        for name in names:
            if name in ("docProps/core.xml",):
                continue
            data = package.read(name)
            if name.startswith("customXml/item") and b"DataMashup" in data.replace(b"\x00", b""):
                for part, source in mashup_formulas(data).items():
                    scan_text(f"Power Query ({part})", source, terms, report)
                continue
            if name.endswith((".xml", ".rels", ".vml")):
                text = data.decode("utf-8", "replace")
                if name == "xl/workbook.xml":
                    text = re.sub(r"<x15ac:absPath[^>]*/>", "", text)  # reported above
                scan_text(name, text, terms, report)
            elif name.endswith(".bin"):
                # VBA project and printer settings: search both common encodings.
                for encoding in ("cp1252", "utf-16-le"):
                    text = data.decode(encoding, "ignore")
                    lowered = text.lower()
                    for term in terms:
                        if term.lower() in lowered:
                            report.add("FAIL", f"{name}: private term present: {term!r}")
                    if name.endswith("vbaProject.bin"):
                        for match in DEVICE_ID.finditer(text):
                            report.add("FAIL", f"{name}: sensor-ID-like name: {match.group(0)}")

        # --- things to review ---------------------------------------------
        printers = [n for n in names if n.startswith("xl/printerSettings/")]
        if printers:
            report.add("WARN", f"{len(printers)} printer-settings part(s) present; these can name a local printer")
        if any(n.startswith("xl/persons/") or n.startswith("xl/threadedComments/") for n in names):
            report.add("WARN", "threaded comments / person list present; these carry author identities")
        if any(n.startswith("xl/comments") for n in names):
            report.add("WARN", "cell comments present; check their authors and text")
        if any(n.startswith("xl/externalLinks/") for n in names):
            report.add("WARN", "external workbook links present")

        # --- data volume, for manual confirmation -------------------------
        sheet_names = re.findall(r'<sheet name="([^"]+)"', workbook)
        sheet_parts = sorted(
            (n for n in names if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n)),
            key=lambda n: int(re.search(r"\d+", n.rsplit("/", 1)[1]).group()),
        )
        for index, part in enumerate(sheet_parts):
            xml = package.read(part).decode("utf-8", "replace")
            rows = len(re.findall(r"<row ", xml))
            values = len(re.findall(r"<v>", xml))
            label = sheet_names[index] if index < len(sheet_names) else part
            report.add("INFO", f"sheet {label!r}: {rows} rows, {values} stored cell values")
        cached = 0
        for name in names:
            if re.fullmatch(r"xl/charts/chart\d+\.xml", name):
                cached += len(re.findall(r"<c:pt ", package.read(name).decode("utf-8", "replace")))
        report.add("INFO", f"charts: {cached} cached data points")
        if expect_data is not None:
            compare_cached_data(package, workbook, expect_data, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("workbook", type=Path)
    parser.add_argument("--terms", type=Path,
                        help="file of private terms, one per line (# for comments)")
    parser.add_argument("--expect-data", type=Path, metavar="DIR",
                        help="folder with the synthetic hr.csv and rr.csv the workbook "
                             "was built from; cached data must match them exactly")
    args = parser.parse_args()

    if not args.workbook.is_file():
        print(f"not a file: {args.workbook}", file=sys.stderr)
        return 2
    terms: list[str] = []
    if args.terms:
        if not args.terms.is_file():
            print(f"terms file not found: {args.terms}", file=sys.stderr)
            return 2
        terms = [
            line.strip()
            for line in args.terms.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]

    try:
        report = audit(args.workbook, terms, args.expect_data)
    except zipfile.BadZipFile:
        print("not a ZIP-based workbook (.xlsx/.xlsm)", file=sys.stderr)
        return 2

    for level in ("FAIL", "WARN", "PASS", "INFO"):
        for lvl, message in report.items:
            if lvl == level:
                print(f"{level}  {message}")
    fails = report.count("FAIL")
    print()
    if args.expect_data is not None:
        tail = "Cached recording compared with the synthetic files given by --expect-data."
    else:
        tail = ("Sheets and charts listed under INFO must contain synthetic data only; "
                "without --expect-data this tool cannot verify that.")
    print(f"{fails} failure(s), {report.count('WARN')} warning(s). {tail}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
