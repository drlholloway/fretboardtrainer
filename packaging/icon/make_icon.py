#!/usr/bin/env python3
"""Draw the Fretboard Trainer icon and write the platform masters.

The picture: a fretboard seen the way a chord diagram shows it (strings
vertical, frets horizontal) with Mothman spread across the strings. His red
eyes are the two inlay dots of the twelfth fret, so the board is staring back
at whoever is trying to learn it. Same cream-ink-and-red-eye language as the
Sightings icon.

Outputs (in apps/fretboard_trainer/assets/icon/):
  icon_1024.png        full-bleed square, rounded corners baked in (docs, legacy Android)
  icon_ios.png         full-bleed square, no alpha (iOS applies its own mask)
  icon_android_bg.png  adaptive-icon background layer: the fretboard
  icon_android_fg.png  adaptive-icon foreground layer: Mothman, inside the safe zone
  icon_macos.png       transparent canvas, Apple-style rounded square at 824/1024
  icon_512.png, icon_256.png  smaller copies of the full-bleed master
Run with: python3 packaging/icon/make_icon.py
"""
import os
import sys

from PIL import Image, ImageDraw

SS = 4  # supersampling factor
OUT = os.path.join(
    os.path.dirname(__file__), "..", "..", "apps", "fretboard_trainer", "assets", "icon"
)

WOOD = (74, 46, 26, 255)        # rosewood
WOOD_DARK = (58, 35, 19, 255)   # between the frets, towards the bottom
FRET = (196, 188, 172, 255)     # fret wire
STRING = (214, 204, 184, 255)   # strings
INLAY = (150, 132, 104, 255)    # ordinary inlay dot
INK = (242, 232, 213, 255)      # Mothman, cream like the Sightings trace
EYE = (201, 48, 48, 255)        # lead red

# Geometry in a 1000-unit square.
STRING_XS = [172, 303, 434, 566, 697, 828]           # six strings
FRET_YS = [80, 245, 410, 575, 740, 905]              # fret wires
EYE_Y = (FRET_YS[1] + FRET_YS[2]) / 2 + 10           # inside the "twelfth fret"
EYE_XS = (385, 615)                                  # where a double inlay sits


def catmull_rom(points, steps=24):
    """Closed Catmull-Rom spline through `points`."""
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = (points[(i + k - 1) % n] for k in range(4))
        for t in (j / steps for j in range(steps)):
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def draw_board(img, box):
    """Fretboard background into box = (x, y, size)."""
    x0, y0, size = box
    s = size / 1000.0
    d = ImageDraw.Draw(img)

    def P(x, y):
        return (x0 + x * s, y0 + y * s)

    d.rectangle([P(0, 0), P(1000, 1000)], fill=WOOD)
    # Slightly darker lower half so the board has some depth.
    d.rectangle([P(0, FRET_YS[3]), P(1000, 1000)], fill=WOOD_DARK)
    # Inlays: a single dot two frets below the eyes, like a real neck.
    r = 26
    cy = (FRET_YS[3] + FRET_YS[4]) / 2
    d.ellipse([P(500 - r, cy - r), P(500 + r, cy + r)], fill=INLAY)
    # Fret wires.
    for y in FRET_YS:
        d.line([P(-10, y), P(1010, y)], fill=FRET, width=int(11 * s))
    # Strings, thicker towards the bass side (left).
    for i, x in enumerate(STRING_XS):
        w = 22 - i * 2.4
        d.line([P(x, -10), P(x, 1010)], fill=STRING, width=int(w * s))


def draw_mothman(img, box):
    """Mothman silhouette with red eyes into box = (x, y, size).

    Headless, eyes set in the shoulders, as in the Point Pleasant reports;
    the eyes land exactly on the twelfth-fret inlay dots.
    """
    x0, y0, size = box
    s = size / 1000.0

    def P(x, y):
        return (x0 + x * s, y0 + y * s)

    # Draw on a separate layer so scallops can be cut out with transparency.
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    CLEAR = (0, 0, 0, 0)

    def disc(cx, cy, r, fill):
        ld.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill)

    # Wings: a swept shape from the shoulder up to a high tip, then down the
    # outside to a lower tip and back to the hip. Mirrored for the right wing.
    wing = [
        (440, 330),   # shoulder
        (300, 200),   # upper edge
        (120, 120),   # upper tip
        (60, 300),    # outer edge
        (70, 520),
        (150, 760),   # lower tip
        (300, 740),   # lower edge
        (420, 640),   # hip
    ]
    scallops = [(52, 420, 62), (72, 640, 56), (215, 790, 60), (345, 770, 44)]
    for sx in (1, -1):
        pts = [(500 + sx * (x - 500), y) for x, y in wing]
        ld.polygon([P(x, y) for x, y in catmull_rom(pts)], fill=INK)
        for cx, cy, r in scallops:
            disc(500 + sx * (cx - 500), cy, r, CLEAR)

    # Torso: broad shoulders that hold the eyes, tapering to two legs.
    torso = [
        (335, 300), (420, 232), (500, 218), (580, 232), (665, 300),
        (660, 470), (615, 690), (590, 900), (500, 905), (410, 900),
        (385, 690), (340, 470),
    ]
    ld.polygon([P(x, y) for x, y in catmull_rom(torso)], fill=INK)
    # Gap between the legs.
    ld.polygon([P(500, 700), P(536, 910), P(464, 910)], fill=CLEAR)
    # Short antennae, the one moth-like cue.
    for sx in (-1, 1):
        ld.line([P(500 + sx * 60, 232), P(500 + sx * 120, 100)], fill=INK, width=int(15 * s))
        disc(500 + sx * 120, 100, 14, INK)

    img.alpha_composite(layer)

    # Eyes on the twelfth-fret inlay positions.
    d = ImageDraw.Draw(img)
    r = 50
    for ex in EYE_XS:
        d.ellipse([P(ex - r - 7, EYE_Y - r - 7), P(ex + r + 7, EYE_Y + r + 7)], fill=(120, 30, 30, 255))
        d.ellipse([P(ex - r, EYE_Y - r), P(ex + r, EYE_Y + r)], fill=EYE)
        d.ellipse([P(ex - 24, EYE_Y - 24), P(ex - 6, EYE_Y - 6)], fill=(255, 196, 186, 255))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def render(canvas, draw_fn):
    big = Image.new("RGBA", (canvas * SS, canvas * SS), (0, 0, 0, 0))
    draw_fn(big)
    return big.resize((canvas, canvas), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    N = 1024

    def full_square(big):
        draw_board(big, (0, 0, N * SS))
        draw_mothman(big, (0, 0, N * SS))

    # 1. iOS: opaque square, Apple masks it.
    square = render(N, full_square)
    square.convert("RGB").save(os.path.join(OUT, "icon_ios.png"))

    # 2. Full-bleed master with rounded corners (docs, legacy Android launchers).
    full_img = square.copy()
    full_img.putalpha(rounded_mask(N, int(N * 0.18)))
    full_img.save(os.path.join(OUT, "icon_1024.png"))
    full_img.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))
    full_img.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "icon_256.png"))

    # 3. Android adaptive layers. Launchers show the inner 72/108 of each layer
    #    and the safe zone is a 66/108 circle, so the board is drawn full-bleed
    #    (it is a pattern, cropping is fine) with its fret spacing scaled so the
    #    visible window matches the square icon, and Mothman sits in the
    #    central 61% square (inside the safe circle).
    def bg(big):
        inner = int(N * SS * 72 / 108)
        off = (N * SS - inner) // 2
        # Draw the board larger than the canvas so the visible 72/108 window
        # shows the same composition as the square icon.
        ImageDraw.Draw(big).rectangle([0, 0, big.size[0], big.size[1]], fill=WOOD)
        draw_board(big, (off, off, inner))
        # Extend fret wires and strings across the bleed area.
        d = ImageDraw.Draw(big)
        s = inner / 1000.0
        for y in FRET_YS:
            yy = off + y * s
            d.line([(0, yy), (big.size[0], yy)], fill=FRET, width=int(11 * s))
        for i, x in enumerate(STRING_XS):
            xx = off + x * s
            d.line([(xx, 0), (xx, big.size[1])], fill=STRING, width=int((22 - i * 2.4) * s))
        # Keep the darker lower band consistent across the bleed too.
        band = off + FRET_YS[3] * s
        dark = Image.new("RGBA", big.size, (0, 0, 0, 0))
        ImageDraw.Draw(dark).rectangle([0, band, big.size[0], big.size[1]], fill=WOOD_DARK)
        big.paste(dark, (0, 0), dark)
        draw_board(big, (off, off, inner))

    render(N, bg).save(os.path.join(OUT, "icon_android_bg.png"))

    def fg(big):
        inner = int(N * SS * 72 / 108)
        off = (N * SS - inner) // 2
        draw_mothman(big, (off, off, inner))

    render(N, fg).save(os.path.join(OUT, "icon_android_fg.png"))

    # 4. macOS: rounded square 824/1024 centered on a transparent canvas.
    def mac(big):
        inner = int(N * SS * 824 / 1024)
        off = (N * SS - inner) // 2
        tile = Image.new("RGBA", (inner, inner), WOOD)
        draw_board(tile, (0, 0, inner))
        draw_mothman(tile, (0, 0, inner))
        tile.putalpha(rounded_mask(inner, int(inner * 0.225)))
        big.paste(tile, (off, off), tile)

    render(N, mac).save(os.path.join(OUT, "icon_macos.png"))
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    sys.exit(main())
