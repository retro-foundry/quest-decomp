# Quest BBC Micro source

This directory contains the standalone, byte-exact BeebAsm reconstruction of
the BBC Micro `$.QUEST1` payload.

## Source files

- `quest1.asm` contains every instruction, table, string, room-map byte,
  graphic, sprite, and initial state byte in the payload.
- `memory_map.inc` names the MOS interfaces, hardware registers, constants,
  runtime state, data ranges, and routine entry points used by the source.
- `reconstruction.json` records the source-owned ranges and the evidence level
  assigned to each reconstructed range.

The build has no `INCBIN`, generated layout include, extracted binary slice, or
dependency on the original disk image. The original payload remains the byte
authority represented by the expected length and SHA-256 in `validate.ps1`.

Sprite names describe the decoded artwork. Room-local enemies are bats, small
bouncing robots, and moths. The separate per-level cross-room subsystem draws
small bouncing robots on levels 0-7 and ghosts on levels 8-9. Jellyfish, fish,
mice, caterpillars, lifts, and moth-shaped hazards belong to other descriptor
tables and must not be inferred to share that cross-room behavior.

## Build and validate

From the repository root:

```powershell
./build.ps1
./validate.ps1
```

Pass `-BeebAsm <path>` to either command when BeebAsm is not on `PATH`.
Generated files are written below ignored `build/reconstruction/`:

- `QUEST1` is the rebuilt DFS payload.
- `quest1.labels` is the generated BeebAsm symbol map.

Validation checks all maintained `tools/` and `source_bbc/` file references,
parses every bundled Python file and gameplay-variant JSON definition, builds
the payload, smoke-applies a bundled variant, and requires the rebuilt QUEST1
length and SHA-256 to match the original exactly.

## Gameplay variants

The canonical source always rebuilds the original game. Reproducible gameplay
changes are applied after assembly by `tools/reconstruction/apply_variant.py`.
Variant definitions live under `../tools/reconstruction/variants/` and include
their expected original bytes so a stale or incompatible patch fails loudly.

Use `tools/reconstruction/make_start_room_variant.py` to generate a start-room
variant. Its optional position search uses
`tools/runtime_trace/find_start_point.py`. These tools are bundled and are also
exercised or syntax-checked by `validate.ps1`.

## Source conventions

- Preserve NMOS 6502 behavior and the original byte layout.
- Use named constants and addresses from `memory_map.inc` in executable code.
- Keep relocation addresses only where they document `ORG`, `COPYBLOCK`,
  `CLEAR`, assertions, or another layout invariant.
- Describe decoded graphics and proven behavior in names and comments; do not
  infer movement, collision, or puzzle meaning from artwork alone.
- Keep uncertain data structural or dataflow-labelled until stronger evidence
  exists.
- Keep source and comments ASCII-only.
