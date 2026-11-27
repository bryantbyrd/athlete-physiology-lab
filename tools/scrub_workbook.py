#!/usr/bin/env python3
"""Remove residue that Excel writes on every save from a workbook template.

Excel records the folder a workbook was saved in, the author names, and (per
sheet) binary printer settings that can name a local printer. These cannot be
switched off from inside Excel, so this tool rewrites the package:

  * drops the absolute save path (x15ac:absPath) from xl/workbook.xml
  * empties creator / lastModifiedBy in docProps/core.xml
  * removes xl/printerSettings/* together with the relationships and
    pageSetup references that point at them

Every other part is copied byte for byte. The input file is never modified.
Standard library only.

Usage:
    python3 tools/scrub_workbook.py INPUT.xlsm OUTPUT.xlsm

Run tools/audit_workbook.py on the output afterwards, and open it in Excel.
"""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

PRINTER_REL = "relationships/printerSettings"


def scrub(src: Path, dst: Path) -> list[str]:
    notes: list[str] = []
    with zipfile.ZipFile(src) as zin:
        names = zin.namelist()
        parts = {name: zin.read(name) for name in names}
        infos = {info.filename: info for info in zin.infolist()}

    # --- absolute save path ------------------------------------------------
    workbook = parts["xl/workbook.xml"].decode("utf-8")
    cleaned, count = re.subn(
        r"<mc:AlternateContent\b(?:(?!</mc:AlternateContent>).)*?absPath"
        r"(?:(?!</mc:AlternateContent>).)*?</mc:AlternateContent>",
        "", workbook, flags=re.S,
    )
    if count:
        parts["xl/workbook.xml"] = cleaned.encode("utf-8")
        notes.append("removed absolute save path from xl/workbook.xml")

    # --- author names ------------------------------------------------------
    if "docProps/core.xml" in parts:
        core = parts["docProps/core.xml"].decode("utf-8")
        cleaned = core
        for tag in ("dc:creator", "cp:lastModifiedBy"):
            cleaned = re.sub(rf"<{tag}>.*?</{tag}>", f"<{tag}></{tag}>", cleaned, flags=re.S)
        if cleaned != core:
            parts["docProps/core.xml"] = cleaned.encode("utf-8")
            notes.append("emptied author fields in docProps/core.xml")

    # --- printer settings --------------------------------------------------
    removed = 0
    for rels_name in [n for n in names if re.fullmatch(r"xl/worksheets/_rels/sheet\d+\.xml\.rels", n)]:
        rels = parts[rels_name].decode("utf-8")
        ids = []
        for match in re.finditer(r"<Relationship\b[^>]*?/>", rels):
            element = match.group(0)
            if PRINTER_REL in element:
                ids.append(re.search(r'\bId="([^"]+)"', element).group(1))
                rels = rels.replace(element, "")
        if not ids:
            continue
        parts[rels_name] = rels.encode("utf-8")
        sheet_name = "xl/worksheets/" + rels_name.rsplit("/", 1)[1][: -len(".rels")]
        sheet = parts[sheet_name].decode("utf-8")
        for rel_id in ids:
            sheet, hits = re.subn(
                rf'(<pageSetup\b[^>]*?)\s+r:id="{re.escape(rel_id)}"', r"\1", sheet)
            removed += hits
        parts[sheet_name] = sheet.encode("utf-8")
    printer_parts = [n for n in names if n.startswith("xl/printerSettings/")]
    for name in printer_parts:
        del parts[name]
    if printer_parts:
        notes.append(f"removed {len(printer_parts)} printer-settings part(s) "
                     f"and {removed} page-setup reference(s)")

    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zout:
        for name in names:
            if name not in parts:
                continue
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = infos[name].external_attr
            zout.writestr(info, parts[name])
    return notes


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().split("Usage:")[1].split("\n\n")[0].strip(), file=sys.stderr)
        return 2
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    if not src.is_file():
        print(f"not a file: {src}", file=sys.stderr)
        return 2
    if src.resolve() == dst.resolve():
        print("input and output must be different files", file=sys.stderr)
        return 2
    dst.parent.mkdir(parents=True, exist_ok=True)
    for note in scrub(src, dst) or ["nothing to remove"]:
        print(note)
    print(f"wrote {dst} ({dst.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
