#!/usr/bin/env python3
"""Pixel-art block textures: assets/blocks/<name>.png, drawn here so they can be
remade. Any PNG in assets/blocks/ that BlockTextures knows about textures that
block in game (still shaded per face and darker deeper down), so you can also
just paint your own over these. Keep them square; 32x32 matches the rest.

    python3 tools/make_block_textures.py

scrap.png: a jumble of salvage (nuts, a washer, a spring, screws, a rusty
plate, a red clamp jaw and a yellow wall plug) packed in dark olive grime,
after the scrap-heap reference. Tiles seamlessly.
"""
import os
import random
from PIL import Image

N = 32
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "blocks")

O = (28, 22, 16)                                   # outline
GRIME = [(46, 38, 14), (72, 60, 22), (98, 82, 30), (126, 106, 40)]
STEEL = {"h": (236, 238, 244), "l": (196, 200, 210), "m": (148, 152, 166), "d": (98, 100, 116)}
RUST = {"h": (210, 140, 84), "l": (170, 98, 52), "m": (132, 72, 40), "d": (92, 50, 30)}
BRONZE = {"h": (236, 196, 132), "l": (200, 150, 92), "m": (160, 110, 62), "d": (110, 72, 40)}
RED = {"h": (255, 160, 140), "l": (238, 92, 72), "m": (200, 46, 36), "d": (134, 28, 24)}
YEL = {"h": (255, 240, 160), "l": (250, 212, 88), "m": (232, 176, 44), "d": (170, 116, 24)}


class Tile:
    def __init__(self):
        self.px = [[None] * N for _ in range(N)]
        self.part = [[0] * N for _ in range(N)]     # which item each pixel belongs to (0 = grime)
        self.next_id = 1

    def item(self):
        self.next_id += 1
        return self.next_id - 1

    def put(self, x, y, c, pid):
        x %= N
        y %= N
        self.px[y][x] = c
        self.part[y][x] = pid


def lit(pal, nx, ny, r):
    """Colour for a point on a rounded part: lit from the top left."""
    k = (nx + ny) / max(r, 1.0)
    if k < -1.0:
        return pal["h"]
    if k < -0.25:
        return pal["l"]
    if k < 0.6:
        return pal["m"]
    return pal["d"]


def disc(t, cx, cy, r, pal, hole=0.0, hexagon=False, teeth=False):
    """Washers, nuts (hexagon) and gears (teeth): a lit disc with a hole."""
    pid = t.item()
    R = r + (1 if teeth else 0)
    for y in range(-R, R + 1):
        for x in range(-R, R + 1):
            d = (x * x + y * y) ** 0.5
            inside = d <= r + 0.35
            if hexagon:
                inside = abs(x) * 0.87 + abs(y) * 0.5 <= r * 0.87 + 0.3 and abs(y) <= r - 0.5
            if teeth and not inside and d <= R + 0.35 and (x + y) % 2 == 0:
                inside = True
            if not inside:
                continue
            c = O if d < hole else lit(pal, x, y, r)
            if hole > 0 and hole <= d < hole + 1.0 and x + y > 0:
                c = pal["h"]                       # the far rim of the hole catches the light
            t.put(cx + x, cy + y, c, pid)


def spring(t, x0, y0, turns, h, pal):
    """A coil spring lying on its side."""
    pid = t.item()
    for i in range(turns * 3):
        for y in range(h):
            k = i % 3
            if k == 0:
                c = pal["h"] if y == 1 else pal["l"]
            elif k == 1:
                c = pal["m"] if y < h - 1 else pal["d"]
            else:
                c = pal["d"] if 0 < y < h - 1 else O
            t.put(x0 + i, y0 + y, c, pid)


def screw(t, x0, y0, length, pal, dx=1, dy=-1, head=True):
    """A screw or bolt along a diagonal or straight line: threads, then a head."""
    pid = t.item()
    for i in range(length):
        x, y = x0 + i * dx, y0 + i * dy
        t.put(x, y, pal["m"], pid)
        side = (x + (1 if dy != 0 else 0), y + (1 if dy == 0 else 0))
        t.put(side[0], side[1], pal["h"] if i % 2 == 0 else pal["d"], pid)
    if head:
        hx, hy = x0 + length * dx, y0 + length * dy
        for y in range(-1, 3):
            for x in range(-1, 3):
                t.put(hx + x, hy + y, lit(pal, x - 0.5, y - 0.5, 1.5), pid)


def strip(t, x0, y0, w, h, pal, holes=(), spots=None):
    """A flat strip of metal (a bent bracket) with holes and rust spots."""
    pid = t.item()
    for y in range(h):
        for x in range(w):
            c = pal["l"] if y == 0 else (pal["d"] if y == h - 1 else pal["m"])
            if x == 0 and 0 < y:
                c = pal["l"]
            if spots and (x * 5 + y * 3) % 7 == 0 and 0 < y < h - 1:
                c = spots
            t.put(x0 + x, y0 + y, c, pid)
    for hx, hy in holes:
        t.put(x0 + hx, y0 + hy, O, pid)
    return pid


def scrap() -> Image.Image:
    rng = random.Random(11)
    t = Tile()
    # the jumble, back to front (later parts sit on top)
    strip(t, 0, 12, 10, 5, RUST, holes=[(2, 2), (7, 2)], spots=RUST["d"])      # rusty bracket
    strip(t, 19, 26, 9, 4, STEEL, holes=[(4, 2)], spots=RUST["m"])             # bent steel plate
    spring(t, 13, 1, 5, 6, STEEL)                                              # big coil spring
    disc(t, 6, 25, 4, BRONZE, hole=1.6, teeth=True)                            # a bronze gear
    disc(t, 26, 19, 5, STEEL, hole=2.2)                                        # a washer
    disc(t, 6, 5, 5, STEEL, hole=1.8, hexagon=True)                            # a big nut
    screw(t, 11, 31, 8, STEEL, dx=1, dy=-1)                                    # a screw, up and right
    screw(t, 29, 2, 6, RUST, dx=0, dy=1, head=False)                           # a rusty nail, downwards
    # the red C-clamp: jaw, spine and foot, with its steel screw
    jaw = strip(t, 12, 10, 8, 3, RED)
    for y in range(13, 21):
        t.put(12, y, RED["l"], jaw); t.put(13, y, RED["m"], jaw); t.put(14, y, RED["d"], jaw)
    for x in range(12, 19):
        t.put(x, 20, RED["m"], jaw); t.put(x, 21, RED["d"], jaw)
    for y in range(13, 20):
        t.put(18, y, STEEL["h"] if y % 2 else STEEL["d"], jaw)
    # a yellow wall plug
    plug = strip(t, 25, 9, 5, 4, YEL)
    t.put(25, 10, YEL["h"], plug); t.put(29, 11, YEL["d"], plug); t.put(27, 10, YEL["d"], plug)
    disc(t, 9, 19, 2, STEEL, hole=0.6, hexagon=True)                           # little nuts
    disc(t, 1, 20, 2, STEEL, hole=0.6)
    disc(t, 16, 26, 2, RUST, hole=0.6)
    # outlines: dark wherever a part meets grime, and round each part that lies on another
    img = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            p = t.part[y][x]
            nbrs = [t.part[(y + dy) % N][(x + dx) % N] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            c = t.px[y][x]
            if p == 0:
                if any(q != 0 for q in nbrs):
                    c = O
                else:
                    k = rng.random()
                    c = GRIME[0] if k < 0.3 else GRIME[1] if k < 0.72 else GRIME[2] if k < 0.93 else GRIME[3]
            elif any(q > p for q in nbrs):
                c = O                              # the edge of a part that lies on this one
            img.putpixel((x, y), c)
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    img = scrap()
    img.save(os.path.join(OUT, "scrap.png"))
    print("wrote assets/blocks/scrap.png (%dx%d)" % img.size)


if __name__ == "__main__":
    main()
