#!/usr/bin/env python3
"""Rat sprite sheets: ONE PNG per class, e.g. assets/rats/digger.png.

Layout (must match RatSprite in scripts/actors/rat_sprite.gd):
  - every cell is 72 x 72 pixels, transparent background, the rat standing on
    the bottom of the cell and facing the viewer's right;
  - one ROW per animation, in this order, top to bottom:
        0 idle (2 frames)   1 run (4)     2 jump (3)
        3 dig (3)           4 attack (2)  5 hurt (2)
        6 build (3)         7 use (3)     8 down (4)
  - frames go left to right; the sheet is 4 cells wide (288 x 648), cells past
    an animation's frame count are left empty.

Team colour: paint anything that should be Blue or Red in MAGENTA (hue about
275-325 degrees, any lightness or shade). The game makes the Blue and Red
rats from the one drawing by swapping that hue. Keep everything else out of
that hue range (the pink ears, nose and tail are fine: they are a different hue).

To change frame counts or speeds, edit FRAMES / FPS in rat_sprite.gd and keep
this file's FRAMES in step.

    python3 tools/rat_sheets.py guide            # docs/rat_sheet_layout.png (labelled grid)
    python3 tools/rat_sheets.py preview DIR      # DIR/<class>_blue.png, <class>_red.png (as the game tints them)
    python3 tools/rat_sheets.py pack DIR         # DIR/<class>_<anim>_<frame>.png -> sheets
    python3 tools/rat_sheets.py unpack DIR       # sheets -> DIR/<class>_<anim>_<frame>.png
"""
import colorsys
import os
import sys
from PIL import Image, ImageDraw

CELL = 72
COLS = 4
ANIMS = ["idle", "run", "jump", "dig", "attack", "hurt", "build", "use", "down"]
FRAMES = {"idle": 2, "run": 4, "jump": 3, "dig": 3, "attack": 2, "hurt": 2, "build": 3, "use": 3, "down": 4}
CLASSES = ["digger", "scout", "builder", "saboteur"]
TEAMS = {"blue": (0.35, 0.58, 0.98), "red": (0.95, 0.38, 0.33)}   # UiKit.TEAM
KEY_HUE = (0.76, 0.90)   # RatSprite.KEY_HUE_MIN / MAX
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RATS = os.path.join(ROOT, "assets", "rats")


def sheet_path(cls: str) -> str:
    return os.path.join(RATS, "%s.png" % cls)


def tint(img: Image.Image, team_rgb) -> Image.Image:
    """The same hue swap the game does (RatSprite.tint)."""
    hue = colorsys.rgb_to_hsv(*team_rgb)[0]
    out = img.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            if a == 0 or g >= r or g >= b:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if KEY_HUE[0] <= h <= KEY_HUE[1] and s >= 0.2 and v >= 0.08:
                rr, gg, bb = colorsys.hsv_to_rgb(hue, s, v)
                px[x, y] = (round(rr * 255), round(gg * 255), round(bb * 255), a)
    return out


def preview(dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for cls in CLASSES:
        sheet = Image.open(sheet_path(cls)).convert("RGBA")
        for team, rgb in TEAMS.items():
            tint(sheet, rgb).save(os.path.join(dst, "%s_%s.png" % (cls, team)))
    print("team previews written to", dst)


def pack(src: str) -> None:
    for cls in CLASSES:
        sheet = Image.new("RGBA", (CELL * COLS, CELL * len(ANIMS)), (0, 0, 0, 0))
        for row, anim in enumerate(ANIMS):
            for f in range(FRAMES[anim]):
                frame = os.path.join(src, "%s_%s_%d.png" % (cls, anim, f))
                if os.path.exists(frame):
                    sheet.alpha_composite(Image.open(frame).convert("RGBA").resize((CELL, CELL), Image.NEAREST), (f * CELL, row * CELL))
                else:
                    print("missing frame:", frame)
        sheet.save(sheet_path(cls))
        print("wrote", os.path.relpath(sheet_path(cls), ROOT))


def unpack(dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for cls in CLASSES:
        sheet = Image.open(sheet_path(cls)).convert("RGBA")
        for row, anim in enumerate(ANIMS):
            for f in range(FRAMES[anim]):
                cell = sheet.crop((f * CELL, row * CELL, (f + 1) * CELL, (row + 1) * CELL))
                cell.save(os.path.join(dst, "%s_%s_%d.png" % (cls, anim, f)))
    print("unpacked into", dst)


def guide() -> None:
    """A labelled picture of the layout over the Digger (blue) sheet."""
    s = 2
    base = Image.open(sheet_path("digger")).convert("RGBA")
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
    d.text((8, 6), "magenta = team colour", fill=(230, 120, 230, 255))
    path = os.path.join(ROOT, "docs", "rat_sheet_layout.png")
    out.save(path)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "guide":
        guide()
    elif len(sys.argv) >= 3 and sys.argv[1] == "preview":
        preview(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] in ("pack", "unpack"):
        (pack if sys.argv[1] == "pack" else unpack)(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(1)
