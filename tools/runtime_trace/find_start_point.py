#!/usr/bin/env python3
"""Find a place in a room's drawn screen where the player can actually stand.

Dropping the player in from a fixed height and letting gravity settle them only
works if something is underneath. In the Music Room, column unit $1C is over a
cavern, so the player fell straight out of the bottom of the room and the level
index stepped from 1 to 2 within a second of the game starting.

Nothing in the game stores a per-room start point to copy, but the room's own
geometry is on the screen once it is drawn, and terrain collision is display
based - $290B tests the display rather than the map - so what the screen shows
is exactly what the player will stand on. This boots a variant disc, dumps the
mode 1 screen twice a moment after the room appears, and reports the places
where three empty rows sit directly on top of a solid one.

Three, because the player is three character rows tall. The left and right
movers set $41 to $18 before the collision scan, and the scan reads one byte per
iteration through (display pointer),Y with Y zero, so $18 is twenty-four
scanlines - three rows of eight. $2899 agrees: it reaches the ground by adding
$0780 to the player pointer, which is three times $280. The game's own start
point agrees too, putting the player at row 27 with the floor at row 30.

Requiring only two clear rows buries the player's bottom third in the floor.
That looks like the game misbehaving rather than a bad start point: the player
stands there but the collision scan finds solid ground inside its own column, so
walking is blocked in the direction of the buried row.

Two dumps rather than one because the player and the moving entities are drawn
into the same screen as the terrain, and a sprite reads as solid. Anything that
moves between the two dumps is not terrain, so intersecting them leaves the room
itself. Without this a falling player counts as a floor and the tool recommends
standing on thin air.

The reported row is where the player rests, not a height to fall from. Dropping
from a height was the first attempt and it tunnelled: from character row 10 the
fall gathered enough speed to pass straight through the row of separated spikes
on top of the Music Room pyramid and out of the bottom of the room, stepping the
level index from 1 to 2 within a second.

Mode 1 memory is a grid of eight-byte blocks: four pixels wide, eight scanlines
tall, eighty to a character row of $280 bytes, so the block for character row r
and column unit c is at $3000 + r * $280 + c * 8. Column unit is the same unit
the game keeps the player's horizontal position in, at $35.

    python tools/runtime_trace/find_start_point.py \
        --disc build/reconstruction/Quest-room-4-1-card.ssd
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

SCREEN_BASE = 0x3000
SCREEN_LENGTH = 0x5000
BYTES_PER_CHARACTER_ROW = 0x0280
BYTES_PER_BLOCK = 8
BLOCKS_PER_ROW = BYTES_PER_CHARACTER_ROW // BYTES_PER_BLOCK
CHARACTER_ROWS = SCREEN_LENGTH // BYTES_PER_CHARACTER_ROW

# The status bar and the two icon rows occupy the top of the screen, and the
# bottom row is the sound display, so neither is room geometry.
FIRST_PLAYABLE_ROW = 9
LAST_PLAYABLE_ROW = 30

# The player is three character rows tall: the movers scan $18 bytes, one per
# scanline, and the ground is $0780 - three rows - below the player pointer.
PLAYER_CHARACTER_ROWS = 3

PROLOGUE = [
    "breakat 10000000", "c", "keydown 32",
    "breakat 27000000", "c", "keyup 32",
    "breakat 28200000", "c", "keydown 32",
    "breakat 28400000", "c", "keyup 32",
]


def beebjit() -> Path:
    for candidate in (REPO_ROOT / "build" / "emulators").rglob("beebjit.exe"):
        return candidate
    raise SystemExit("beebjit is not installed")


def dump_screens(disc: Path, cycles: tuple[int, ...], work: Path) -> list[bytes]:
    work.mkdir(parents=True, exist_ok=True)
    commands = list(PROLOGUE)
    targets = []
    for index, cycle in enumerate(cycles):
        target = work / f"screen_{index}.bin"
        if target.exists():
            target.unlink()
        targets.append(target)
        commands += [f"breakat {cycle}", "c",
                     f"savemem {target} {SCREEN_BASE:x} {SCREEN_LENGTH:x}"]
    commands.append("q")
    command_file = work / "commands.txt"
    command_file.write_text("\n".join(commands) + "\n", encoding="ascii")
    with command_file.open("rb") as stdin:
        subprocess.run(
            [str(beebjit()), "-autoboot", "-headless", "-mode", "interp", "-debug",
             "-opt", "sound:off", "-disc", str(disc.resolve())],
            stdin=stdin, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            cwd=str(beebjit().parent),
        )
    missing = [t for t in targets if not t.exists()]
    if missing:
        raise SystemExit(f"beebjit wrote no screen dump for {missing[0].name}")
    return [t.read_bytes() for t in targets]


# $290B decides what blocks the player, and it treats a display byte as solid
# only when it is neither zero nor $C0. $C0 is drawn but passable, so counting
# it as terrain reports floors that the player falls straight through - which is
# what made a drop in the Music Room appear to tunnel through the spikes on the
# pyramid, and what made a search for a clear drop find none.
PASSABLE_BYTES = frozenset((0x00, 0xC0))


def solid_grid(screen: bytes) -> list[list[bool]]:
    grid = []
    for row in range(CHARACTER_ROWS):
        line = []
        for block in range(BLOCKS_PER_ROW):
            offset = row * BYTES_PER_CHARACTER_ROW + block * BYTES_PER_BLOCK
            line.append(any(byte not in PASSABLE_BYTES
                            for byte in screen[offset:offset + BYTES_PER_BLOCK]))
        grid.append(line)
    return grid


def terrain_grid(screens: list[bytes]) -> list[list[bool]]:
    """Solid in every dump, so sprites that moved in between are excluded."""
    grids = [solid_grid(screen) for screen in screens]
    return [[all(grid[row][block] for grid in grids)
             for block in range(BLOCKS_PER_ROW)]
            for row in range(CHARACTER_ROWS)]


def standing_places(grid: list[list[bool]]) -> list[tuple[int, int, int]]:
    """(row, column, floor_row) for each player-tall gap resting on solid ground."""
    places = []
    height = PLAYER_CHARACTER_ROWS
    for column in range(BLOCKS_PER_ROW):
        # The floor may be the bottom border at LAST_PLAYABLE_ROW itself, which
        # is where the game's own start point rests, so that row must be reachable.
        for row in range(FIRST_PLAYABLE_ROW, LAST_PLAYABLE_ROW - height + 1):
            if any(grid[row + offset][column] for offset in range(height)):
                continue
            if not grid[row + height][column]:
                continue
            places.append((row, column, row + height))
    return places


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--disc", required=True, type=Path)
    parser.add_argument("--cycle", type=int, default=30600000,
                        help="first dump cycle; just after the room is drawn")
    parser.add_argument("--second-cycle", type=int, default=31100000,
                        help="second dump cycle, far enough on that sprites have moved")
    parser.add_argument("--near", type=lambda t: int(t, 0), default=40,
                        help="prefer a column near this one, in eight-byte units")
    parser.add_argument("--work", type=Path,
                        default=REPO_ROOT / "build" / "traces" / "start_point")
    arguments = parser.parse_args()

    screens = dump_screens(
        arguments.disc, (arguments.cycle, arguments.second_cycle),
        arguments.work.resolve(),
    )
    grid = terrain_grid(screens)
    places = standing_places(grid)
    if not places:
        raise SystemExit("no two-row gap resting on solid ground was found")

    # A wide floor is a safer landing than a one-block ledge, and a spot near
    # the middle of the room is more use than one wedged against an edge.
    widths: dict[tuple[int, int], int] = {}
    by_floor: dict[int, set[int]] = {}
    for row, column, floor in places:
        by_floor.setdefault(floor, set()).add(column)
    for row, column, floor in places:
        run = 1
        for step in (-1, 1):
            probe = column + step
            while probe in by_floor[floor]:
                run += 1
                probe += step
        widths[(row, column)] = run

    ranked = sorted(
        places,
        key=lambda place: (-widths[(place[0], place[1])],
                           abs(place[1] - arguments.near),
                           place[0]),
    )
    print(f"{'rest row':>9} {'column':>7} {'floor row':>9} {'floor width':>11}")
    for row, column, floor in ranked[:12]:
        print(f"{row:>9} {column:>7} {floor:>9} {widths[(row, column)]:>11}")
    row, column, floor = ranked[0]
    print()
    print(f"best: standing on the floor at character row {floor},"
          f" {widths[(row, column)]} blocks wide")
    print(f"  --start-row {row} --start-column 0x{column:02X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
