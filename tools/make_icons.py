#!/usr/bin/env python3
"""Draws the 16x16 pixel-art icons (gadgets, traps, siege, gear, materials,
tools, abilities, menu buttons) into ONE sprite sheet:

    assets/icons/icons.png      8 columns of 16x16 cells, in ICONS order
    scripts/ui/icon_sheet.gd    the id of each cell (read by the game)
    docs/icon_sheet_layout.png  an enlarged, labelled picture of the sheet

Every icon is built from simple shapes; a dark outline is then added around
whatever was drawn, so all icons share one look.

To use your own art, paint over the cells in icons.png (keep the grid). To
replace a single icon without touching the sheet, drop assets/icons/<id>.png
next to it; a separate file wins. Rerunning this script redraws the whole
sheet, so only rerun it to add new icons (new ids go at the end of ICONS).

    python3 tools/make_icons.py
"""
import os
import sys
from PIL import Image

N = 16
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icons")

# palette (muted, matching the existing burrow_* UI art)
O = (34, 24, 20)          # outline
WOOD = (150, 98, 52); WOOD_L = (190, 132, 74); WOOD_D = (104, 66, 34)
STEEL = (170, 180, 188); STEEL_D = (110, 118, 128); STEEL_L = (214, 222, 228)
GREEN = (120, 190, 84); GREEN_D = (76, 132, 52)
RED = (206, 58, 46); RED_D = (146, 36, 30)
YEL = (246, 196, 64); YEL_D = (196, 140, 34); ORANGE = (240, 132, 44)
WHITE = (244, 240, 228); BLUE = (82, 128, 232); BLUE_L = (150, 186, 250); BLUE_D = (52, 86, 170)
REDT = (232, 96, 84)
DIRT = (122, 82, 52); DIRT_D = (90, 58, 36); DIRT_L = (150, 104, 68)
STONE = (128, 128, 138); STONE_D = (92, 92, 102); STONE_L = (164, 164, 174)
ICE = (176, 222, 244); ICE_L = (236, 250, 255); ICE_D = (120, 176, 210)
OBS = (60, 40, 82); OBS_L = (118, 86, 160); OBS_D = (36, 24, 50)
SCRAP = (196, 120, 56); SCRAP_D = (140, 82, 36)
BLACK = (24, 20, 22); GOO = (150, 196, 60); GOO_L = (196, 230, 110)
PINK = (232, 154, 168); GREY = (120, 120, 130)


class Icon:
    def __init__(self):
        self.px = [[None] * N for _ in range(N)]

    def put(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            self.put(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps), c)

    def disc(self, cx, cy, r, c):
        for y in range(N):
            for x in range(N):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.put(x, y, c)

    def pts(self, points, c):
        for x, y in points:
            self.put(x, y, c)

    def image(self, outline=True):
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        filled = [[self.px[y][x] is not None for x in range(N)] for y in range(N)]
        for y in range(N):
            for x in range(N):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), c + (255,))
                elif outline and any(0 <= x + dx < N and 0 <= y + dy < N and filled[y + dy][x + dx]
                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    img.putpixel((x, y), O + (255,))
        return img


def block(i, base, dark, light, specks=()):
    """A little isometric-ish cube face used by the material icons."""
    i.rect(2, 3, 13, 13, base)
    i.rect(2, 3, 13, 4, light)
    i.rect(12, 5, 13, 13, dark)
    i.rect(2, 13, 13, 13, dark)
    for x, y, c in specks:
        i.put(x, y, c)


ICONS = {}


def icon(name):
    def wrap(fn):
        ICONS[name] = fn
        return fn
    return wrap


# ---------------------------------------------------------------- materials
@icon("dirt")
def _(i):
    block(i, DIRT, DIRT_D, GREEN, [(4, 7, DIRT_D), (8, 9, DIRT_D), (6, 11, DIRT_L), (10, 6, DIRT_L), (5, 5, GREEN_D)])

@icon("stone")
def _(i):
    block(i, STONE, STONE_D, STONE_L, [(4, 7, STONE_D), (5, 8, STONE_D), (6, 8, STONE_D), (9, 10, STONE_D), (10, 11, STONE_D), (8, 6, STONE_L)])

@icon("ice")
def _(i):
    block(i, ICE, ICE_D, ICE_L, [(4, 6, ICE_L), (5, 7, ICE_L), (6, 8, ICE_L), (9, 9, ICE_L), (10, 10, WHITE)])

@icon("obsidian")
def _(i):
    block(i, OBS, OBS_D, OBS_L, [(5, 6, OBS_L), (6, 7, OBS_L), (9, 10, OBS_L), (4, 11, OBS_D)])

@icon("scrap")
def _(i):
    i.disc(8, 8, 5.6, SCRAP)
    for x, y in ((8, 1), (8, 14), (1, 8), (14, 8), (3, 3), (12, 3), (3, 12), (12, 12)):
        i.rect(x - 1 if x > 8 else x, y - 1 if y > 8 else y, (x - 1 if x > 8 else x) + 1, (y - 1 if y > 8 else y) + 1, SCRAP)
    i.disc(8, 8, 2.2, SCRAP_D)
    i.put(6, 5, YEL)

@icon("paint")
def _(i):
    i.line(3, 13, 9, 7, WOOD)            # brush handle
    i.line(4, 13, 10, 7, WOOD_D)
    i.rect(9, 4, 11, 6, STEEL)           # ferrule
    i.rect(10, 1, 13, 4, RED)            # bristles dipped in paint
    i.put(13, 1, REDT)
    i.pts([(2, 9), (3, 10)], BLUE)       # a few drops
    i.put(12, 9, YEL)

@icon("cheese")
def _(i):
    i.rect(2, 7, 13, 12, YEL)
    i.line(2, 6, 9, 2, YEL); i.rect(3, 4, 9, 6, YEL); i.rect(9, 3, 13, 6, YEL)
    i.rect(2, 11, 13, 12, YEL_D)
    i.disc(5.5, 9, 1.2, YEL_D); i.disc(10, 8.5, 1.0, YEL_D); i.put(8, 11, YEL_D)

# ---------------------------------------------------------------- mobility
@icon("ladder")
def _(i):
    i.rect(4, 1, 5, 14, WOOD_D)
    i.rect(10, 1, 11, 14, WOOD_D)
    for y in (3, 6, 9, 12):
        i.rect(6, y, 9, y, WOOD_L)

@icon("spring")
def _(i):
    i.rect(2, 13, 13, 14, STEEL_D)
    for k, y in enumerate(range(5, 13)):
        x = 5 if k % 2 == 0 else 9
        i.rect(x, y, x + 2, y, STEEL)
    i.line(5, 6, 11, 5, STEEL_L)
    i.rect(3, 2, 12, 3, GREEN)
    i.rect(3, 4, 12, 4, GREEN_D)

@icon("highway")
def _(i):
    for y in (3, 7, 11):
        i.rect(1, y, 14, y + 2, WOOD_L)
        i.rect(1, y + 2, 14, y + 2, WOOD)
    i.pts([(4, 4), (11, 8), (7, 12)], WOOD_D)
    i.pts([(15, 5), (15, 9)], YEL)

@icon("conveyor")
def _(i):
    i.rect(1, 6, 14, 11, STEEL_D)
    i.rect(1, 6, 14, 6, STEEL)
    i.disc(2.5, 8.5, 2.2, GREY); i.disc(13.5, 8.5, 2.2, GREY)
    i.rect(5, 8, 9, 9, YEL)
    i.pts([(10, 7), (10, 10), (11, 8), (11, 9)], YEL)

# ---------------------------------------------------------------- construction
@icon("gate")
def _(i):
    i.rect(2, 1, 13, 14, BLUE_L)
    i.rect(2, 1, 13, 2, BLUE)
    for x in (4, 7, 10):
        i.rect(x, 3, x, 14, BLUE)
    i.rect(2, 8, 13, 8, BLUE_D)
    i.pts([(12, 3), (12, 4)], WHITE)

@icon("teamblock")
def _(i):
    i.rect(2, 3, 13, 13, BLUE)
    i.rect(2, 3, 13, 4, BLUE_L)
    i.rect(12, 5, 13, 13, BLUE_D)
    i.rect(2, 13, 13, 13, BLUE_D)
    i.rect(6, 7, 9, 10, BLUE_L)      # a team crest
    i.pts([(7, 8), (8, 9)], WHITE)

@icon("stash")
def _(i):
    i.rect(1, 6, 14, 14, WOOD)
    i.rect(1, 3, 14, 6, WOOD_L)
    i.rect(1, 3, 7, 4, BLUE); i.rect(8, 3, 14, 4, REDT)     # half blue, half red lid trim
    i.rect(1, 10, 14, 10, WOOD_D)
    i.rect(6, 7, 9, 11, YEL); i.rect(7, 9, 8, 10, YEL_D)    # brass lock
    i.rect(1, 14, 14, 14, WOOD_D)

# ---------------------------------------------------------------- traps
@icon("trap")
def _(i):
    i.rect(1, 11, 14, 13, WOOD_L)
    i.rect(1, 13, 14, 13, WOOD_D)
    i.line(3, 10, 3, 5, STEEL); i.line(3, 5, 9, 5, STEEL); i.line(9, 5, 9, 10, STEEL)   # the snap bar
    i.rect(11, 8, 13, 10, YEL)           # bait
    i.put(12, 8, YEL_D)

@icon("tnt")
def _(i):
    i.rect(4, 5, 11, 14, RED)
    i.rect(4, 5, 5, 14, RED_D)
    i.rect(4, 9, 11, 10, WHITE)
    i.line(8, 4, 9, 1, BLACK)
    i.pts([(10, 0), (10, 1), (11, 1)], YEL); i.put(11, 0, ORANGE)

@icon("dynamite")
def _(i):
    for x in (3, 6, 9):
        i.rect(x, 6, x + 2, 14, RED)
        i.rect(x, 6, x, 14, RED_D)
    i.rect(3, 10, 11, 10, BLACK)
    i.line(7, 5, 10, 2, BLACK); i.line(10, 2, 12, 3, BLACK)
    i.pts([(13, 2), (13, 3), (14, 2)], YEL); i.put(14, 1, ORANGE)

@icon("sticky")
def _(i):
    i.rect(2, 10, 13, 13, GOO)
    i.rect(4, 8, 11, 9, GOO)
    i.rect(6, 6, 8, 7, GOO)
    i.pts([(3, 14), (9, 14), (12, 14)], GOO)
    i.pts([(5, 9), (9, 11), (7, 7)], GOO_L)
    i.rect(2, 13, 13, 13, GREEN_D)

@icon("pitfall")
def _(i):
    i.rect(1, 3, 14, 5, GREEN)
    i.rect(1, 3, 14, 3, GOO_L)
    i.rect(1, 6, 14, 14, DIRT)
    i.rect(4, 6, 11, 14, BLACK)
    i.pts([(4, 6), (11, 6)], DIRT_D)
    i.pts([(7, 4), (8, 4)], GREEN_D)

@icon("wallspring")
def _(i):
    i.rect(1, 2, 5, 13, STONE)
    i.rect(1, 2, 5, 2, STONE_L)
    for k, x in enumerate(range(6, 11)):
        y = 5 if k % 2 == 0 else 9
        i.rect(x, y, x, y + 2, STEEL)
    i.rect(11, 3, 12, 12, GREEN)
    i.rect(13, 3, 13, 12, GREEN_D)

@icon("decoy")
def _(i):
    # a cheese wedge that isn't: green stink curling off it
    i.rect(2, 8, 12, 13, YEL)
    i.line(2, 7, 8, 4, YEL); i.rect(3, 5, 8, 7, YEL); i.rect(8, 4, 12, 7, YEL)
    i.rect(2, 12, 12, 13, YEL_D)
    i.disc(5.5, 10, 1.1, YEL_D); i.disc(9.5, 9.5, 0.9, YEL_D)
    i.pts([(12, 3), (13, 2), (14, 3), (13, 1), (14, 0)], GOO)
    i.pts([(10, 2), (11, 1), (10, 0)], GOO_L)

@icon("teleporter")
def _(i):
    # a round pad with a beam of light rising off it
    i.rect(2, 12, 13, 14, STEEL_D)
    i.rect(3, 12, 12, 12, STEEL)
    i.rect(4, 11, 11, 11, BLUE)
    i.rect(5, 3, 10, 10, BLUE_L)
    i.rect(6, 2, 9, 10, WHITE)
    i.pts([(3, 6), (12, 4), (2, 9), (13, 8), (4, 2), (11, 1)], BLUE_L)

@icon("windup")
def _(i):
    # a clockwork mouse with a brass key in its back
    i.disc(7.0, 10.5, 4.0, STEEL)
    i.rect(3, 12, 11, 13, STEEL_D)
    i.pts([(5, 8), (6, 7), (7, 7)], STEEL_L)
    i.disc(10.5, 7.5, 1.7, PINK)
    i.pts([(11, 9), (12, 10), (12, 11), (13, 11)], STEEL)
    i.put(14, 11, PINK)
    i.put(11, 10, BLACK)
    i.pts([(2, 11), (1, 10), (1, 9), (2, 8)], PINK)
    i.disc(4.5, 14.5, 1.0, BLACK); i.disc(9.5, 14.5, 1.0, BLACK)
    i.rect(6, 4, 6, 6, YEL_D)
    i.rect(3, 2, 5, 3, YEL); i.rect(7, 2, 9, 3, YEL)
    i.pts([(4, 2), (8, 2)], YEL_D)

@icon("squeaker")
def _(i):
    # a rubber pad with a squeaky bulb, and the squeak
    i.rect(1, 11, 14, 13, BLUE_D)
    i.rect(2, 11, 13, 11, BLUE)
    i.rect(5, 8, 10, 10, YEL)
    i.rect(6, 7, 9, 7, YEL)
    i.pts([(6, 8), (7, 7)], WHITE)
    i.pts([(3, 4), (2, 5), (3, 6)], WHITE)      # sound arcs
    i.pts([(12, 4), (13, 5), (12, 6)], WHITE)
    i.pts([(1, 3), (0, 5), (1, 7)], STEEL_L)
    i.pts([(14, 3), (15, 5), (14, 7)], STEEL_L)

# ---------------------------------------------------------------- siege
@icon("cannon")
def _(i):
    i.line(4, 9, 12, 3, STEEL_D); i.line(4, 8, 12, 2, STEEL); i.line(5, 9, 13, 3, STEEL_D)
    i.rect(12, 1, 14, 3, STEEL_D)
    i.rect(2, 9, 11, 11, WOOD)
    i.disc(4.5, 12.5, 2.4, GREY); i.disc(10.5, 12.5, 2.4, GREY)
    i.put(4, 12, STEEL_L); i.put(10, 12, STEEL_L)

@icon("crane")
def _(i):
    i.rect(3, 2, 4, 14, YEL_D)
    i.line(4, 2, 12, 2, YEL)
    i.rect(1, 13, 7, 14, WOOD_D)
    i.line(12, 3, 12, 8, BLACK)
    i.disc(12, 10.5, 2.4, STEEL_D)
    i.put(11, 9, STEEL_L)

@icon("dozer")
def _(i):
    i.rect(4, 5, 11, 10, YEL)
    i.rect(6, 3, 10, 5, YEL_D)
    i.rect(7, 4, 9, 4, ICE)              # cab window
    i.rect(3, 10, 12, 13, BLACK)
    i.pts([(5, 11), (8, 11), (11, 11)], GREY)
    i.rect(12, 5, 14, 13, STEEL)         # the blade
    i.rect(14, 5, 14, 13, STEEL_D)

# ---------------------------------------------------------------- gear
@icon("jetpack")
def _(i):
    i.rect(3, 2, 6, 10, STEEL)
    i.rect(9, 2, 12, 10, STEEL)
    i.rect(3, 2, 6, 3, RED); i.rect(9, 2, 12, 3, RED)
    i.rect(7, 4, 8, 8, WOOD_D)           # straps
    i.rect(4, 11, 5, 11, STEEL_D); i.rect(10, 11, 11, 11, STEEL_D)
    i.pts([(4, 12), (5, 12), (10, 12), (11, 12), (4, 13), (11, 13)], ORANGE)
    i.pts([(5, 13), (10, 13), (4, 14), (11, 14)], YEL)

@icon("shield")
def _(i):
    # the Rat Knight Shield: a steel-rimmed heater shield with a cheese crest
    rows = {2: (3, 12), 3: (3, 12), 4: (3, 12), 5: (3, 12), 6: (3, 12), 7: (3, 12), 8: (3, 12),
            9: (4, 11), 10: (4, 11), 11: (5, 10), 12: (6, 9), 13: (7, 8)}
    for y, (x0, x1) in rows.items():
        i.rect(x0, y, x1, y, STEEL_D)
        if x1 - x0 > 1 and 2 < y < 13:
            i.rect(x0 + 1, y, x1 - 1, y, BLUE if y < 8 else BLUE_D)
    i.rect(4, 3, 11, 3, STEEL_L)              # light along the top edge
    i.rect(7, 3, 8, 12, STEEL)                # the centre band
    i.rect(6, 5, 9, 7, YEL)                   # cheese crest
    i.pts([(6, 5), (9, 7)], YEL_D)
    i.pts([(7, 6)], YEL_D)

@icon("bubbles")
def _(i):
    # a shoe stepping onto a bubble
    i.disc(8, 11.5, 3.6, BLUE_L)
    i.disc(8, 11.5, 2.6, ICE_L)
    i.pts([(6, 10), (7, 9)], WHITE)
    i.rect(3, 4, 10, 7, RED)                   # the shoe
    i.rect(3, 4, 5, 2, RED)
    i.rect(3, 2, 5, 3, RED)
    i.rect(3, 7, 11, 8, WHITE)                 # its sole
    i.pts([(4, 5), (6, 5)], WHITE)             # laces
    i.disc(13, 4, 1.4, BLUE_L); i.put(12, 3, WHITE)
    i.disc(13.5, 8.5, 0.9, BLUE_L)

# ---------------------------------------------------------------- tools
@icon("chisel")
def _(i):
    i.line(3, 13, 8, 8, WOOD)
    i.line(4, 13, 9, 8, WOOD_D)
    i.rect(8, 6, 9, 7, STEEL_D)
    i.line(9, 6, 13, 2, STEEL); i.line(10, 6, 13, 3, STEEL_L)
    i.pts([(13, 7), (14, 9), (12, 9)], STONE_L)   # chips

@icon("pantograph")
def _(i):
    i.rect(1, 6, 7, 12, BLUE_L)              # original
    i.rect(1, 6, 7, 6, BLUE)
    i.rect(8, 2, 14, 8, YEL)                 # its copy
    i.rect(8, 2, 14, 2, YEL_D)
    i.line(5, 4, 9, 4, WHITE); i.pts([(8, 3), (8, 5)], WHITE)    # copy arrow
    i.line(10, 10, 13, 13, STEEL)            # a little drafting arm
    i.line(12, 10, 10, 12, STEEL)

# ---------------------------------------------------------------- abilities
@icon("superdig")
def _(i):
    i.line(3, 13, 10, 6, WOOD)
    i.line(4, 13, 11, 6, WOOD_D)
    i.line(6, 3, 14, 7, STEEL); i.line(7, 2, 14, 6, STEEL_L)
    i.pts([(1, 4), (2, 5), (3, 3), (2, 2), (4, 6)], YEL)      # impact sparks

@icon("sniff")
def _(i):
    i.disc(5, 10, 3.6, GREY)
    i.rect(7, 9, 9, 11, GREY)
    i.put(10, 10, PINK); i.put(9, 9, GREY)
    i.put(4, 9, BLACK)
    for x, y in ((11, 6), (12, 5), (13, 6), (14, 5), (11, 3), (12, 2), (13, 3)):
        i.put(x, y, YEL)

@icon("beacon")
def _(i):
    i.rect(4, 1, 4, 14, WOOD_D)
    i.rect(5, 2, 12, 7, BLUE)
    i.rect(5, 2, 12, 2, BLUE_L)
    i.pts([(8, 4), (9, 4), (8, 5)], WHITE)
    i.rect(2, 14, 7, 14, STONE)

@icon("patch")
def _(i):
    for gx in range(3):
        for gy in range(3):
            i.rect(1 + gx * 5, 1 + gy * 5, 4 + gx * 5, 4 + gy * 5, DIRT if (gx + gy) % 2 else DIRT_L)
    i.rect(7, 5, 8, 10, WHITE); i.rect(5, 7, 10, 8, WHITE)

@icon("detonate")
def _(i):
    i.rect(3, 8, 12, 14, WOOD)
    i.rect(3, 8, 12, 8, WOOD_L)
    i.rect(7, 3, 8, 7, STEEL)
    i.rect(4, 2, 11, 3, STEEL_D)
    i.pts([(13, 10), (14, 9), (15, 10)], RED)   # wire

@icon("plant")
def _(i):
    i.rect(5, 7, 10, 14, RED)
    i.rect(5, 10, 10, 10, WHITE)
    i.rect(7, 0, 8, 4, YEL)
    i.pts([(5, 3), (6, 4), (9, 4), (10, 3)], YEL)   # "place it here" arrow

# ---------------------------------------------------------------- menu buttons
@icon("online")
def _(i):
    i.disc(8, 8, 6.4, BLUE)
    i.rect(3, 5, 7, 8, GREEN); i.rect(9, 8, 12, 11, GREEN); i.rect(6, 11, 8, 12, GREEN)
    i.pts([(5, 4), (11, 4)], BLUE_L)

@icon("book")
def _(i):
    i.rect(2, 2, 13, 13, RED)
    i.rect(2, 2, 3, 13, RED_D)
    i.rect(5, 4, 12, 11, WHITE)
    for y in (6, 8, 10):
        i.rect(6, y, 11, y, STONE)

@icon("door")
def _(i):
    i.rect(3, 1, 12, 14, WOOD)
    i.rect(3, 1, 12, 2, WOOD_L)
    i.rect(5, 4, 10, 7, WOOD_D)
    i.rect(5, 9, 10, 12, WOOD_D)
    i.put(10, 8, YEL)


COLS = 8
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main() -> int:
    from PIL import ImageDraw
    os.makedirs(OUT, exist_ok=True)
    ids = list(ICONS.keys())
    rows = (len(ids) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * N, rows * N), (0, 0, 0, 0))
    for k, name in enumerate(ids):
        i = Icon()
        ICONS[name](i)
        sheet.alpha_composite(i.image(), ((k % COLS) * N, (k // COLS) * N))
    sheet.save(os.path.join(OUT, "icons.png"))
    with open(os.path.join(ROOT, "scripts", "ui", "icon_sheet.gd"), "w") as f:
        f.write("class_name IconSheet\n")
        f.write("## Generated by tools/make_icons.py: which icon is in which cell of\n")
        f.write("## res://assets/icons/icons.png (left to right, top to bottom).\n\n")
        f.write("const CELL := %d\n" % N)
        f.write("const COLS := %d\n" % COLS)
        f.write("const IDS := [%s]\n" % ", ".join('"%s"' % n for n in ids))
    # a labelled guide, 6x
    s = 6
    guide = Image.new("RGBA", (COLS * (N * s + 12) + 12, rows * (N * s + 28) + 12), (36, 28, 22, 255))
    d = ImageDraw.Draw(guide)
    for k, name in enumerate(ids):
        x = 12 + (k % COLS) * (N * s + 12)
        y = 12 + (k // COLS) * (N * s + 28)
        cell = sheet.crop(((k % COLS) * N, (k // COLS) * N, (k % COLS + 1) * N, (k // COLS + 1) * N))
        guide.alpha_composite(cell.resize((N * s, N * s), Image.NEAREST), (x, y))
        d.rectangle((x - 1, y - 1, x + N * s, y + N * s), outline=(90, 80, 70, 255))
        d.text((x, y + N * s + 4), "%d %s" % (k, name), fill=(240, 228, 200, 255))
    guide.save(os.path.join(ROOT, "docs", "icon_sheet_layout.png"))
    print("wrote %d icons into assets/icons/icons.png (+ scripts/ui/icon_sheet.gd, docs/icon_sheet_layout.png)" % len(ids))
    return 0


if __name__ == "__main__":
    sys.exit(main())
