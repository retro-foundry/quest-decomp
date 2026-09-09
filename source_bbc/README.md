# Quest 6502 reconstruction

This directory rebuilds the BBC Micro `$.QUEST1` payload as NMOS 6502 machine
code. The original payload remains the byte authority. Reconstruction proceeds
one bounded routine at a time:

1. unresolved ranges are temporarily included from `original/game/$.QUEST1`;
2. a reconstructed routine is written as BeebAsm source at its original loaded
   address;
3. assembly-time assertions enforce the original start and end addresses; and
4. the built payload is byte-compared with the authority before a bootable SSD
   is produced.

The required end state is stricter: `quest1.asm` plus `memory_map.inc` must
contain every code and data byte needed to assemble `$.QUEST1`. The final
payload build must not read the authority file, generated slices, or an
`INCBIN`. Named data belongs in explicit `EQUB`/string/table blocks with its
record shape documented; unknown content must be labelled honestly until its
code/data boundary is proved.

`source_bbc/reconstruction.json` is the canonical complete routine list.
`quest1.asm` currently reconstructs 132 routines covering 5,878 bytes. The
routines highlighted in detail below include:

- runtime `$0BA0-$0BA8`, loaded `$24A0-$24A8`,
  `write_system_clock_via_osword_02`;
- runtime `$0C6E-$0CEC`, loaded `$256E-$25EC`,
  `run_startup_room_sequence_until_space`, including its inline prompt;
- runtime `$125D-$1268`, loaded `$2A5D-$2A68`,
  `write_twelve_video_ula_palette_entries`;
- runtime `$1269-$1283`, loaded `$2A69-$2A83`,
  `write_four_video_ula_palette_entries`;
- runtime `$1CE4-$1D51`, loaded `$34E4-$3551`,
  `copy_16_byte_graphic_to_display`, including its embedded pointer table;
- runtime `$1D52-$1D68`, loaded `$3552-$3568`,
  `copy_graphic_byte_to_display`;
- runtime `$1E29-$1E3E`, loaded `$3629-$363E`, `draw_item_graphic_pair`;
- runtime `$1E3F-$1E6B`, loaded `$363F-$366B`,
  `show_golden_dragon_ending`, including its inline VDU message;
- runtime `$3245-$3254`, loaded `$4A45-$4A54`,
  `restore_item_and_goal_records`;
- runtime `$3256-$327D`, loaded `$4A56-$4A7D`,
  `print_inline_vdu_stream`, including its stack-rewritten return;
- runtime `$1E6C-$1F0E`, loaded `$366C-$370E`,
  `initialise_room_moving_objects`;
- runtime `$2453-$2470`, loaded `$3C53-$3C70`,
  `collect_power_crystal_and_refill_energy`;
- runtime `$2237-$223A`, loaded `$3A37-$3A3A`,
  `run_game_tick_with_flag_88_cleared`;
- runtime `$25C4-$25DB`, loaded `$3DC4-$3DDB`,
  `apply_3a_3b_difference_to_4b`;
- runtime `$265A-$2781`, loaded `$3E5A-$3F81`,
  `poll_controls_and_apply_gameplay_actions`;
- runtime `$2790-$2796`, loaded `$3F90-$3F96`, `osbyte_81_inkey`;
- runtime `$2893-$2898`, loaded `$4093-$4098`,
  `prepare_player_relative_display_scan`;
- runtime `$2899-$28A6`, loaded `$4099-$40A6`,
  `set_display_pointer_three_mode1_rows_below_player`;
- runtime `$28EF-$290A`, loaded `$40EF-$410A`,
  `advance_player_vertical_position_and_display_pointer`;
- runtime `$290B-$293E`, loaded `$410B-$413E`,
  `scan_display_column_for_blocking_byte`;
- runtime `$293F-$2956`, loaded `$413F-$4156`,
  `adjust_display_pointer_then_scan_markers`;
- runtime `$2957-$29A1`, loaded `$4157-$41A1`,
  `scan_four_display_bytes_for_markers`;
- runtime `$2A35-$2A4D`, loaded `$4235-$424D`,
  `check_player_relative_display_pattern_15`;
- runtime `$2AFD-$2B23`, loaded `$42FD-$4323`, `enter_room_below`;
- runtime `$2B57-$2B87`, loaded `$4357-$4387`,
  `check_player_candidate_bounds_overlap`;
- runtime `$2E44-$2E7B`, loaded `$4644-$467B`,
  `update_and_draw_two_indexed_pairs`;
- runtime `$2E7C-$2E91`, loaded `$467C-$4691`,
  `handle_matching_indexed_pair`;
- runtime `$2E92-$2EA9`, loaded `$4692-$46A9`,
  `draw_directional_indexed_pair_if_matching`;
- runtime `$30AC-$30CD`, loaded `$48AC-$48CD`,
  `toggle_first_indexed_pair_mode_when_positions_match`;
- runtime `$2EAA-$2EDC`, loaded `$46AA-$46DC`,
  `draw_indexed_pair_if_reference_matches`;
- runtime `$2EDD-$2EED`, loaded `$46DD-$46ED`,
  `test_indexed_pair_matches_reference`;
- runtime `$2EEE-$2F11`, loaded `$46EE-$4711`,
  `set_indexed_pair_value_delta_at_thresholds`;
- runtime `$2F12-$2F8E`, loaded `$4712-$478E`,
  `advance_indexed_pair_value_and_display_pointer`;
- runtime `$32A7-$32BE`, loaded `$4AA7-$4ABE`,
  `test_display_pointer_in_xor_draw_window`; and
- runtime `$32C5-$32D0`, loaded `$4AC5-$4AD0`,
  `select_graphic_then_xor_draw`; and
- runtime `$32D1-$3332`, loaded `$4AD1-$4B32`,
  `xor_graphic_into_display`; and
- runtime `$3343-$334B`, loaded `$4B43-$4B4B`,
  `configure_two_row_repeated_xor_graphic`; and
- runtime `$343A-$3452`, loaded `$4C3A-$4C52`,
  `reverse_room_moving_object_delta_at_limits`; and
- runtime `$3453-$3487`, loaded `$4C53-$4C87`,
  `draw_room_moving_object`; and
- runtime `$3488-$34BA`, loaded `$4C88-$4CBA`,
  `advance_room_moving_object_state_and_pointer`; and
- runtime `$3563-$35C1`, loaded `$4D63-$4DC1`,
  `update_and_draw_room_enemies`; and
- runtime `$35FA-$362D`, loaded `$4DFA-$4E2D`,
  `advance_indexed_entity_with_collision_checks`.

The display routines' boundaries, callers, fixed palette values,
pointer/selector rules, byte order, destination advance, and register effects
are recorded in
`analysis/reconstruction/write_twelve_video_ula_palette_entries_contract.md`,
`analysis/reconstruction/copy_16_byte_graphic_to_display_contract.md` and
`analysis/reconstruction/copy_graphic_byte_to_display_contract.md`. The
committed initial-render trace proves both forward and reversed-within-halves
16-byte copies, the byte helper's normal copy path, and destination pointer-page
carry. The optional `EOR #$90`, record-`$12` substitution, and `$0880` pointer
base remain static-only contracts.

Paired focused checkpoints prove the twelve-entry palette routine in both
startup and active-gameplay hardware states. Each call executes the same 50
instructions in 171 cycles and returns `A=$D3` with `X` and `Y` preserved.
The startup call changes the previously black palette and visible display; the
gameplay call has no net hardware or display change because the mapping is
already current.

The system-clock wrapper loads OSWORD `$02` and block address `$0E00`, then
tail-jumps to MOS. Five committed no-input calls prove its fixed four-
instruction handoff. A focused full MOS round trip from `$254D` to `$2550`
takes 243 cycles/77 instructions, leaves the zero-filled five-byte block
unchanged, and matches every workspace/stack, register, display, and hardware
effect. See
`analysis/reconstruction/write_system_clock_via_osword_02_contract.md`.

The startup room sequence reads sixteen packed room references backwards from
the table at `$0CED`, draws and ticks each room, prints its inline
`" PRESS SPACE "` prompt at tick `$28`, and exits through the shared stack
cleanup when MOS INKEY reports Space. Focused checkpoints cover its multiply
carry, inline stream, inner expiry, outer expiry, and restart paths with exact
authority/rebuild state, memory, display, PC, and video-hardware effects.

The game-tick wrapper loads and stores zero at `$88`, then falls through to
the original dispatcher at `$223B` without changing the caller's stack frame.
Five committed calls prove the two-instruction sequence from sole observed
caller `$2553`. A focused full-tick call returns to `$2556` after 155,487
cycles/47,894 traced instructions with exact 198-byte memory, 160-byte screen,
and video-hardware effects. The passive trace sees `$88` already zero, so its
higher-level meaning remains deliberately unassigned. See
`analysis/reconstruction/run_game_tick_with_flag_88_cleared_contract.md`.

The `$25C4` arithmetic helper computes the byte difference `$3A-$3B`. An
equal pair takes the adjacent fixed-`$0C` return for `$4B`; an unequal pair
copies `$3B` to `$3A` and subtracts the difference from `$4B`. A non-negative
result returns through the shared preceding `RTS`, while a negative result is
also stored at `$9F` before falling through to `$25DC`. Five natural equality
calls and paired explicit-state captures cover all three transfers. See
`analysis/reconstruction/apply_3a_3b_difference_to_4b_contract.md`.

The crystal-collection routine decrements the twelve-diamond count, performs
the final-crystal `$A2` decrement when that count reaches zero, plays the
collection sound, refills energy, removes the matching status diamond, stamps
the room cell, and tail-transfers to the status-divider redraw. The title text
provides the twelve-crystal, disappearing-diamond, energy-bonus, and final
force-field semantics. A natural call and a `$2A=$01` focused checkpoint cover
all twelve instructions with exact complete authority/rebuild effects. See
`analysis/reconstruction/collect_power_crystal_and_refill_energy_contract.md`.

The player-relative pointer helper adds `$0780`, or three Mode 1 character
rows, from `$38/$39` into `$7C/$7D`. Focused no-input and X checkpoints prove
the `$7460->$7BE0` no-carry case and `$42C0->$4A40` low-byte-carry case. All 21
calls in the committed no-input, X, and Z trace windows satisfy the 16-bit
formula. See
`analysis/reconstruction/set_display_pointer_three_mode1_rows_below_player_contract.md`.

The adjacent wrapper calls that pointer helper and then tail-jumps to the
sourced display scanner at `$2957`, preserving the outer caller's return
address. The committed no-input/X/Z traces prove 21 complete transfers, and a
focused outer call proves its exact 114-cycle/39-instruction downstream path
with seven memory changes and no display or hardware effect. The wrapper's
other static entry paths remain unobserved. See
`analysis/reconstruction/prepare_player_relative_display_scan_contract.md`.

The vertical player-state wrapper copies `$2C/$38/$39` through candidate bytes
`$3C/$3E/$3F`, calls the original `$34F1` signed-step helper, then copies the
result back. Eleven Z-after-X calls prove two-unit position advances and exact
two-scanline pointer motion, including three `$027A` BBC row transitions. A
focused 98-cycle/32-instruction call attributes all 14 wrapper instructions
post-source and matches every complete effect. See
`analysis/reconstruction/advance_player_vertical_position_and_display_pointer_contract.md`.

The display-column blocking scan tests `$7C/$7D` through the sourced window
predicate, accepts out-of-window, zero, and `$C0` positions, and returns carry
set on another in-window nonzero byte. Each accepted position advances through
the BBC interleaved display layout by low-byte increment or exact `$0279` row
step. X/Z traces prove 140 reads/tests, 111 low-byte increments, 19 row steps,
and ten occupied returns. Natural, forced-`$C0`, and forced-window checkpoints
cover every instruction and branch with exact complete effects. See
`analysis/reconstruction/scan_display_column_for_blocking_byte_contract.md`.

The pointer-adjustment wrapper tests the low three bits of `$7C`. An
unaligned pointer decrements only its low byte and falls through to `$2957`;
an aligned pointer subtracts `$0279` with full borrow propagation and jumps to
the same scanner. Seven committed X-path calls prove the decrement path.
Focused calls prove `$7C06->$7C05` and forced `$7C08-$0279=$798F`, with all
12 body instructions collectively covered and exact complete downstream
effects. See
`analysis/reconstruction/adjust_display_pointer_then_scan_markers_contract.md`.

The four-byte scanner checks the display pointer, then reads offsets
`$00/$08/$10/$18` and distinguishes zero, `$C0`, `$0A`, `$05`, `$44`, and
other nonzero values. Thirty-nine committed calls prove ten occupied-byte and
29 all-zero results across tail, direct, and fall-through entries. A four-case
state matrix covers pointer rejection and every marker/action branch; three
post-source checkpoints attribute 43/66/23 instructions to the new range with
exact complete effects. The marker bytes' gameplay identities remain
unclaimed. See
`analysis/reconstruction/scan_four_display_bytes_for_markers_contract.md`.

The player-relative pattern wrapper aligns `$38/$39` to a 16-byte boundary,
adds `$0795` into `$7C/$7D`, and submits selector `$15` to the original
display-pattern test at `$2A4E`. Five no-input calls compute `$7460->$7BF5`
and return through the shared carry-clear exit. A focused 148-cycle/46-
instruction call and the 11-frame post-source run are exact. Pointer carry and
the carry-set tail transfer to `$337B` remain static-only. See
`analysis/reconstruction/check_player_relative_display_pattern_15_contract.md`.

The player/candidate overlap guard performs four exact N-flag bounds checks.
Nonzero `$6C` selects extent `$17` and advances `$3C` by six; a failed bound
returns carry clear through `$2B35`, while a complete overlap falls through to
the original action at `$2B88`. The committed no-input trace covers 15 shared
returns, and a bounded six-case state matrix exercises both mode paths, every
rejection point, and the success fall-through. A focused comparison through
the real outer `$2E7C` call executes 98 cycles/33 instructions with all 31
instructions in the three sourced ranges owned and exact. See
`analysis/reconstruction/check_player_candidate_bounds_overlap_contract.md`.

The two-entry indexed-pair updater loops over X=`$00/$02`, conditionally
erases and redraws each pair, advances an indexed countdown, applies the
sourced delta/match/value-pointer helpers, then clears repeated-source mode and
carry before returning. Five natural calls and four forced-state cases cover
every branch, including the external `$3009` tail path. Fresh Ghidra ownership
keeps `$3003-$3008` with that alternate updater rather than this contiguous
source range. The natural post-source call is exact for 6,673 cycles/2,081
Quest instructions, 73 changed bytes, and 52 screen bytes. See
`analysis/reconstruction/update_and_draw_two_indexed_pairs_contract.md`.

The shared INKEY wrapper preserves the caller's negative key number in X,
loads Y=`$FF` and OSBYTE function `$81`, then tail-jumps to MOS `$FFF4`. The
no-input trace proves 65 complete handoffs from 13 control-poll call sites. A
focused call proves the full MOS round trip from `$2660` to `$2663`, with all
three Quest instructions source-owned and exact memory, register, display, and
video-hardware effects. See
`analysis/reconstruction/osbyte_81_inkey_contract.md`.

The control dispatcher polls documented Z/X movement, SPACE, jet-thrust,
RETURN, pause, P, exit, sound, and last-chance chord controls; applies movement;
ticks slow damage; clears transient state; and subtracts gravity. Deterministic
replays and a focused state checkpoint execute 136 of its 137 instructions.
The remaining `$26C3` call follows an INKEY -90 loop that has no exit key on a
Model B, so it is retained byte-exactly under a machine-scoped unreachable
declaration. See
`analysis/reconstruction/poll_controls_and_apply_gameplay_actions_contract.md`.

The indexed-pair predicate compares `$222B+X` with `$90`, then—only after a
match—compares `$8A+X` with `$8F`. It returns carry set exactly when both
fields match. The no-input trace proves 15 full matches and 15 first-field
mismatches; paired focused checkpoints prove the exact 26-cycle/eight-
instruction and 18-cycle/five-instruction paths with no memory, display, or
hardware effects. A second-field-only mismatch remains static-only. See
`analysis/reconstruction/test_indexed_pair_matches_reference_contract.md`.

The adjacent matching-pair handler gates its work through that predicate. On
a match it copies `$222F+X` to `$11`, stores the halved modulo-256 result of
`$2230+X + 8` at `$3C`, then tail-jumps to the sourced `$2B57` guard. On a
mismatch it returns through the shared carry-clear exit at `$2E7A`. The
no-input trace covers five calls on each path; focused calls and an 11-frame
post-source run match the authority exactly. The wider identities of the
fields and the guard's downstream action remain unclaimed. See
`analysis/reconstruction/handle_matching_indexed_pair_contract.md`.

The indexed-pair draw helper derives graphic selector `$10/$12` from bit 1 of
`$222F+X`, sets two renderer rows, and draws through the sourced XOR renderer
only when the pair predicate matches. Twenty no-input calls cover both selector
choices on both predicate outcomes. Focused match/mismatch calls take 3,029/74
cycles and 948/23 instructions, with exact 61/3-byte memory and 48/0-byte
screen effects. `$74` is zero on all ten natural draw paths, so its optional
`$80+X` clear remains static-only. See
`analysis/reconstruction/draw_indexed_pair_if_reference_matches_contract.md`.

The following threshold helper compares the indexed primary field with two
selectors, then checks the indexed value against the corresponding threshold.
Static flow proves conditional `$01/$FF` stores to the adjacent delta field;
the no-input trace covers five calls through each no-write comparison exit.
Focused 25-cycle and 33-cycle calls plus an 11-frame post-source run are exact.
The unmatched-selector and both store paths remain static-only. See
`analysis/reconstruction/set_indexed_pair_value_delta_at_thresholds_contract.md`.

The adjacent indexed-pair step adds `$222C+X` to `$222F+X`, moves the paired
little-endian display pointer at `$99/$9A+X` by `+8` or `-8`, wraps across
indexed primary fields, and reverses at endpoints 0/7. Ten no-input calls prove
five ordinary paths in each direction and exact value/pointer sequences; the
committed Z-after-X trace also proves one lower non-terminal wrap. Focused
ordinary calls take 59/58 cycles and 18/17 instructions, while focused
Z-replay call 8 proves the wrap in 79 cycles/22 instructions with four exact
state changes. Upper wrap, endpoint reversals, and the static tail entry remain
qualified. See
`analysis/reconstruction/advance_indexed_pair_value_and_display_pointer_contract.md`.

The XOR renderer's pointer predicate returns carry clear exactly for
`$7C/$7D` in `$4180-$7FFF`. The committed no-input trace exercises its short
accepted path 485 times, while the `$4180` boundary and carry-set paths remain
byte-proven static contracts. A focused call from `$2963` executes seven
instructions in 20 cycles with no memory, display, or hardware effect. See
`analysis/reconstruction/test_display_pointer_in_xor_draw_window_contract.md`.

The graphic-selection wrapper uses `X` to load an adjacent-byte pointer from
run-time table `$0B5F/$0B60`, preserves the input accumulator, and falls
through to the XOR renderer at `$32D1`. The no-input trace proves 30
selections across six observed indices. Two focused calls prove alternate
`X=$12`/`$10` selections (`$0660`/`$0640`) and exact original/rebuilt display
effects. See
`analysis/reconstruction/select_graphic_then_xor_draw_contract.md`.

The XOR renderer processes one or two observed eight-scanline character rows,
XORing four Mode 1 bytes at offsets `$00/$08/$10/$18`. Across the committed
no-input, X, and Z traces, 116 calls make 5,632 exact XOR stores and prove both
normal source advance and repeated-source-scanline modes. Focused no-input and
X-path captures are exact end to end. Clipped display scanlines and a
source-pointer page carry remain static-only paths. See
`analysis/reconstruction/xor_graphic_into_display_contract.md`.

The adjacent configuration helper writes repeated-source mode `$01` and row
count `$02` for that renderer. The no-input trace contains 20 complete calls
from `$347A`; one extra entry hit is an IRQ accepted while PC already equals
`$3343`, not another call. A focused checkpoint proves the exact five-
instruction, 16-cycle state transition and its two zero-page writes. The
second static caller at `$3544` remains unobserved. See
`analysis/reconstruction/configure_two_row_repeated_xor_graphic_contract.md`.

The room-moving-object delta-limit helper compares Y-indexed selector state with the
inclusive `$1D/$46` limits. Ten committed calls prove its no-match path, while
focused calls 52 and 77 in the same no-input replay naturally prove reversal
to `$01` at the lower limit and `$FF` at the upper limit. Both write paths,
register/flag effects, and absence of display/hardware effects match the
authority exactly. See
`analysis/reconstruction/reverse_indexed_xor_graphic_delta_at_limits_contract.md`.

The room-moving-object draw wrapper maps Y-indexed `$122A/$64` state to all four observed
even graphic selectors, loads a Y-indexed display pointer from `$43/$44`, and
tail-calls the proven selector and renderer. The no-input trace contains 20
complete calls split across callers `$33C7/$3403`; focused captures cover
opposite selector branches and exact two-row display effects. The global
one-row bypass remains static-only. See
`analysis/reconstruction/draw_indexed_xor_graphic_contract.md`.

The adjacent room-moving-object updater adds its Y-indexed `$01/$FF` delta to selector state and
moves the paired 16-bit display pointer by `+8/-8` according to delta sign.
All ten no-input calls are checked byte for byte; they split 5/5 by direction
and include a positive pointer-page carry. Focused calls prove both directions
and no display/hardware side effect. Negative borrow and other delta/Y values
remain static-only. See
`analysis/reconstruction/advance_indexed_xor_graphic_state_and_pointer_contract.md`.

The indexed-entity collision dispatcher chooses one of two vertical probes,
uses the vertical mover when clear, and otherwise probes in the signed
horizontal direction before tail-calling the horizontal mover. The natural
key/door replay covers 19 of its 20 instructions over 3,752 calls. A bounded
checkpoint supplies a blocked vertical route and blocked positive-direction
horizontal route, executes the missing reversal at `$361D`, and matches the
authority exactly for PCs, registers, complete memory, display, and video
hardware. See
`analysis/reconstruction/advance_indexed_entity_with_collision_checks_contract.md`.

The enclosing room-enemy update loop walks backward over even-numbered slots
and selects bat, small-robot, and moth movement/range behaviors through
`active_enemy_species`. Natural
traces cover 36 of 37 instructions across all three dispatches. A two-byte
coordinate checkpoint makes the first moth overlap the player after
its natural vertical step, covering `$3584` and the pursuit-delta copy path.
The complete two-entity call, including XOR redraw and player interaction,
matches the authority exactly. See
`analysis/reconstruction/update_and_draw_indexed_entities_contract.md` (the
filename retains the earlier structural name for stable evidence links).

`memory_map.inc` is the shared, human-maintained map of names promoted from
evidence. It includes proven zero-page state, MOS vectors and calls, BBC device
registers, display ranges, and relocated Quest routine entries. Reconstructed
routines are assembled at their runtime addresses and copied into the loaded
payload, so these names remain correct even when a routine contains absolute
references to another runtime routine or datum.

Build from the repository root:

```powershell
source_bbc/build.ps1
source_bbc/validate.ps1
```

Outputs are written below ignored `build/reconstruction/`:

- `QUEST1` — rebuilt DFS payload;
- `Quest-rebuilt.ssd` — copy of the authoritative disk with only `$.QUEST1`
  replaced;
- `quest1.labels` — BeebAsm symbol map; and
- `disc-build.json` — exact hashes and changed-byte accounting.

`validate.ps1` also performs the paired original/rebuilt workbench capture,
then requires the rebuilt run's complete 64 KiB emulator state at cycle
31,100,000 to match the committed oracle byte for byte.

The workbench can also capture an ordinary JSR/RTS routine call at exact entry
and return boundaries. That focused view compares registers and flags, the full
logical 64 KiB address space, selected RAM ranges, saved Video ULA/CRTC state,
and a display rendered from the checkpoint itself. See
`tools/reconstruction_workbench/README.md` for checkpoint options and limits.

Later work should replace another bounded transitional span with code or named
data. Do not present uncertain bytes as understood assembly merely because they
disassemble cleanly; identify them as unresolved code/data and continue the
evidence work until they can be named accurately.
