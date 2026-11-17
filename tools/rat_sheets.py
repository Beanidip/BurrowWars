#!/usr/bin/env python3
"""Rat sprite sheets: one PNG per class and team, e.g. assets/rats/digger_blue.png.

Layout (must match RatSprite in scripts/actors/rat_sprite.gd):
  - every cell is 72 x 72 pixels, transparent background, the rat standing on
    the bottom of the cell and facing the viewer's right;
  - one ROW per animation, in this order, top to bottom:
        0 idle (2 frames)   1 run (4)     2 jump (3)
        3 dig (3)           4 attack (2)  5 hurt (2)
        6 build (3)         7 use (3)     8 down (4)
  - frames go left to right; the sheet is 4 cells wide (288 x 648), cells past
    an animation's frame count are left empty.
To change frame counts or speeds, edit FRAMES / FPS in rat_sprite.gd and keep
this file's FRAMES in step.

    python3 tools/rat_sheets.py guide            # docs/rat_sheet_layout.png (labelled grid)
    python3 tools/rat_sheets.py pack DIR         # DIR/<class>_<team#>_<anim>_<frame>.png -> sheets
    python3 tools/rat_sheets.py unpack DIR       # sheets -> DIR/<class>_<team#>_<anim>_<frame>.png
"""
import os
import sys
from PIL import Image, ImageDraw

CELL = 72
COLS = 4
ANIMS = ["idle", "run", "jump", "dig", "attack", "hurt", "build", "use", "down"]
FRAMES = {"idle": 2, "run": 4, "jump": 3, "dig": 3, "attack": 2, "hurt": 2, "build": 3, "use": 3, "down": 4}
CLASSES = ["digger", "scout", "builder", "saboteur"]
TEAMS = ["blue", "red"]
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RATS = os.path.join(ROOT, "assets", "rats")


def sheet_path(cls: str, team: str) -> str:
    return os.path.join(RATS, "%s_%s.png" % (cls, team))


def pack(src: str) -> None:
    for cls in CLASSES:
        for t, team in enumerate(TEAMS):
            sheet = Image.new("RGBA", (CELL * COLS, CELL * len(ANIMS)), (0, 0, 0, 0))
            for row, anim in enumerate(ANIMS):
                for f in range(FRAMES[anim]):
                    frame = os.path.join(src, "%s_%d_%s_%d.png" % (cls, t, anim, f))
                    if os.path.exists(frame):
                        sheet.alpha_composite(Image.open(frame).convert("RGBA").resize((CELL, CELL), Image.NEAREST), (f * CELL, row * CELL))
                    else:
                        print("missing frame:", frame)
            sheet.save(sheet_path(cls, team))
            print("wrote", os.path.relpath(sheet_path(cls, team), ROOT))


def unpack(dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for cls in CLASSES:
        for t, team in enumerate(TEAMS):
            sheet = Image.open(sheet_path(cls, team)).convert("RGBA")
            for row, anim in enumerate(ANIMS):
                for f in range(FRAMES[anim]):
                    cell = sheet.crop((f * CELL, row * CELL, (f + 1) * CELL, (row + 1) * CELL))
                    cell.save(os.path.join(dst, "%s_%d_%s_%d.png" % (cls, t, anim, f)))
    print("unpacked into", dst)


def guide() -> None:
    """A labelled picture of the layout over the Digger (blue) sheet."""
    s = 2
    base = Image.open(sheet_path("digger", "blue")).convert("RGBA")
    w, h = base.size
    out = Image.new("RGBA", (w * s + 150, h * s + 30), (36, 28, 22, 255))
    out.alpha_composite(base.resize((w * s, h * s), Image.NEAREST), (140, 24))
    d = ImageDraw.Draw(out)
    for row, anim in enumerate(ANIMS):
        y = 24 + row * CELL * s
        d.text((8, y + CELL * s // 2 - 6), "%d  %s (%d)" % (row, anim, FRAMES[anim]), fill=(240, 228, 200, 255))
        for c in range(COLS):
            x = 140 + c * CELL * s
            colour = (230, 190, 80, 255) if c < FRAMES[anim] else (90, 80, 70, 255)
            d.rectangle((x, y, x + CELL * s - 1, y + CELL * s - 1), outline=colour)
    for c in range(COLS):
        d.text((140 + c * CELL * s + 6, 6), "frame %d" % c, fill=(240, 228, 200, 255))
    path = os.path.join(ROOT, "docs", "rat_sheet_layout.png")
    out.save(path)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "guide":
        guide()
    elif len(sys.argv) >= 3 and sys.argv[1] in ("pack", "unpack"):
        (pack if sys.argv[1] == "pack" else unpack)(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(1)
