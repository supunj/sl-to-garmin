#!/usr/bin/env python3
"""Split a monolithic mkgmap TYP text file into per-type files.

Reads a monolithic TYP text file (default: build/drive66.txt, produced by
assemble_typ.sh from the segment tree) and writes, relative to the device
segment root (default: typ/drive66/):

    common/common.txt            [_id] and [_drawOrder] sections
    polygon/<type>.txt           one file per [_polygon] section
    line/<type>.txt              one file per [_line] section
    point/<type>-<sub-type>.txt  one file per [_point] section

Type/sub-type names are taken verbatim from the section (e.g. 0x01,
0x10603), so filenames stay hex like the source file.

Usage:
    test/split_typ.py [input-file] [output-root]
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = REPO_ROOT / "build" / "drive66.txt"
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "typ" / "drive66"

SECTION_START = re.compile(r"^\[(_id|_drawOrder|_polygon|_line|_point)\]$", re.IGNORECASE)
SECTION_END = re.compile(r"^\[end\]$", re.IGNORECASE)
TYPE_RE = re.compile(r"^Type=(0x[0-9a-fA-F]+)\s*$")
SUBTYPE_RE = re.compile(r"^SubType=(0x[0-9a-fA-F]+)\s*$")


def parse_sections(path):
    """Yield (kind, lines) for each section, keeping the section's own text."""
    kind = None
    lines = []
    with open(path, encoding="cp1252") as f:
        for raw in f:
            line = raw.rstrip("\n")
            start = SECTION_START.match(line)
            if start:
                if kind is not None:
                    raise ValueError(f"section [{kind}] not closed before {line}")
                kind = start.group(1).lower()
                lines = [line]
            elif SECTION_END.match(line):
                if kind is None:
                    raise ValueError(f"[end] without section at: {line}")
                lines.append(line)
                yield kind, lines
                kind = None
                lines = []
            elif kind is not None:
                lines.append(line)
            # comments/blank lines outside sections (banner headers) are dropped
    if kind is not None:
        raise ValueError(f"file ends inside section [{kind}]")


def section_key(kind, lines):
    """Return (subdir, filename) for a section's lines."""
    type_value = None
    subtype_value = None
    for line in lines:
        m = TYPE_RE.match(line)
        if m and type_value is None:
            type_value = m.group(1)
        m = SUBTYPE_RE.match(line)
        if m and subtype_value is None:
            subtype_value = m.group(1)

    if kind in ("_id", "_draworder"):
        return None  # collected into common.txt
    if type_value is None:
        raise ValueError(f"section [{kind}] has no Type= line")

    if kind == "_polygon":
        return "polygon", f"{type_value}.txt"
    if kind == "_line":
        return "line", f"{type_value}.txt"
    if kind == "_point":
        return "point", f"{type_value}-{subtype_value or '0x00'}.txt"
    raise ValueError(f"unknown section kind {kind}")


def main():
    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_INPUT
    output_root = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT_ROOT

    common_parts = []
    written = {}  # subdir -> count
    seen_names = set()

    for kind, lines in parse_sections(input_path):
        key = section_key(kind, lines)
        if key is None:
            common_parts.append(lines)
            continue
        subdir, name = key
        full_key = f"{subdir}/{name}"
        if full_key in seen_names:
            raise ValueError(f"duplicate section would overwrite {full_key}")
        seen_names.add(full_key)

        out_dir = output_root / subdir
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / name).write_text("\n".join(lines) + "\n", encoding="cp1252")
        written[subdir] = written.get(subdir, 0) + 1

    common_dir = output_root / "common"
    common_dir.mkdir(parents=True, exist_ok=True)
    common_text = "\n\n".join("\n".join(part) for part in common_parts) + "\n"
    (common_dir / "common.txt").write_text(common_text, encoding="cp1252")

    print(f"common -> common/common.txt ({len(common_parts)} sections)")
    for subdir in ("polygon", "line", "point"):
        print(f"{subdir} -> {subdir}/ ({written.get(subdir, 0)} files)")


if __name__ == "__main__":
    main()
