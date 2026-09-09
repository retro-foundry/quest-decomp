# `update_and_draw_room_enemies` contract

## Authority and scope

- Machine: BBC Micro Model B, NMOS 6502.
- Runtime source-owned bytes: `$3563-$35C1`.
- Loaded source-owned bytes: `$4D63-$4DC1` in
  `original/game/$.QUEST1`.
- Source-owned range SHA-256:
  `7f13d72fd25dcaa844f673dde3c4195602172165be5bb14f733b8092477137fe`.
- Static authority: the relocated runtime binary, `pcode/game.pcode.json`, and
  the already source-owned drawing, probing, range, movement, and interaction
  callees.
- Runtime authority: the committed play traces and the focused
  `indexed_entity_player_overlap` checkpoint.

The name stays at the observable data structure: Y walks even indexes through
the same state arrays consumed by the indexed-entity helpers. Although the
renderer has separately been identified with the room enemies, this contract
does not assign species-specific meanings to the three behavior modes.

## Boundary and control flow

The observed caller is `JSR $3563` at `$2243`. The routine returns to `$2246`
through the shared `$3425-$3429` tail, which clears `$6C` before its `RTS`.
It starts Y from `$1222`, processes one entity, subtracts two, and repeats while
Y remains non-negative.

Each iteration optionally draws the old XOR image when `$61` is nonzero, then
dispatches on the shared type byte at `$1221`:

1. Type `$00` loads the indexed coordinates and calls the `$2B9E` player-range
   entry, which supplies its own `$08/$0A/$19` box.
2. Type `$02` performs collision-aware movement first, clamps both deltas, and
   calls the `$35E8` player-range tail with the narrower `$05/$01/$10` box. A
   miss skips the common movement because this entity has already moved.
3. Every other type calls `reflect_indexed_entity_at_obstacles`, whose shared
   tail supplies the same `$05/$01/$10` player-range test.

When either range test returns carry set, `$31/$32` are copied to the entity's
Y-indexed `$123A/$123B` deltas, making its next step point toward the player.
The common path clamps both deltas and moves on both axes. Finally the routine
reloads the indexed coordinates, applies the player-overlap action with a
sixteen-row extent, and draws the current XOR image.

## Runtime evidence

The committed natural traces execute 36 of the 37 instructions. Together they
cover the bat, small-robot, and moth dispatches, old-image draw and skip, player-range hit and
miss, both movement arrangements, player interaction, redraw, iteration, and
the shared tail return. Their only missing instruction was the moth
carry-set jump at `$3584`.

The focused checkpoint starts at the first natural `$3563` entry after cycle
204,800,000 in the hash-pinned key/door replay. The natural call has two moth
entities and selects Y=`$02` first. Writing only `$006A=$45` and `$1233=$00`
aligns that entity with the unchanged player. Its natural clear vertical step
leaves it inside the supplied player-range box, so `$3584` executes once and
the common pursuit path copies `$31=$FF` and `$32=$02` into `$123C/$123D`
before moving again.

The complete two-entity call returns from `$3429` to `$2246` after 9,972 cycles
and 2,426 Quest instructions. It changes 176 logical-memory bytes including 104
screen bytes, changes the rendered display, and does not change Video ULA or
CRTC state. Authority and rebuilt calls match exactly for caller, entry and
return registers, return address, PC sequence, complete memory effect, display
effect, and video-hardware effect. The two entry writes are a bounded branch
oracle, not a claim that the overlap occurs naturally in a particular room.

## Reconstruction acceptance

BeebAsm must emit these 95 bytes at loaded `$4D63-$4DC1`:

```text
ac 22 12 a5 61 f0 03 20 32 35 ad 21 12 f0 1b c9
02 d0 11 20 fa 35 20 ed 36 20 a1 36 20 e8 35 90
2a 4c 93 35 20 c2 35 4c 93 35 20 7f 36 20 03 22
90 0d a5 31 99 3a 12 a5 32 99 3b 12 4c a5 35 20
a1 36 20 ed 36 20 ba 36 20 08 37 20 7f 36 a9 10
85 41 20 06 22 20 32 35 88 88 10 a7 4c 25 34
```

The complete `$.QUEST1` payload and rebuilt SSD must remain byte-identical to
their authorities.
