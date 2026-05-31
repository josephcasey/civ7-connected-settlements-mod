#!/usr/bin/env python3
"""Generate the Connected Settlements mod preview graphic.

Output: 512x512 PNG (Steam Workshop / CivFanatics spec: square, <1 MB).
Rendered at 2x then downsampled with LANCZOS for crisp anti-aliasing.
"""
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024              # supersample canvas, downscaled to 512 at the end
OUT = "assets/preview.png"

# Civ7-ish palette: dark teal slate + antique gold
TOP    = (12, 33, 40)
BOT    = (6, 18, 23)
GOLD   = (206, 168, 88)
GOLD_HI= (236, 206, 140)
TEAL_HI= (46, 92, 102)
TOWN   = (120, 200, 180)   # towns lean teal
INK    = (228, 222, 206)
MUTE   = (150, 168, 168)

SERIF_B = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS_B  = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def vgradient(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    return base


def hexagon(cx, cy, r, flat_top=True):
    pts = []
    for i in range(6):
        a = math.radians(60 * i + (0 if flat_top else 30))
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_text_tracked(draw, xy, text, font, fill, tracking, anchor_center_x=None):
    """Draw text with letter spacing. If anchor_center_x set, center the run."""
    widths = [draw.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = (anchor_center_x - total / 2) if anchor_center_x is not None else xy[0]
    y = xy[1]
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=font, fill=fill)
        x += w + tracking
    return total


img = vgradient(S, S, TOP, BOT)
draw = ImageDraw.Draw(img, "RGBA")

# --- faint flat-top hex grid background -----------------------------------
grid = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(grid)
hr = 70
dx = hr * 1.5
dy = hr * math.sqrt(3)
col = 0
x = -hr
while x < S + hr:
    yoff = 0 if col % 2 == 0 else dy / 2
    y = -hr + yoff
    while y < S + hr:
        gd.line(hexagon(x, y, hr) + [hexagon(x, y, hr)[0]],
                fill=(70, 120, 130, 38), width=2)
        y += dy
    x += dx
    col += 1
img.paste(grid, (0, 0), grid)

# --- network of connected settlements -------------------------------------
cx, cy = S * 0.5, S * 0.40
# surrounding settlements: (angle_deg, distance, is_town)
ring = [
    (-150, 250, False),
    (-95,  300, True),
    (-35,  260, False),
    (30,   300, True),
    (95,   250, True),
]
nodes = []
for ang, dist, is_town in ring:
    a = math.radians(ang)
    nodes.append((cx + dist * math.cos(a), cy + dist * math.sin(a), is_town))

# connection lines (under nodes), with a soft glow pass
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gl = ImageDraw.Draw(glow)
for nx, ny, _ in nodes:
    gl.line([(cx, cy), (nx, ny)], fill=(206, 168, 88, 160), width=8)
glow = glow.filter(ImageFilter.GaussianBlur(7))
img.paste(glow, (0, 0), glow)
for nx, ny, _ in nodes:
    draw.line([(cx, cy), (nx, ny)], fill=(*GOLD, 220), width=4)

# small node dot at the midpoint to read as "link"
def node_city(d, x, y, r, fill, outline):
    d.polygon(hexagon(x, y, r), fill=fill, outline=outline, width=5)

def node_town(d, x, y, r, fill, outline):
    d.ellipse([x - r, y - r, x + r, y + r], fill=fill, outline=outline, width=5)

# surrounding nodes
for nx, ny, is_town in nodes:
    if is_town:
        node_town(draw, nx, ny, 30, (16, 40, 44, 255), TOWN)
        draw.ellipse([nx - 11, ny - 11, nx + 11, ny + 11], fill=TOWN)
    else:
        node_city(draw, nx, ny, 36, (20, 44, 40, 255), GOLD)
        draw.polygon(hexagon(nx, ny, 15), fill=GOLD)

# central (selected) settlement: glowing gold hex
cglow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cg = ImageDraw.Draw(cglow)
cg.polygon(hexagon(cx, cy, 78), fill=(236, 206, 140, 150))
cglow = cglow.filter(ImageFilter.GaussianBlur(22))
img.paste(cglow, (0, 0), cglow)
draw.polygon(hexagon(cx, cy, 62), fill=(28, 54, 50, 255), outline=GOLD_HI, width=7)
draw.polygon(hexagon(cx, cy, 34), fill=GOLD_HI)

# count badge on the central node
badge_n = str(len(nodes))
bf = ImageFont.truetype(SANS_B, 70)
bb = draw.textbbox((0, 0), badge_n, font=bf)
draw.text((cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2 - bb[1]),
          badge_n, font=bf, fill=(18, 38, 36))

# --- title block ----------------------------------------------------------
# divider rule
ry = S * 0.70
draw.line([(S * 0.16, ry), (S * 0.84, ry)], fill=(*GOLD, 200), width=3)
for ex in (S * 0.16, S * 0.84):
    draw.polygon(hexagon(ex, ry, 9, flat_top=False), fill=GOLD)

title_f = ImageFont.truetype(SERIF_B, 84)
draw_text_tracked(draw, (0, S * 0.735), "CONNECTED", title_f, GOLD_HI,
                  tracking=10, anchor_center_x=S / 2)
draw_text_tracked(draw, (0, S * 0.825), "SETTLEMENTS", title_f, GOLD_HI,
                  tracking=10, anchor_center_x=S / 2)

sub_f = ImageFont.truetype(SANS_B, 30)
draw_text_tracked(draw, (0, S * 0.935), "CIVILIZATION VII  •  CITY DETAILS",
                  sub_f, MUTE, tracking=6, anchor_center_x=S / 2)

# --- gold panel frame (Civ UI inset look) ---------------------------------
m = 24
draw.rectangle([m, m, S - m, S - m], outline=(*GOLD, 230), width=5)
draw.rectangle([m + 12, m + 12, S - m - 12, S - m - 12],
               outline=(*GOLD, 90), width=2)

# downscale for crisp anti-aliasing
final = img.resize((512, 512), Image.LANCZOS)
final.save(OUT, "PNG", optimize=True)
print("wrote", OUT)
