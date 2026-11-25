#!/usr/bin/env python3
"""Draws the hat sprites: assets/hats/<id>.png (placeholder pixel art).

    python3 tools/make_hats.py            # write the PNGs
    python3 tools/make_hats.py preview    # also a preview sheet in build/hats_preview.png

Each hat is drawn facing you, its bottom row is where it sits on the head
(scripts/actors/hats.gd finds the top of the head in every frame and puts it
there). Anything MAGENTA becomes the wearer's team colour, as on the rats.
Replace these with your own: any size up to 24 x 22, the same idea.
"""
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "hats"

PAL = {
    ".": None,
    "k": (38, 26, 20),       # outline
    "m": (200, 60, 200),     # team colour (light)
    "M": (136, 36, 136),     # team colour (dark)
    "y": (246, 200, 58),     # gold / cheese
    "Y": (196, 140, 30),     # dark gold
    "c": (214, 158, 40),     # cheese hole
    "w": (246, 244, 236),    # white
    "g": (150, 154, 166),    # light grey
    "G": (58, 58, 70),       # dark grey (black hats)
    "h": (98, 98, 112),      # black hat highlight
    "r": (214, 52, 52),      # red
    "u": (60, 140, 230),     # blue
    "e": (70, 160, 70),      # green
    "b": (150, 98, 54),      # brown
    "B": (104, 64, 34),      # dark brown
    "o": (240, 140, 40),     # orange
}

HATS = {
    "party": """
.....yy.....
....yyyy....
.....yy.....
.....kk.....
....kmmk....
....kwwk....
...kmmmmk...
...kwwwwk...
..kmmmmmmk..
..kwwwwwwk..
.kmmmmmmmmk.
.kkkkkkkkkk.
""",
    "tophat": """
...kkkkkkkkkk...
...kGhGGGGGGk...
...kGhGGGGGGk...
...kGhGGGGGGk...
...kGhGGGGGGk...
...kmmmmmmmmk...
...kMMMMMMMMk...
.kkkkkkkkkkkkkk.
kGGGGGGGGGGGGGGk
.kkkkkkkkkkkkkk.
""",
    "crown": """
..k....kk....k..
.kyk..kyyk..kyk.
.kyyk.kyyk.kyyk.
.kyyykyyyykyyyk.
.kyyyyyyyyyyyyk.
.kyrryyuuyyeeyk.
.kYYYYYYYYYYYYk.
.kkkkkkkkkkkkkk.
""",
    "cheese": """
..........kk....
.......kkkyyk...
....kkkyyyyyk...
..kkyyyyyyyyk...
.kyyyyyyyyyyyk..
.kyycyyyyycyyk..
.kyyyyyyycyyyk..
.kycyyyyyyyyyk..
.kYYYYYYYYYYYk..
.kkkkkkkkkkkkk..
""",
    "beanie": """
.....kwwk.....
....kwwwwk....
.....kkkk.....
...kkmmmmkk...
..kmmmmmmmmk..
.kmmMmmMmmMmk.
.kmmMmmMmmMmk.
.kwwwwwwwwwwk.
.kgwgwgwgwgwk.
.kkkkkkkkkkkk.
""",
    "viking": """
kk................kk
kwk..............kwk
kwwk....kkkk....kwwk
.kwwk.kkggggkk.kwwk.
..kwwkgggggggGkwwk..
...kwkggggggggkwk...
....kkgggggggGkk....
.....kGGGGGGGGk.....
....kyyyyyyyyyyk....
....kkkkkkkkkkkk....
""",
    "chef": """
...kkk.kkk....
..kwwwkwwwk...
.kwwwwwwwwwk..
kwwwwwwwwwwwk.
kwwwwwwwwgwwk.
.kwwwwwwwwwk..
..kwwwwwwwk...
..kwgwwwgwk...
..kwwwwwwwk...
..kkkkkkkkk...
""",
    "propeller": """
.kkkkk..kkkkk.
kyyyyykkyyyyyk
.kkkkkkkkkkkk.
......kk......
....kkmmkk....
..kkmmuummkk..
.kmmmmuummmmk.
.kmmmmmmmmmmk.
kMMMMMMMMMMMMk
.kkkkkkkkkkkk.
""",
    "wizard": """
.......kk.....
......kmk.....
......kmmk....
.....kmmmk....
.....kmymk....
....kmmmmmk...
....kmmmmmk...
...kmmymmmmk..
...kmmmmmmmk..
..kmmmmmmymmk.
..kmmmmmmmmmk.
.kyyyyyyyyyyyk
kkkkkkkkkkkkkk
""",
    "flower": """
....kkk.....
...kwwwk....
.kkkwwwkkk..
kwwwkyykwwwk
kwwkyyyykwwk
kwwwkyykwwwk
.kkkwwwkkk..
...kwwwk....
....kkk.....
""",
    "cowboy": """
.......kkkkkkkk.......
......kbbbbbbbbk......
.....kbbbbkkbbbbk.....
.....kbbbbbbbbbbk.....
.....kmmmmmmmmmmk.....
kk...kBBBBBBBBBBk...kk
kbkkkkkkkkkkkkkkkkkkbk
.kbbbbbbbbbbbbbbbbbbk.
..kkkkkkkkkkkkkkkkkk..
""",
    "pirate": """
.........kk.........
.......kkGGkk.......
.....kkGGGGGGkk.....
...kkGGGGwwGGGGkk...
.kkGGGGGwkkwGGGGGkk.
kGGGGGGGGwwGGGGGGGGk
kGGGGGGGGGGGGGGGGGGk
.kyyyyyyyyyyyyyyyyk.
..kkkkkkkkkkkkkkkk..
""",
}


def draw(art):
    rows = [r for r in art.strip("\n").split("\n")]
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row.ljust(w, ".")):
            col = PAL[ch]
            if col is not None:
                img.putpixel((x, y), col + (255,))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, art in HATS.items():
        draw(art).save(OUT / f"{name}.png")
    print(f"wrote {len(HATS)} hats to {OUT}")
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        preview()


def preview():
    """Every hat on every class (front view, first idle frame), 4x."""
    sys.path.insert(0, str(ROOT / "tools"))
    classes = ["digger", "scout", "builder", "saboteur"]
    names = list(HATS)
    room = 16
    sheet = Image.new("RGBA", (72 * len(names), (72 + room) * len(classes) * 2), (60, 50, 40, 255))
    for ci, cls in enumerate(classes):
        for vi, view in enumerate(["_front", ""]):
            base = Image.open(ROOT / "assets" / "rats" / f"{cls}{view}.png").convert("RGBA").crop((0, 0, 72, 72))
            for hi, hat in enumerate(names):
                cell = Image.new("RGBA", (72, 72 + room), (0, 0, 0, 0))
                cell.paste(base, (0, room))
                ax, ay = anchor(base)
                h = draw(HATS[hat])
                cell.alpha_composite(h, (ax - h.width // 2, ay + room - h.height + SINK))
                sheet.alpha_composite(cell, (hi * 72, (ci * 2 + vi) * (72 + room)))
    out = ROOT / "build" / "hats_preview.png"
    out.parent.mkdir(exist_ok=True)
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
    print("preview:", out)


SINK = 3


def anchor(cell):
    """Where a hat's bottom-centre goes: the middle of the head, at its top
    (the same rule as scripts/actors/hats.gd)."""
    w, h = cell.size
    a = cell.split()[3]
    bb = a.getbbox()
    if bb is None:
        return w // 2, h // 2
    top = bb[1]
    xs = [x for y in range(top, min(h, top + 12)) for x in range(w) if a.getpixel((x, y)) > 0]
    cx = round(sum(xs) / len(xs))
    band = [y for y in range(h) for x in range(cx - 3, cx + 4) if 0 <= x < w and a.getpixel((x, y)) > 0]
    return cx, (min(band) if band else top)


if __name__ == "__main__":
    main()
