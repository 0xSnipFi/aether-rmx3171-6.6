#!/usr/bin/env python3
"""Minimal single-entry Android DTBO image packer.

This is intentionally small: AETHER only needs one RMX3171 overlay entry when
the host does not have AOSP's mkdtimg available.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


DT_TABLE_MAGIC = 0xD7B7AB1E
DTB_MAGIC = b"\xd0\x0d\xfe\xed"
HEADER_SIZE = 32
ENTRY_SIZE = 32
ENTRY_COUNT = 1
ENTRIES_OFFSET = HEADER_SIZE
DT_OFFSET = HEADER_SIZE + ENTRY_SIZE


def parse_u32(value: str) -> int:
    parsed = int(value, 0)
    if parsed < 0 or parsed > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError(f"{value!r} is outside u32 range")
    return parsed


def build_image(input_path: Path, output_path: Path, page_size: int, entry_id: int, rev: int) -> None:
    dtbo = input_path.read_bytes()
    if not dtbo.startswith(DTB_MAGIC):
        raise SystemExit(f"{input_path} is not a valid DTB/DTBO blob")

    total_size = DT_OFFSET + len(dtbo)
    if total_size > 0xFFFFFFFF:
        raise SystemExit("DTBO image is too large for dt_table_header")

    header = struct.pack(
        ">8I",
        DT_TABLE_MAGIC,
        total_size,
        HEADER_SIZE,
        ENTRY_SIZE,
        ENTRY_COUNT,
        ENTRIES_OFFSET,
        page_size,
        0,
    )
    entry = struct.pack(
        ">8I",
        len(dtbo),
        DT_OFFSET,
        entry_id,
        rev,
        0,
        0,
        0,
        0,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(header + entry + dtbo)


def main() -> None:
    parser = argparse.ArgumentParser(description="Pack one DTBO into an Android dt_table image")
    parser.add_argument("output", type=Path)
    parser.add_argument("input", type=Path)
    parser.add_argument("--page-size", type=parse_u32, default=2048)
    parser.add_argument("--id", type=parse_u32, default=0)
    parser.add_argument("--rev", type=parse_u32, default=0)
    args = parser.parse_args()

    build_image(args.input, args.output, args.page_size, args.id, args.rev)


if __name__ == "__main__":
    main()
