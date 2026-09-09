#!/usr/bin/env python3
"""Generate a variant that starts the game in any room, placed and equipped.

Three separate things have to be right, and each was got wrong once first.

The room pointer. set_room_data_pointer builds the room cell pointer as $37D0
plus the level base at $72/$73 plus the sector times five, and that base is a
copy of $70/$71, which the level transitions maintain by adding or subtracting
$78. Patching only $8F and $90 leaves the pointer stale and the room draws as
garbage. $3200 - an unreferenced developer warp, never executed in any trace -
writes all four together from four immediates, so this retargets its immediates
and calls it.

The displaced stores. The region the call replaces runs to $0BDE, not $0BD8.
The original loads zero once at $0BD5 and leans on it for four stores: $8F, $A0,
$70 and $71. A call returns something else in A, so leaving the last three in
place writes that over the pointer just set. Row 0's high byte is zero, which is
why every room tested before row 4 looked correct.

The start point. $0C29 places the player at display pointer $7460, $35 = $1C
and $2C = $B0
- character row 27 of 32, column unit 28 - which is open floor in the opening
room and solid wall or a pit elsewhere. Nothing in the game holds a per-room
start point: the edge transitions keep the player's height from the room they
came from, so there is no stored position to reuse. Instead this places the
player where the room's own drawn screen shows a floor, resting on it rather
than falling onto it. tools/runtime_trace/find_start_point.py reads that screen
and reports the places two empty rows sit on a solid one.

$2C has to move with the pointer. It is the vertical position the boundary
tests use - $28B0 takes the room-above transition when $2C is under 18, and
$2AFD's counterpart does the same downward - and it is kept independently of
the display pointer, so a start point that moves one and not the other leaves
the game believing the player is somewhere they are not. Placed at row 19 with
$2C still saying row 27, the player cannot reach the ceiling however far up they
fly, because collision stops them at the real ceiling while $2C is still eight
rows short of the test. That was reported as not being able to leave a room
through the top.

Falling onto the floor was the first attempt and it does not work: from
character row 10 in the Music Room the fall gathered enough speed to tunnel
through the row of separated spikes on the pyramid and out of the bottom of the
room, stepping the level index from 1 to 2 within a second of the game starting.

Coordinates are given the way the rooms are named in conversation: across
first, then down, so "4,1" is four across and one down. Across is $90 and down
is $8F, both measured - a session of known moves showed moving right increments
$90 and moving down increments $8F, and the game opens at $8F = 0, $90 = 1.

Across-first was established the hard way. Built as row-first, "4,1" produced
$8F = 4, $90 = 1, a room of pits; built across-first it produces $8F = 1,
$90 = 4, which is the Music Room, and the Music Room was described as three
along and one down from the opening room, which is exactly $90 = 1 + 3 and
$8F = 0 + 1.

    python tools/reconstruction/make_start_room_variant.py --room 4,1
        --item 0x32 --no-damage --name room_4_1_card
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

VARIANTS = Path(__file__).resolve().parent / "variants"
LEVEL_STRIDE = 0x78

SCREEN_BASE = 0x3000
BYTES_PER_CHARACTER_ROW = 0x0280
BYTES_PER_COLUMN_UNIT = 8

# The game's own start point, and the bytes that write it.
STOCK_START_ROW = 27
STOCK_START_COLUMN = 0x1C
PLACEMENT_EXPECT = ("a9 60 85 36 85 38 a9 74 85 37 85 39 "
                   "a9 1c 85 35 a9 b0 85 2c")

# $2C is the player's vertical position, in eighths of a character row measured
# from row 5, and the game keeps it alongside the display pointer rather than
# deriving one from the other. $28B0 reads it, not the pointer, to decide the
# player has reached the ceiling: LDA $2C, LSR A, CMP #$09 takes the room-above
# transition only when $2C is under 18.
VERTICAL_POSITION_ORIGIN_ROW = 5
VERTICAL_POSITION_PER_ROW = 8


def vertical_position(row: int) -> int:
    return (row - VERTICAL_POSITION_ORIGIN_ROW) * VERTICAL_POSITION_PER_ROW

ITEM_CODES = {0x2C: "Key", 0x32: "access card"}


def hexbyte(text: str) -> int:
    value = int(text, 0)
    if not 0 <= value <= 0xFF:
        raise argparse.ArgumentTypeError(f"{text} is not a byte")
    return value


def display_pointer(row: int, column: int) -> int:
    return SCREEN_BASE + row * BYTES_PER_CHARACTER_ROW + column * BYTES_PER_COLUMN_UNIT


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--room", required=True, metavar="ACROSS,DOWN",
                        help="the room as it is named in conversation, across then down, e.g. 4,1")
    parser.add_argument("--item", type=hexbyte,
                        help="item code for the first slot, $0C; $32 is the access card")
    parser.add_argument("--start-row", type=int, default=10,
                        help="character row 0-31 the player rests at; the stock start is 27")
    parser.add_argument("--start-column", type=hexbyte, default=STOCK_START_COLUMN,
                        help="$35, the horizontal position in eight-byte units, 0-79")
    parser.add_argument("--no-damage", action="store_true",
                        help="also stop energy loss and death, so the drop cannot kill")
    parser.add_argument("--fly-everywhere", action="store_true",
                        help="also let the jet boots work in rooms without the triangle symbol")
    parser.add_argument("--name", default="start_room")
    arguments = parser.parse_args()

    try:
        across_text, _, down_text = arguments.room.partition(",")
        across, down = int(across_text), int(down_text)
    except ValueError:
        raise SystemExit(f"--room wants ACROSS,DOWN, got {arguments.room!r}")
    # The grid is eight across: $18AA holds exactly eight bytes, one per $90,
    # mapping the across coordinate to a password number, and $18B2 is the next
    # instruction's opcode. Ten down, from the $78 stride over the map.
    if not 0 <= across <= 7:
        raise SystemExit("across must be 0 to 7")
    if not 0 <= down <= 9:
        raise SystemExit("down must be 0 to 9")
    if not 0 <= arguments.start_row <= 31:
        raise SystemExit("start row must be 0 to 31")
    vertical = vertical_position(arguments.start_row)
    if not 0 <= vertical <= 0xFF:
        raise SystemExit(
            f"start row {arguments.start_row} puts $2C outside a byte"
        )

    base = down * LEVEL_STRIDE
    pointer = display_pointer(arguments.start_row, arguments.start_column)
    if not SCREEN_BASE <= pointer <= 0x7FFF:
        raise SystemExit(f"start point ${pointer:04X} is outside the mode 1 screen")

    # The call replaces the whole run of stores, and has to reload the zero the
    # original shared, for $A0. $70/$71 belong to the call now.
    if arguments.item is None:
        start_write = "20 00 32 a9 00 85 a0" + " ea" * 7
    else:
        start_write = f"20 00 32 a9 {arguments.item:02x} 85 0c a9 00 85 a0 ea ea ea"

    described = None
    if arguments.item is not None:
        described = ITEM_CODES.get(arguments.item, f"item ${arguments.item:02X}")

    document = {
        "name": arguments.name,
        "description": (
            f"Start in room {across},{down} - {across} across, {down} down"
            + (f" carrying the {described}" if described else "")
            + f", resting at character row {arguments.start_row}"
            + (", taking no damage" if arguments.no_damage else "")
            + (", able to fly in every room" if arguments.fly_everywhere else "")
            + "."
        ),
        "evidence": [
            "set_room_data_pointer builds the room cell pointer as $37D0 plus the level base at $72/$73 plus the sector times five, and $72/$73 is a copy of $70/$71",
            "the level transitions maintain that base: $1CC7 adds $78 going down and $1CB5 subtracts $78 going up, so the base is the level times $78",
            "$3200 already writes $8F, $90 and $70/$71 together from four immediates, and its own values of 4, 3 and $01E0 satisfy that relation exactly, since 4 times $78 is $01E0",
            "initialise_new_game writes $90, $8F, $A0, $70 and $71 at $0BD1 through $0BDE, fourteen bytes, using one LDA #$00 for the last four",
            "$0BDF immediately loads a fresh constant and no branch reads the flags, so what the patch leaves in A and P after $0BDE does not matter",
            "$0C29 through $0C3C is the start point: it writes $7460 to both $36/$37 and $38/$39, $1C to $35 and $B0 to $2C, and $7460 is exactly $3000 plus 27 times $280 plus $1C times 8, so the pointer is character row 27 at column unit $1C and $35 is that same column",
            "$2C is the vertical position in eighths of a row from row 5: enter_room_above rebuilds the pointer as $35 times 8 plus $7D80, which is row 31, and writes $2C = $D0, and $D0 over 8 plus 5 is 31; the stock start point's $B0 gives 27, the row its pointer encodes, so the same formula fits both",
            "$28B0 reads $2C rather than the display pointer to decide the player has reached the ceiling, taking enter_room_above when $2C over 2 is under 9",
            "the only other constant writers of $35 are the edge transitions, $2AD1 with $00 and $2AE8 with $4C, and neither writes a vertical, so room entry keeps the height from the previous room and no per-room start point is stored",
            "the access card is item code $32 and the Key is $2C: sampling $0C and $0D across the played_access_card replay shows the slots taking 44 and 50 decimal, and a captured frame labels each",
            "draw_two_item_slots reads $0C,X and uses the value directly as a graphic index, so a slot holds the item code itself",
        ],
        "qualifications": [
            "patching only $8F and $90 without the pointer produces corrupt rooms above level 0, which is what an earlier attempt did",
            "an earlier version patched only $0BD1 through $0BD8 and left the $A0, $70 and $71 stores running on whatever A the call returned, so it produced a correct room only for row 0, and with an item in A it drew an empty room",
            "$3200 normally jumps into the room draw rather than returning; its jump is replaced with an RTS so it can be called, which changes that routine for any other caller, though no trace has ever entered it",
            "the stock start point is open floor only in the opening room; carrying it into another room can place the player inside a wall or over a cavern, which is why the start point is chosen per room",
            "the start point has to be a place the player rests on, not a height to fall from: a long fall tunnels through thin terrain, which is how the first attempt left the Music Room within a second",
            "find_start_point.py reads the floor out of the drawn screen, which is the right authority because terrain collision is display based at $290B, but it only sees the room as first drawn, so a floor that a moving platform provides is not among its answers",
            "an earlier version moved the display pointer and $35 but left $2C at the stock $B0, so the game believed the player was eight rows lower than they were drawn and the room-above transition could never fire",
            "coordinates are across then down, matching how the rooms are named in conversation: across is $90 and down is $8F",
            "across-first is confirmed by the Music Room, which is three along and one down from the opening room and appears at $90 = 4, $8F = 1; the row-first reading put a room of pits there instead",
            "the level shown on a room sign is the down index plus one, so down 0 displays as Level 1",
        ],
        "patches": [
            {"name": "teleport_row", "runtime_address": "3200",
             "expect": "a9 04", "write": f"a9 {down:02x}"},
            {"name": "teleport_column", "runtime_address": "3204",
             "expect": "a9 03", "write": f"a9 {across:02x}"},
            {"name": "teleport_base_low", "runtime_address": "3208",
             "expect": "a9 e0", "write": f"a9 {base & 0xFF:02x}"},
            {"name": "teleport_base_high", "runtime_address": "320C",
             "expect": "a9 01", "write": f"a9 {base >> 8:02x}"},
            {"name": "teleport_returns", "runtime_address": "3210",
             "expect": "4c 06 12", "write": "60 ea ea"},
            {"name": "start_calls_teleport", "runtime_address": "0BD1",
             "expect": "a9 01 85 90 a9 00 85 8f 85 a0 85 70 85 71",
             "write": start_write},
            {"name": "start_point", "runtime_address": "0C29",
             "expect": PLACEMENT_EXPECT,
             "write": (f"a9 {pointer & 0xFF:02x} 85 36 85 38 "
                       f"a9 {pointer >> 8:02x} 85 37 85 39 "
                       f"a9 {arguments.start_column:02x} 85 35 "
                       f"a9 {vertical:02x} 85 2c")},
        ],
    }
    if arguments.item is not None:
        document["patches"][5]["parameter"] = "item_code"
        document["patches"][5]["parameter_offset"] = 4
    if arguments.no_damage:
        document["patches"] += [
            {"name": "no_energy_loss", "runtime_address": "2B8F",
             "expect": "c6 3b", "write": "a9 01"},
            {"name": "death_flag_never_set", "runtime_address": "2B93",
             "expect": "a9 01", "write": "a9 00"},
        ]
        document["evidence"].append(
            "the damage routine has two lifted entries, $2B88 and $2B8F, so the later one is the one to patch; LDA #$01 replaces DEC $3B because NOP sets no flags and the guarding BNE then reads stale ones")

    if arguments.fly_everywhere:
        document["patches"].append(
            {"name": "thrust_poll_ignores_room_flag", "runtime_address": "2685",
             "expect": "a5 a6", "write": "a9 01"})
        document["evidence"].append(
            "$2685 loads $A6 and branches past both thrust polls when it is zero; $1BAA clears $A6 for every room and $167A sets it while one particular cell is drawn, so the boots are granted by a room's symbol")
        document["qualifications"].append(
            "flying in a room the designer did not intend it in can reach places the room was not built for; see the fly_in_every_room variant for the full reasoning")

    path = VARIANTS / f"{arguments.name}.json"
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"room {across},{down} - {across} across, {down} down"
          f"  ->  $8F={down}, $90={across}, $70/$71=${base:04X}")
    print(f"start point  ->  display ${pointer:04X}"
          f" (character row {arguments.start_row}, column unit ${arguments.start_column:02X})"
          f", $2C=${vertical:02X}")
    if arguments.item is not None:
        print(f"first slot   ->  $0C = ${arguments.item:02X} ({described})")
    print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
