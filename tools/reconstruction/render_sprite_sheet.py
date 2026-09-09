"""Render Quest's XOR sprites, lift, item pairs, and status/object graphics."""

from pathlib import Path
import re

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "source_bbc" / "quest1.asm"
OUTPUT = ROOT / "analysis" / "reconstruction" / "all_sprite_sheet.png"


def read_block(source: str, start_label: str, end_label: str, base_address: int, record_size: int):
    start = re.search(rf"(?m)^\.{re.escape(start_label)}\s*$", source)
    end = re.search(rf"(?m)^\.{re.escape(end_label)}\s*$", source)
    if start is None or end is None or end.start() <= start.end():
        raise ValueError(f"cannot locate sprite block {start_label}..{end_label}")
    block = source[start.end() : end.start()]
    label = None
    record = []
    result = []
    for line in block.splitlines():
        match = re.match(r"\s*\.([A-Za-z0-9_]+)\s*$", line)
        if match:
            label = match.group(1)
        if "EQUB" not in line:
            continue
        record.extend(int(value, 16) for value in re.findall(r"&([0-9A-Fa-f]{2})", line))
        if len(record) == record_size:
            result.append((base_address + len(result) * record_size, label, record))
            record = []
    if record:
        raise ValueError(f"partial sprite record in {start_label}: {len(record)} bytes")
    return result


def colour(value: int, packed_pixel: int):
    # BBC Mode 1 logical colour: high-nibble bit followed by low-nibble bit.
    low = (value >> (7 - packed_pixel)) & 1
    high = (value >> (3 - packed_pixel)) & 1
    return ((0, 0, 0), (255, 0, 0), (255, 255, 0), (255, 255, 255))[low | high << 1]


source = SOURCE.read_text()
records = read_block(
    source,
    "player_enemy_and_lift_xor_sprite_frames_source",
    "player_enemy_and_lift_xor_sprite_frames_end",
    0x0400,
    32,
)
records += read_block(
    source,
    "inert_xor_sprite_frame_block_source",
    "inert_xor_sprite_frame_block_end",
    0x0800,
    32,
)

room_records = read_block(
    source,
    "room_and_item_graphic_records_source",
    "room_and_item_graphic_records_source_end",
    0x0E10,
    16,
)
status_records = read_block(
    source,
    "status_icon_graphics_source",
    "unused_status_figure_graphics_source_end",
    0x0880,
    16,
)

# The lift renderer uses $0EA0 as a 32-byte XOR source, thereby combining room
# graphic records $0A and $0B into the complete 16x8 lift image.
lift_first = room_records[0x0A - 1]
lift_second = room_records[0x0B - 1]
records.append((0x0EA0, "vertical_lift_graphic_records_0a_0b", lift_first[2] + lift_second[2]))

item_names = (
    "key_item_1",
    "key_item_2",
    "key_item_3",
    "golden_dragon",
    "worm_item",
    "access_card_item",
    "fish_facing_left",
    "mouse_facing_left",
    "cheese_item",
    "cross_item",
    "eye_item",
    "bottle_item",
)
for pair_index, name in enumerate(item_names):
    record_index = 0x28 + pair_index * 2
    first = room_records[record_index - 1]
    second = room_records[record_index]
    records.append((0x0E00 + record_index * 0x10, name, first[2] + second[2]))

status_names = (
    "remaining_power_crystal_icon",
    "collected_power_crystal_icon",
    "initial_status_marker_icon",
    "blank_status_icon",
    "status_figure_fragment_4",
    "status_figure_fragment_5",
    "status_figure_fragment_6",
    "status_figure_fragment_7",
)
for (address, _label, record), name in zip(status_records, status_names):
    records.append((address, name, record))

columns = 3
scale = 8
cell_width = 390
cell_height = 108
sheet = Image.new("RGB", (columns * cell_width, ((len(records) + columns - 1) // columns) * cell_height), (224, 224, 224))
draw = ImageDraw.Draw(sheet)

for index, (runtime_address, label, record) in enumerate(records):
    column = index % columns
    row = index // columns
    ox = column * cell_width
    oy = row * cell_height
    draw.text((ox + 8, oy + 6), f"${runtime_address:04X}  {label}", fill=(0, 0, 0))
    sprite_x = ox + 8
    sprite_y = oy + 28
    byte_columns = len(record) // 8
    for y in range(8):
        for byte_column in range(byte_columns):
            value = record[y + byte_column * 8]
            for packed_pixel in range(4):
                x = byte_column * 4 + packed_pixel
                draw.rectangle(
                    (
                        sprite_x + x * scale,
                        sprite_y + y * scale,
                        sprite_x + (x + 1) * scale - 1,
                        sprite_y + (y + 1) * scale - 1,
                    ),
                    fill=colour(value, packed_pixel),
                )
    draw.rectangle((sprite_x - 1, sprite_y - 1, sprite_x + byte_columns * 4 * scale, sprite_y + 8 * scale), outline=(96, 96, 96))

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
temporary_output = OUTPUT.with_name(f"{OUTPUT.stem}.new{OUTPUT.suffix}")
sheet.save(temporary_output)
temporary_output.replace(OUTPUT)
print(OUTPUT)
