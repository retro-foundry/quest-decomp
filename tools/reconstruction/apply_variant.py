#!/usr/bin/env python3
"""Build a deliberately modified Quest payload from the byte-exact reconstruction.

The reconstruction's whole guarantee is that it rebuilds the original bytes
exactly, so a gameplay change must not be made by editing quest1.asm. A
variant is instead a named list of patches applied to the finished payload,
each stating the runtime address, the bytes it expects to find, and the bytes
to write. A patch whose expected bytes do not match is refused, so a variant
cannot silently rot as the reconstruction advances.

    python tools/reconstruction/apply_variant.py --variant sector_e_level_1
    python tools/reconstruction/apply_variant.py --variant sector_e_level_1 --set start_sector=5

By default this writes a patched QUEST1 payload without requiring copyrighted
original media. Pass --base-disc to place that payload into a user-supplied SSD.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import quest_addr as addr

VARIANTS = Path(__file__).resolve().parent / "variants"
BUILD = addr.REPO_ROOT / "build" / "reconstruction"
PAYLOAD = BUILD / "QUEST1"
QUEST1_MEDIA_OFFSET = 18432


class VariantError(ValueError):
    """The variant cannot be applied to this payload."""


def parse_bytes(text: str) -> bytes:
    return bytes(int(part, 16) for part in text.split())


def apply_patches(payload: bytearray, patches: list[dict], overrides: dict[str, int]) -> list[str]:
    applied = []
    for patch in patches:
        runtime = int(patch["runtime_address"], 16)
        expected = parse_bytes(patch["expect"])
        replacement = parse_bytes(patch["write"])
        if len(expected) != len(replacement):
            raise VariantError(
                f"{patch['name']}: expect and write differ in length"
            )
        name = patch.get("parameter")
        if name and name in overrides:
            value = overrides[name]
            if not 0 <= value <= 0xFF:
                raise VariantError(f"{name} must be a byte, got {value}")
            index = patch.get("parameter_offset", 0)
            replacement = (
                replacement[:index] + bytes([value]) + replacement[index + 1:]
            )
        offset = addr.runtime_to_loaded(runtime) - addr.QUEST1_LOAD_ADDRESS
        found = bytes(payload[offset:offset + len(expected)])
        if found != expected:
            raise VariantError(
                f"{patch['name']}: runtime ${runtime:04X} holds "
                + " ".join(f"{b:02x}" for b in found)
                + ", expected "
                + " ".join(f"{b:02x}" for b in expected)
                + ". The reconstruction has changed under this variant."
            )
        payload[offset:offset + len(replacement)] = replacement
        applied.append(
            f"{patch['name']}: runtime ${runtime:04X} "
            + " ".join(f"{b:02x}" for b in expected)
            + " -> "
            + " ".join(f"{b:02x}" for b in replacement)
        )
    return applied


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--variant", required=True)
    parser.add_argument("--set", action="append", default=[], metavar="NAME=VALUE",
                        help="repeatable; override a named patch parameter")
    parser.add_argument(
        "--output-payload",
        type=Path,
        help="patched QUEST1 output (default: build/reconstruction/QUEST1-NAME)",
    )
    parser.add_argument(
        "--base-disc",
        type=Path,
        help="optional Quest SSD to wrap the patched payload in",
    )
    parser.add_argument(
        "--output-disc",
        type=Path,
        help="disc output; requires --base-disc",
    )
    arguments = parser.parse_args()

    definition = VARIANTS / f"{arguments.variant}.json"
    if not definition.exists():
        print(f"no such variant: {definition}", file=sys.stderr)
        return 1
    if not PAYLOAD.exists():
        print("build the byte-exact payload first: ./build.ps1", file=sys.stderr)
        return 1

    overrides: dict[str, int] = {}
    for pair in arguments.set:
        name, _, value = pair.partition("=")
        if not value:
            print(f"--set needs NAME=VALUE, got {pair!r}", file=sys.stderr)
            return 1
        overrides[name] = int(value, 0)

    document = json.loads(definition.read_text(encoding="utf-8"))
    payload = bytearray(PAYLOAD.read_bytes())
    original = bytes(payload)
    try:
        applied = apply_patches(payload, document["patches"], overrides)
    except VariantError as exc:
        print(f"variant {arguments.variant} refused: {exc}", file=sys.stderr)
        return 1

    output_payload = arguments.output_payload or (BUILD / f"QUEST1-{arguments.variant}")
    output_payload.parent.mkdir(parents=True, exist_ok=True)
    output_payload.write_bytes(payload)

    output_disc = None
    if arguments.output_disc and not arguments.base_disc:
        print("--output-disc requires --base-disc", file=sys.stderr)
        return 1
    if arguments.base_disc:
        if not arguments.base_disc.is_file():
            print(f"base disc does not exist: {arguments.base_disc}", file=sys.stderr)
            return 1
        output_disc = arguments.output_disc or (BUILD / f"Quest-{arguments.variant}.ssd")
        disc = bytearray(arguments.base_disc.read_bytes())
        end = QUEST1_MEDIA_OFFSET + len(payload)
        if len(disc) < end:
            print(
                f"base disc is too short: need at least {end} bytes, got {len(disc)}",
                file=sys.stderr,
            )
            return 1
        disc[QUEST1_MEDIA_OFFSET:end] = payload
        output_disc.parent.mkdir(parents=True, exist_ok=True)
        output_disc.write_bytes(disc)

    changed = sum(1 for a, b in zip(original, payload) if a != b)
    print(f"variant: {document['name']}")
    print(f"  {document['description']}")
    for line in applied:
        print(f"  {line}")
    print(f"changed {changed} payload byte(s)")
    print(f"payload: {output_payload}")
    if output_disc:
        print(f"disc: {output_disc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
