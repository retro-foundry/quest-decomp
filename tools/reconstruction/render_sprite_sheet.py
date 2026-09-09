"""Render Quest's complete runtime $0400-$087F XOR sprite bank."""

from pathlib import Path
import re

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "source_bbc" / "quest1.asm"
OUTPUT = ROOT / "analysis" / "reconstruction" / "all_sprite_sheet.png"


def read_block(source: str, start_label: str, end_label: str, base_address: int):
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
        if len(record) == 32:
            result.append((base_address + len(result) * 0x20, label, record))
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
)
records += read_block(
    source,
    "unused_xor_sprite_frames_0800_087f_source",
    "unused_xor_sprite_frames_0800_087f_end",
    0x0800,
)

columns = 2
scale = 10
cell_width = 430
cell_height = 125
sheet = Image.new("RGB", (columns * cell_width, ((len(records) + 1) // 2) * cell_height), (224, 224, 224))
draw = ImageDraw.Draw(sheet)

for index, (runtime_address, label, record) in enumerate(records):
    column = index % columns
    row = index // columns
    ox = column * cell_width
    oy = row * cell_height
    draw.text((ox + 8, oy + 6), f"${runtime_address:04X}  {label}", fill=(0, 0, 0))
    sprite_x = ox + 8
    sprite_y = oy + 28
    for y in range(8):
        for byte_column in range(4):
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
    draw.rectangle((sprite_x - 1, sprite_y - 1, sprite_x + 16 * scale, sprite_y + 8 * scale), outline=(96, 96, 96))

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
temporary_output = OUTPUT.with_name(f"{OUTPUT.stem}.new{OUTPUT.suffix}")
sheet.save(temporary_output)
temporary_output.replace(OUTPUT)
print(OUTPUT)
