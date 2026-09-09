# Quest room map

Rooms are named across then down: the letter is `$90` (A = 0 through H = 7) and
the digit is `$8F` (0 through 9), so `E1` is `$90 = 4`, `$8F = 1`. Eight across
is proved by `$18AA` being exactly eight bytes indexed by `$90`; ten down by the
`$78` level stride. The game opens in `B0`.

Two kinds of statement are mixed below and kept apart deliberately.

- **Reported** is the player's account of playing the game. It is testimony:
  useful, and the reason most of the tables below were found at all, but not
  proof.
- **Payload** is what the authority image says, with the address that says it.

Where the two disagree the disagreement is recorded rather than resolved.

## What the payload proves about the grid

| Table | Address | Shape | What it holds |
| --- | --- | --- | --- |
| `room_appearance_table` | `$09B0` | 80 bytes, `$8F * 8 + $90` | palette nibble and tile-pair index per room |
| `item_and_goal_record_table` | `$0900` | 12 records of 4 | eleven item-indexed records plus the Golden Dragon ending at index 3 |
| `indexed_xor_room_record_table` | `$0930` | 16 records of 5 | room-specific type, display row, and position limits for four indexed XOR graphics |
| `initial_item_and_goal_record_table` | `$0980` | 12 records of 4 | new-game image copied over the mutable `$0900` records by `$3245` |
| `room_enemy_record_table` | `$0A00` | 20 records of 6 | bat, small bouncing robot, or moth enemies, per room |
| `second_room_entity_record_table` | `$0A96` | 20 records of 5 | the second entity class, per room |
| `indexed_pair_record_table` | `$0A78` | 10 records of 3, by `$8F` | one roaming pair per level |
| `across_to_password_number` | `$18AA` | 8 bytes, by `$90` | which password a column carries |

A record's room comes from the packed pair `match_packed_record_against_references`
tests: byte 0's low six bits are `$8F` and byte 1's low nibble is `$90`.

## Palette groups, and the reactors

`load_room_palette_and_tile_pair` takes the low nibble of the appearance byte as
the lower-screen palette. Grouping all eighty rooms by it:

| Palette | Rooms | Reported character |
| --- | --- | --- |
| `0` | H7 | passage to the lower maze |
| `2` | E0 F0 B1 C2 G2 H3 C4 F4 G4 A5 C5 D5 E5 G5 D6 C7 G8 E9 F9 H9 | 20 rooms, mixed |
| `3` | A0 B0 C1 E1 F1 B2 E2 C3 D3 A4 B4 F5 H5 B6 B7 E7 H8 G9 | 18 rooms, mixed |
| `5` | H1 F3 E4 E6 G6 G7 A9 | Teleport, Chemical Supplies, Oracle, water |
| `6` | C0 D0 G0 H0 D1 G1 A2 D2 F2 A3 B3 E3 G3 H4 B5 F6 H6 D7 F7 B8 C8 D8 E8 F8 B9 C9 D9 | 27 rooms, mixed |
| `7` | A1 H2 A6 | square-key door, Joke Shop, platform/spikes |
| `9` | D4 | password SALLY |
| `A` | **A8** | **"PRAY AT NOON" clue — a decoy reactor** |
| `B` | **C6, A7** | **the two known real reactors** |

The last two rows are the striking ones and they were not looked for. Palette
`B` contains exactly two rooms and they are exactly the two rooms reported as
real reactors. Palette `A` contains exactly one room, and it is the one reported
as looking like a reactor while not being one. So the appearance byte alone
separates the decoy from the genuine articles.

Three real reactors are reported. Only two carry palette `B`, so either the
third is reached by teleport into one of them, or it does not share their
appearance.

## Items

`item_and_goal_record_table` holds twelve records and shares the item-name and
graphic index: graphic pairs begin at `$28 + 2n`. Record 3 is deliberately
special, however. Before drawing pair `$2E/$2F`, its code prints “THE GOLDEN
DRAGON” and sets the gameplay-loop exit flag to `$FF`. Its H8 location is the
reported goal, not evidence that the inventory item named `salt` lies there.
At new-game startup, `$3245` restores this whole mutable table from the 48-byte
initial image at `$0980`.

| n | Name | Code | Record's room | Reported |
| --- | --- | --- | --- | --- |
| 0 | `key` | `$28` | G8 | square key at G8 |
| 1 | `key` | `$2A` | B1 | round key at B1 |
| 2 | `key` | `$2C` | A4 | key at A4 |
| 3 | Golden Dragon ending (`salt` index) | `$2E/$2F` | H8 | THE GOLDEN DRAGON at H8 — agrees |
| 4 | `worm` | `$30` | H5 | worm at H5 |
| 5 | `card` | `$32` | A2 | access card at A2 |
| 6 | `herrin` | `$34` | across 0, down 10 | from the E6 fish puzzle |
| 7 | `mouse` | `$36` | across 0, down 10 | mouse at G9, via cheese |
| 8 | `cheese` | `$38` | F1 | cheese at F1 |
| 9 | `cross` | `$3A` | H2 | cross from the Joke Shop chain at H2 |
| 10 | `eye` | `$3C` | F3 | not reported — F3 is Chemical Supplies |
| 11 | `bottle` | `$3E` | B1 | bottle at F7 — **disagrees** |

Seven rows agree exactly, including all three keys in the order the three
reported keys are found, and `$2C` being a key and `$32` the card was already
proved independently from captured frames.

Two records name `down = 10`, which is outside the ten-level grid, so those two
placements can never match a room and the item is never lying there to pick up.
Both are items the account says are *produced* rather than found: the herring
from the fish puzzle and the mouse from baiting with cheese.

Two item rows disagree with the account: `eye` at F3 and `bottle` at B1. The
first is suggestive rather than plainly wrong — F3 is the Chemical Supplies
room, while the room-sign table contains an `Optician` sign that nothing else
explains and would want an eye. The bottle is a plain disagreement. Record 3's
former apparent salt disagreement is resolved by its explicit ending code.

## Passwords

`$18AA` gives the password number a column carries; `$1771` adds `$31` before
printing, so the number shown is one higher than the number stored. Passwords
are five letters at `password_letters + 3n`.

| Shown | Stored | Word | Column | Reported location |
| --- | --- | --- | --- | --- |
| 1 | 0 | SALLY | across 3 | D4 — agrees |
| 2 | 1 | LYNDA | across 5 | F5 — agrees |
| 3 | 2 | DAVID | across 1 | B9 — agrees |
| 4 | 3 | IDIOT | across 7 | H3, reported as EDITOR — **disagrees** |
| 5 | 4 | OTTER | across 6 | G0 — agrees |
| 6 | 5 | ERASE | across 4 | E1, the Music Room — agrees |
| 7 | 6 | SEVEN | across 2 | C7, reported as GREEN — **disagrees** |
| 8 | 7 | ENTER | across 0 | not reported |

Both disagreements are settled by the payload: **neither `GREEN` nor `EDITOR`
appears anywhere in the authority image**, while `IDIOT` is at `$179F` and
`SEVEN` at `$17A8`. Password 7 being the word SEVEN is plainly deliberate.

Password 8, ENTER, has no reported location. Column A carries it, and column A
holds Terminal 1 at A0.

## Terminals

Reported: Terminal 1 at A0, 2 at B7, 3 at C3, 4 at D6, 5 at E9, 6 at F3, 7 at
G4. Reading the letters as `$90`, the terminal number is the column plus one in
every case, so terminals are numbered by column and column H would hold
terminal 8. That is a regularity the account did not claim and the payload has
not yet been shown to encode; it is recorded here as a pattern to test.

Note that a column's terminal number and its password number are unrelated:
column G holds terminal 7 and password 5.

## Entities

Every one of the forty entity records resolves to a room inside the grid, which
is itself a check on the packed format.

`room_enemy_record_table` at `$0A00`, twenty records — B5 C3 F1 D0 A1 C1 B3 B6
C5 G2 E5 E2 A2 E3 F4 E4 H7 D6 C7 D7. This contains **every room the account
calls out for an enemy**: D0, G2, E5, E3 (the homing one) and F4. The rest are
hazard, water, acid and plant rooms.

`second_room_entity_record_table` at `$0A96`, twenty records — A4 B2 B6 G2 A1 B3
C0 G8 F0 E8 E5 G8 G5 H7 H4 E3 C2 E6 B8 D5. This is the class whose renderer
`$23BF` was shown by play to draw the vertical lifts, and whose update pushes or
carries the player. It contains C2, reported as an acid-vat platform room, and
the Ghost Maze rooms B8 and E8. G8 appears twice, so a room can hold two.

`indexed_pair_record_table` at `$0A78` is different in kind: one three-byte
record per level, not per room. `initialise_indexed_pair_from_record` reads it
at `$8F * 3` and writes every unpacked field twice, initialising two parallel
objects, and `advance_indexed_pair_value_and_display_pointer` **carries them
across room boundaries** — at a horizontal position of `$4D` it increments the
column and resets the position to zero, and at a negative position it decrements
the column and sets the position to `$4C`, reversing at columns 0 and 7.

That is a horizontally moving object which roams along a whole level rather than
sitting in one room, and it explains a failed experiment: suppressing its
renderer `$2EAA` appeared to do nothing to "the horizontal lifts", because
whether one is in the room being watched depends on where it has roamed to.

| Level | Reverses at column | Reported platform rooms on that level |
| --- | --- | --- |
| 0 | 1 and 5 | E0 platform |
| 1 | 5 and 6 | D1 platform |
| 2 | 4 and 6 | C2 platform |
| 3 | 3 and 6 | D3 platform — agrees |
| 4 | 0 and 2 | — |
| 5 | 1 and 2 | — |
| 6 | 5 and 6 | A6 platform |
| 7 | 2 and 4 | — |
| 8 | 0 and 7 | — |
| 9 | 0 and 7 | — |

Only level 3 lines up with a reported platform room, so the reversal columns are
not simply "the room the platform is in". The mechanism is proved from the code;
what the two selector columns mean in play is not.

## The reported map

Kept verbatim as testimony. Rooms the payload has something to say about are
marked: **i** an item placement, **e** a first-class entity, **s** a
second-class entity, **P** a password, **R** palette B (reactor), **D** palette
A (decoy).

| Room | Reported | Payload |
| --- | --- | --- |
| A0 | Terminal 1 | |
| B0 | START; crystal obtainable after Terminal 1 | |
| C0 | traversal/obstacle | s |
| D0 | traversal with enemy | e |
| E0 | water/platform traversal | |
| F0 | TIME WARP | s |
| G0 | password 5 OTTER; entrance toward the Chapel | P |
| H0 | The Chapel; cross/noon puzzle | |
| A1 | square-key door, part of the B0 crystal route | e s |
| B1 | round key, first important pickup | i i |
| C1 | hazard/traversal | e |
| D1 | moving platform | |
| E1 | first Music Room, eight pads; password 6 | P |
| F1 | cheese and crystal | i e |
| G1 | connecting | |
| H1 | TELEPORT room | |
| A2 | access card and crystal | i e |
| B2 | traversal/hazard | s |
| C2 | acid vat, platforms | s |
| D2 | traversal | |
| E2 | crystal | e |
| F2 | Joke Shop | |
| G2 | traversal with enemy | e s |
| H2 | Joke Shop; cross chain | i |
| A3 | traversal | |
| B3 | traversal | e s |
| C3 | Terminal 3 and crystal; releases the B9 crystal | e |
| D3 | platform/traversal | |
| E3 | difficult diagonal, homing enemy | e s |
| F3 | CHEMICAL SUPPLIES, Terminal 6; HCl/NaOH, salt | i |
| G3 | second Music Room | |
| H3 | password 4 and crystal | P |
| A4 | key visible | i s |
| B4 | acid vat | |
| C4 | creature/hazard | |
| D4 | password 1 SALLY | P, palette 9 alone |
| E4 | water/traversal | e |
| F4 | hydroponic maze with enemy | e |
| G4 | Terminal 7 | |
| H4 | crystal tied to Terminal 7 | s |
| A5 | traversal/door | |
| B5 | hazard/water | e |
| C5 | plant/hydroponics maze | e |
| D5 | ELEPHANT HOUSE; mouse used here | s |
| E5 | hydroponics with enemies | e s |
| F5 | hydroponics, password 2 LYNDA, slug; salt used here | P |
| G5 | crystal | s |
| H5 | worm | i |
| A6 | moving platform, spikes | palette 7 |
| B6 | acid vat | e s |
| C6 | underwater reactor, one of three real ones | **R** |
| D6 | Terminal 4 | e |
| E6 | underwater fish/herring; worm needed | s |
| F6 | connecting passage | |
| G6 | Joke Shop / TIME WARP and crystal | |
| H6 | traversal | |
| A7 | real reactor, tied to Terminal 2 | **R** |
| B7 | Terminal 2 | |
| C7 | password 7 and crystal | P e |
| D7 | underwater traversal | e |
| E7 | water/fish | |
| F7 | bottle pickup | |
| G7 | traversal | |
| H7 | passage into the lower maze | e s, palette 0 alone |
| A8 | PRAY AT NOON clue; **not** a real reactor | **D** |
| B8 | Ghost Maze | s |
| C8 | Ghost Maze | |
| D8 | Ghost Maze | |
| E8 | Ghost Maze | s |
| F8 | round-key door / lower passage | |
| G8 | square key | i s s |
| H8 | THE GOLDEN DRAGON, the goal | i |
| A9 | The Oracle; teleporter/password puzzle | |
| B9 | password 3 DAVID and crystal; via Terminal 3 | P |
| C9 | lower/Ghost Maze passage | |
| D9 | lower/Ghost Maze passage | |
| E9 | The Armoury / Terminal 5; stun grenades | |
| F9 | lower water/traversal | |
| G9 | mouse and crystal; bring the cheese | |
| H9 | QUEST end-game display | |

Twelve power crystals are reported: A2 F1 E2 H3 G5 G6 C7 H4 G9 C3 B0 B9. Twelve
is also the limit `collected_icon_count` counts up to and the number of icon
slots `initialise_new_game` lays out, which is consistent, but no table of
twelve crystal rooms has been found: `$0900` is twelve records and turned out to
be the items instead. So the crystals are placed by something not yet located.

## Room signs

`room_sign_text_table` at `$17B0` holds sixteen sixteen-byte signs. Fifteen are
accounted for by the reported map:

Music Room (E1, G3), a Level/Sector template, Elephant House (D5), Joke Shop
(F2, H2, G6), Teleport (H1), The Armoury (E9), Hydroponics (C5, E5, F5, F4),
`HCL` and `Na-OH` (F3), Time Warp (F0, G6), The Oracle (A9), Chemical Supplies
(F3), Ghost Maze (B8-E8, C9, D9), Chapel (H0), and a `PASSWORD>` prompt for the
terminals.

The sixteenth is `Optician`, which the reported map does not mention. The item
table has an `eye`. Nothing else in either table explains either of them.
