#!/usr/bin/env python3
"""Shared Quest address mapping between the loaded transport image and runtime.

The loader copies three ranges of the loaded `QUEST1` image to their steady
runtime addresses. The mapping is derived from the included, hash-pinned
`analysis/runtime_memory_map.json`; no original binary is required.
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RUNTIME_MEMORY_MAP = REPO_ROOT / "analysis" / "runtime_memory_map.json"
RECONSTRUCTION_LEDGER = REPO_ROOT / "source_bbc" / "reconstruction.json"

QUEST1_LOAD_ADDRESS = 0x1D00
QUEST1_LENGTH = 0x3F20
RUNTIME_BASE = 0x0380


def _segments() -> list[tuple[int, int, int]]:
    document = json.loads(RUNTIME_MEMORY_MAP.read_text(encoding="utf-8"))
    segments = []
    for segment in document["steady_runtime_segments"]:
        segments.append(
            (
                segment["loaded_source_start"],
                segment["loaded_source_end_exclusive"],
                segment["destination_start"] - segment["loaded_source_start"],
            )
        )
    return sorted(segments)


SEGMENTS = _segments()


def loaded_to_runtime(address: int) -> int:
    """Map a loaded `$.QUEST1` address to its steady runtime address."""
    for start, end_exclusive, delta in SEGMENTS:
        if start <= address < end_exclusive:
            return address + delta
    raise ValueError(f"loaded address 0x{address:04x} is not relocated to runtime")


def runtime_to_loaded(address: int) -> int:
    """Map a steady runtime address back to its loaded `$.QUEST1` address."""
    for start, end_exclusive, delta in SEGMENTS:
        if start + delta <= address < end_exclusive + delta:
            return address - delta
    raise ValueError(f"runtime address 0x{address:04x} has no loaded origin")


def load_ledger() -> dict:
    return json.loads(RECONSTRUCTION_LEDGER.read_text(encoding="utf-8"))


def owned_loaded_ranges() -> list[tuple[int, int, str]]:
    """Source-owned code and data ranges from the ledger, in loaded order."""
    ledger = load_ledger()
    ranges = [
        (routine["loaded_start"], routine["loaded_end_exclusive"], routine["name"])
        for routine in ledger["routines"]
    ]
    ranges.extend(
        (data["loaded_start"], data["loaded_end_exclusive"], data["name"])
        for data in ledger.get("data_ranges", [])
    )
    ranges.sort()
    previous_end = 0
    for start, end_exclusive, name in ranges:
        if start < previous_end:
            raise ValueError(f"source-owned range for {name} overlaps its predecessor")
        previous_end = end_exclusive
    return ranges
