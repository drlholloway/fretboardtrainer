#!/usr/bin/env python3
"""Draw the launch splash scenes: cryptids playing fretted instruments.

Same language as the icon: cream-ink silhouettes with glowing eyes, here
under a night sky instead of on a fretboard. The app picks one at random on
every launch and lays the wordmark and caption over it, so the pictures carry
no text. Subjects stay inside the central band so a cover fit on a tablet or
a tall phone crops only sky and ground.

Outputs (in apps/fretboard_trainer/assets/splash/), 1080x1920:
  mothman.png  bigfoot.png  nessie.png  jersey_devil.png  jackalope.png
  chupacabra.png
Run with: uv run --with pillow packaging/splash/make_splash.py
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 3  # supersampling factor
OUT = os.path.join(
    os.path.dirname(__file__), "..", "..", "apps", "fretboard_trainer", "assets", "splash"
)
W, H = 1000, 1778          # drawing units; rendered at 1080x1920
PX_W, PX_H = 1080, 1920
GROUND = 1330              # horizon line in drawing units

SKY_TOP = (22, 16, 24, 255)       # matches the native launch screens
SKY_LOW = (54, 36, 40, 255)
MOON = (236, 224, 198, 255)
STAR = (236, 224, 198, 255)
FAR = (38, 27, 32, 255)           # distant hills, trees
NEAR = (30, 21, 25, 255)          # ground
INK = (242, 232, 213, 255)        # the cryptids, as in the icon
INK_SHADE = (214, 200, 176, 255)  # limbs behind the instrument
WOOD = (122, 72, 38, 255)
WOOD_LIGHT = (176, 112, 58, 255)
WOOD_DARK = (74, 46, 26, 255)
NECK = (58, 35, 19, 255)
FRET = (196, 188, 172, 255)
STRING = (230, 222, 204, 255)
BRASS = (216, 170, 84, 255)
RED = (201, 48, 48, 255)
AMBER = (232, 163, 61, 255)
GREEN = (126, 200, 96, 255)
BLACK = (22, 16, 24, 255)


# ---------------------------------------------------------------------------
# Drawing helpers. Everything is in drawing units and scaled by `S` on output.

class Canvas:
    def __init__(self):
        self.s = PX_W * SS / W
        self.img = Image.new("RGB", (PX_W * SS, PX_H * SS), SKY_TOP[:3])
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def glow(self, cx, cy, r, color, alpha, blur):
        """A soft halo: a blurred disc used as the paste mask for a flat color."""
        s = self.s
        mask = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(mask).ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s],
                                     fill=alpha)
        self.img.paste(color[:3], (0, 0, *self.img.size), mask.filter(ImageFilter.GaussianBlur(blur * s)))

    def overlay(self, layer):
        self.img.paste(layer, (0, 0), layer)

    def p(self, pts):
        return [(x * self.s, y * self.s) for x, y in pts]

    def poly(self, pts, fill, smooth=False):
        if smooth:
            pts = catmull_rom(pts)
        self.d.polygon(self.p(pts), fill=fill)

    def disc(self, cx, cy, r, fill):
        s = self.s
        self.d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=fill)

    def line(self, a, b, w, fill, caps=True):
        self.d.line(self.p([a, b]), fill=fill, width=max(1, int(w * self.s)))
        if caps:
            self.disc(*a, w / 2, fill)
            self.disc(*b, w / 2, fill)

    def limb(self, pts, w0, w1, fill):
        """A tapered stroke through `pts`, round at every joint."""
        n = len(pts) - 1
        for i in range(n):
            wa = w0 + (w1 - w0) * i / n
            wb = w0 + (w1 - w0) * (i + 1) / n
            a, b = pts[i], pts[i + 1]
            ang = math.atan2(b[1] - a[1], b[0] - a[0]) + math.pi / 2
            ca, sa = math.cos(ang), math.sin(ang)
            self.poly([
                (a[0] + ca * wa / 2, a[1] + sa * wa / 2),
                (b[0] + ca * wb / 2, b[1] + sa * wb / 2),
                (b[0] - ca * wb / 2, b[1] - sa * wb / 2),
                (a[0] - ca * wa / 2, a[1] - sa * wa / 2),
            ], fill)
            self.disc(*a, wa / 2, fill)
        self.disc(*pts[-1], w1 / 2, fill)

    def eye(self, cx, cy, r, color, glow=True):
        if glow:
            self.glow(cx, cy, r * 3.2, color, 110, r * 1.4)
        self.disc(cx, cy, r, color)
        self.disc(cx - r * 0.3, cy - r * 0.3, r * 0.28, (255, 214, 200, 255))


def catmull_rom(points, steps=16, closed=True):
    n = len(points)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        if closed:
            p0, p1, p2, p3 = (points[(i + k - 1) % n] for k in range(4))
        else:
            p0 = points[max(i - 1, 0)]
            p1, p2 = points[i], points[i + 1]
            p3 = points[min(i + 2, n - 1)]
        for t in (j / steps for j in range(steps)):
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    if not closed:
        out.append(points[-1])
    return out


def ellipse_pts(cx, cy, rx, ry, n=64):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n))
            for i in range(n)]


def shaggy(pts, depth, seed, every=1):
    """Roughen a closed outline: push alternate points out along the normal."""
    rng = random.Random(seed)
    n = len(pts)
    out = []
    for i, (x, y) in enumerate(pts):
        if i % every:
            out.append((x, y))
            continue
        ax, ay = pts[i - 1]
        bx, by = pts[(i + 1) % n]
        nx, ny = by - ay, -(bx - ax)
        ln = math.hypot(nx, ny) or 1
        k = depth * (0.5 + rng.random()) * (1 if i % 2 else -0.4)
        out.append((x + nx / ln * k, y + ny / ln * k))
    return out


class Frame:
    """Local coordinates for an instrument: origin at the bridge end of the
    body, neck along -y, rotated by `deg` (clockwise) and scaled by `k`."""

    def __init__(self, cx, cy, deg, k):
        self.cx, self.cy, self.k = cx, cy, k
        a = math.radians(deg)
        self.c, self.s = math.cos(a), math.sin(a)

    def __call__(self, x, y):
        x, y = x * self.k, y * self.k
        return (self.cx + x * self.c - y * self.s, self.cy + x * self.s + y * self.c)

    def pts(self, pts):
        return [self(x, y) for x, y in pts]


# ---------------------------------------------------------------------------
# Backdrops

def sky(c, moon=(760, 330, 120), seed=1):
    top = SKY_TOP
    low = SKY_LOW
    for y in range(0, GROUND + 1, 4):
        t = (y / GROUND) ** 1.6
        col = tuple(int(top[i] + (low[i] - top[i]) * t) for i in range(3)) + (255,)
        c.d.rectangle([0, y * c.s, W * c.s, (y + 5) * c.s], fill=col)
    rng = random.Random(seed)
    for _ in range(90):
        x, y = rng.uniform(0, W), rng.uniform(0, GROUND * 0.7)
        r = rng.choice([1.2, 1.6, 2.2, 3.0])
        c.disc(x, y, r, STAR[:3] + (int(rng.uniform(90, 230)),))
    if moon:
        mx, my, mr = moon
        c.glow(mx, my, mr * 2, MOON, 50, mr * 0.6)
        c.disc(mx, my, mr, MOON)
        # A couple of maria so it reads as the moon rather than a spotlight.
        for dx, dy, r in ((-35, -25, 28), (30, 20, 20), (-10, 45, 14)):
            c.disc(mx + dx * mr / 120, my + dy * mr / 120, r * mr / 120, (218, 204, 176, 255))


def ground(c, color=NEAR, y=GROUND):
    c.d.rectangle([0, y * c.s, W * c.s, H * c.s], fill=color)


def hills(c, pts, color=FAR):
    c.poly([(-50, H), *pts, (W + 50, H)], color, smooth=False)


def pines(c, xs, base, color, seed=3, hmin=160, hmax=300):
    rng = random.Random(seed)
    for x in xs:
        h = rng.uniform(hmin, hmax)
        w = h * 0.36
        tiers = 4
        for t in range(tiers):
            ty = base - h + h * t / tiers * 0.9
            tw = w * (0.45 + 0.55 * (t + 1) / tiers)
            c.poly([(x, ty), (x + tw, ty + h * 0.42), (x - tw, ty + h * 0.42)], color)
        c.d.rectangle(c.p([(x - 6, base - 20), (x + 6, base + 4)])[0] + c.p([(x + 6, base + 4)])[0],
                      fill=color)


# ---------------------------------------------------------------------------
# Instruments. Drawn in a Frame; body at the origin, neck towards -y.

def neck(c, f, length, width, frets, strings, head=True, head_len=70, top_w=None):
    top_w = top_w or width * 0.86
    c.poly(f.pts([(-width / 2, 0), (-top_w / 2, -length), (top_w / 2, -length), (width / 2, 0)]), NECK)
    if head:
        c.poly(f.pts([(-top_w / 2, -length), (-top_w * 0.62, -length - head_len),
                      (top_w * 0.62, -length - head_len), (top_w / 2, -length)]), WOOD_DARK)
        # One tuner per string, split across the two sides (a banjo's fifth
        # string tunes from a peg on the neck instead).
        per_side = strings // 2
        for i in range(per_side):
            y = -length - head_len * (0.25 + 0.6 * i / max(per_side - 1, 1))
            for sx in (-1, 1):
                c.disc(*f(sx * top_w * 0.72, y), 6 * f.k, BRASS)
    # Frets: spacing shrinks up the neck like a real one, nut at -length.
    for i in range(frets + 1):
        t = 1 - 2 ** (-i / 12)
        y = -length + (length / (1 - 2 ** (-frets / 12))) * t
        half = (top_w + (width - top_w) * (y + length) / length) / 2
        c.line(f(-half, y), f(half, y), 3.2 * f.k if i else 5.5 * f.k,
               FRET if i else (236, 228, 212, 255), caps=False)
    return top_w


def strings(c, f, n, y0, y1, w0, w1):
    for i in range(n):
        u = (i + 0.5) / n - 0.5
        c.line(f(u * w0, y0), f(u * w1, y1), max(1.2, 2.4 - i * 0.2) * f.k, STRING, caps=False)


def electric_guitar(c, f):
    body = [(-40, 150), (-150, 120), (-170, 20), (-120, -60), (-150, -150),
            (-110, -175), (-60, -110), (0, -95), (55, -120), (95, -200),
            (135, -175), (120, -70), (165, 20), (145, 120), (40, 150)]
    c.poly(f.pts(body), RED, smooth=True)
    c.poly(f.pts([(-30, -80), (-110, -90), (-120, 20), (-60, 70), (20, 40), (10, -60)]),
           (236, 228, 212, 255), smooth=True)   # pickguard
    top = neck(c, f, 400, 48, 21, 6, head_len=90)
    for y in (-50, 10):
        c.poly(f.pts([(-30, y - 10), (30, y - 10), (30, y + 10), (-30, y + 10)]), BLACK)
    c.poly(f.pts([(-34, 60), (34, 60), (34, 80), (-34, 80)]), (180, 170, 150, 255))
    strings(c, f, 6, 70, -400, 36, top * 0.8)
    for i in range(2):
        c.disc(*f(90 + i * 22, 60 + i * 30), 11 * f.k, (236, 228, 212, 255))


def bass_guitar(c, f):
    body = [(-40, 170), (-165, 140), (-185, 30), (-130, -60), (-165, -170),
            (-120, -195), (-60, -120), (0, -105), (60, -135), (110, -235),
            (150, -205), (130, -70), (180, 30), (160, 140), (40, 170)]
    c.poly(f.pts(body), (58, 90, 140, 255), smooth=True)
    c.poly(f.pts([(-40, -95), (-120, -100), (-135, 20), (-70, 90), (30, 50), (15, -70)]),
           (20, 20, 24, 255), smooth=True)
    top = neck(c, f, 560, 50, 20, 4, head_len=110)
    c.poly(f.pts([(-34, -20), (34, -20), (34, 5), (-34, 5)]), BLACK)
    c.poly(f.pts([(-34, 80), (34, 80), (34, 100), (-34, 100)]), (180, 170, 150, 255))
    strings(c, f, 4, 90, -560, 38, top * 0.8)


def acoustic_guitar(c, f, scale=1.0, n=6, length=380):
    k = scale
    lower, upper = (0, 20 * k, 150 * k, 140 * k), (0, -160 * k, 115 * k, 100 * k)
    outline = [(-150 * k, 20 * k), (-140 * k, 110 * k), (-60 * k, 160 * k), (60 * k, 160 * k),
               (140 * k, 110 * k), (150 * k, 20 * k), (110 * k, -70 * k), (118 * k, -170 * k),
               (70 * k, -250 * k), (-70 * k, -250 * k), (-118 * k, -170 * k), (-110 * k, -70 * k)]
    del lower, upper
    c.poly(f.pts(outline), WOOD_DARK, smooth=True)
    c.poly(f.pts([(x * 0.93, y * 0.93 - 4 * k) for x, y in outline]), WOOD_LIGHT, smooth=True)
    c.poly(f.pts(ellipse_pts(0, -120 * k, 52 * k, 52 * k)), WOOD_DARK)
    c.poly(f.pts(ellipse_pts(0, -120 * k, 42 * k, 42 * k)), BLACK)
    top = neck(c, f.__class__(*f(0, -230 * k), math.degrees(math.atan2(f.s, f.c)), f.k),
               length, 44, 18, n, head_len=70)
    c.poly(f.pts([(-60 * k, 55 * k), (60 * k, 55 * k), (60 * k, 75 * k), (-60 * k, 75 * k)]), NECK)
    strings(c, f, n, 62 * k, -230 * k - length, 36, top * 0.8)


def banjo(c, f):
    c.poly(f.pts(ellipse_pts(0, 0, 150, 150)), (150, 150, 146, 255))       # rim
    c.poly(f.pts(ellipse_pts(0, 0, 134, 134)), (240, 232, 214, 255))       # head
    for i in range(24):
        a = 2 * math.pi * i / 24
        c.disc(*f(142 * math.cos(a), 142 * math.sin(a)), 4 * f.k, (210, 206, 196, 255))
    top = neck(c, f.__class__(*f(0, -130), math.degrees(math.atan2(f.s, f.c)), f.k),
               430, 40, 22, 5, head_len=80)
    c.poly(f.pts([(-40, 70), (40, 70), (40, 84), (-40, 84)]), WOOD_DARK)   # bridge
    strings(c, f, 5, 130, -560, 30, top * 0.8)
    c.disc(*f(26, -130 - 430 * 0.62), 7 * f.k, BRASS)                     # fifth-string peg


def fretting_arm(c, pts, w0, w1):
    """The arm reaching behind the neck: drawn before the instrument, with a
    shaded edge so it stays readable against a cream body or wing."""
    c.limb(pts, w0 + 8, w1 + 8, INK_SHADE)
    c.limb(pts, w0, w1, INK)


def fingertips(c, f, y, half_w, size=1.0):
    """Three fingers curling over the top edge of the neck at `y` (local)."""
    for i in range(3):
        yy = y + 13 * size - i * 26 * size
        a, b = f(-half_w - 6, yy), f(-half_w * 0.2, yy - 6 * size)
        c.limb([a, b], 16 * size, 12 * size, INK_SHADE)
        c.limb([a, b], 11 * size, 8 * size, INK)


# ---------------------------------------------------------------------------
# Scenes

def mothman(c):
    sky(c, moon=(800, 250, 85), seed=11)
    # The Silver Bridge's eyebar chains over the Ohio, low on the horizon.
    ground(c, (26, 20, 30, 255), GROUND - 10)
    for x in (140, 860):
        c.poly([(x - 18, GROUND - 10), (x - 10, GROUND - 260), (x + 10, GROUND - 260),
                (x + 18, GROUND - 10)], FAR)
    for side in (-1, 1):
        pts = [(500 + side * 700, GROUND - 60), (500 + side * 360, GROUND - 255),
               (500 + side * 200, GROUND - 170), (500, GROUND - 120)]
        c.poly([*pts, (500, GROUND - 112), *reversed([(x, y + 8) for x, y in pts])], FAR)
    c.d.rectangle(c.p([(0, GROUND - 80), (W, GROUND - 68)])[0] + c.p([(W, GROUND - 68)])[0], fill=FAR)
    for x in range(20, 1000, 40):
        c.line((x, GROUND - 74), (x, GROUND - 74 - 150 * math.exp(-((x - 140) / 260) ** 2)
                                  - 150 * math.exp(-((x - 860) / 260) ** 2)), 2, FAR, caps=False)

    ox, oy, k = 500, 440, 0.86

    def P(x, y):
        return (ox + (x - 500) * k, oy + y * k)

    wing = [(440, 330), (300, 200), (120, 120), (60, 300), (70, 520), (150, 760),
            (300, 740), (420, 640)]
    scallops = [(52, 420, 62), (72, 640, 56), (215, 790, 60), (345, 770, 44)]
    layer = Canvas()
    layer.img = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
    layer.d = ImageDraw.Draw(layer.img)  # no blending: scallops punch holes
    for sx in (1, -1):
        pts = [P(500 + sx * (x - 500), y) for x, y in wing]
        layer.poly(pts, INK, smooth=True)
        for cx, cy, r in scallops:
            layer.disc(*P(500 + sx * (cx - 500), cy), r * k, (0, 0, 0, 0))
    torso = [(335, 300), (420, 232), (500, 218), (580, 232), (665, 300), (660, 470),
             (615, 690), (590, 900), (500, 905), (410, 900), (385, 690), (340, 470)]
    layer.poly([P(x, y) for x, y in torso], INK, smooth=True)
    layer.poly([P(500, 700), P(536, 910), P(464, 910)], (0, 0, 0, 0))
    for sx in (-1, 1):
        layer.line(P(500 + sx * 60, 232), P(500 + sx * 120, 100), 15 * k, INK)
        layer.disc(*P(500 + sx * 120, 100), 14 * k, INK)
    c.overlay(layer.img)
    for ex in (385, 615):
        c.eye(*P(ex, 340), 44 * k, RED)

    f = Frame(*P(470, 660), 50, 0.95)
    # Right-handed: fretting arm behind the neck, picking hand over the strings.
    fretting_arm(c, [P(655, 420), P(760, 470), f(10, -300)], 36, 24)
    electric_guitar(c, f)
    fingertips(c, f, -300, 22)
    c.limb([P(345, 420), P(300, 600), f(-10, 10)], 36, 24, INK)
    c.disc(*f(-10, 10), 22, INK)


def bigfoot(c):
    sky(c, moon=(250, 300, 95), seed=21)
    hills(c, [(-50, GROUND - 150), (200, GROUND - 230), (420, GROUND - 160), (650, GROUND - 260),
              (900, GROUND - 170), (1050, GROUND - 210)])
    pines(c, range(-20, 1050, 70), GROUND - 60, (32, 24, 28, 255), seed=4, hmin=140, hmax=230)
    ground(c, NEAR, GROUND - 40)
    pines(c, [40, 130, 900, 975], GROUND + 20, (24, 17, 21, 255), seed=5, hmin=380, hmax=520)

    # Mid-stride, turned towards us as in the Patterson film still.
    body = [(500, 420), (560, 430), (600, 480), (700, 540), (760, 640), (770, 800),
            (730, 930), (700, 1040), (720, 1240), (760, 1300), (640, 1310), (600, 1100),
            (520, 1030), (470, 1110), (430, 1300), (300, 1310), (330, 1240), (320, 1060),
            (260, 930), (240, 780), (270, 620), (360, 520), (440, 470)]
    c.poly(shaggy(catmull_rom(body, steps=10), 14, seed=7, every=2), INK)
    head = [(500, 330), (545, 350), (570, 420), (560, 490), (500, 510), (440, 490),
            (430, 420), (455, 350)]
    c.poly(shaggy(catmull_rom(head, steps=8), 9, seed=8, every=2), INK)
    c.poly([(470, 400), (530, 400), (540, 420), (460, 420)], INK_SHADE)  # brow
    for ex in (478, 522):
        c.eye(ex, 440, 11, AMBER)
    f = Frame(470, 920, 40, 0.85)
    fretting_arm(c, [(700, 600), (790, 640), f(20, -420)], 70, 44)
    bass_guitar(c, f)
    fingertips(c, f, -420, 23, size=1.5)
    c.limb([(300, 600), (250, 800), f(-20, 20)], 70, 44, INK)
    c.poly(shaggy(ellipse_pts(*f(-20, 20), 34, 30, 24), 6, seed=10), INK)


def nessie(c):
    sky(c, moon=(760, 300, 105), seed=31)
    hills(c, [(-50, GROUND - 120), (180, GROUND - 330), (360, GROUND - 200), (560, GROUND - 260),
              (760, GROUND - 150), (1050, GROUND - 240)])
    # Urquhart Castle's tower on the far shore.
    c.poly([(840, GROUND - 170), (840, GROUND - 290), (900, GROUND - 290), (900, GROUND - 160)],
           (30, 22, 26, 255))
    for i in range(4):
        c.poly([(840 + i * 16, GROUND - 290), (840 + i * 16, GROUND - 302),
                (848 + i * 16, GROUND - 302), (848 + i * 16, GROUND - 290)], (30, 22, 26, 255))
    water = (34, 30, 44, 255)
    c.d.rectangle(c.p([(0, GROUND - 60), (W, H)])[0] + c.p([(W, H)])[0], fill=water)
    # Moon path on the water.
    for i in range(14):
        y = GROUND - 40 + i * 30
        w = 50 + i * 10
        c.poly([(760 - w, y), (760 + w, y), (760 + w * 0.8, y + 6), (760 - w * 0.8, y + 6)],
               (236, 224, 198, 30 + i * 3))

    # Two humps and a tail behind the neck.
    for cx, r in ((560, 130), (760, 95)):
        c.poly([(cx - r, GROUND + 60), *[(cx + r * math.cos(a), GROUND + 60 - r * 1.05 * math.sin(a))
                                          for a in [math.pi * i / 30 for i in range(31)][::-1]]],
               INK)
    c.poly(catmull_rom([(860, GROUND + 60), (900, GROUND - 10), (960, GROUND - 30),
                        (930, GROUND + 5), (900, GROUND + 60)]), INK)

    # The neck is the fretboard: wood on the front, cream along the back.
    f = Frame(380, GROUND + 60, -12, 1.0)
    c.poly(f.pts([(-80, 0), (-70, -300), (-58, -700), (-40, -760), (70, -760), (58, -560),
                  (70, -300), (100, 0)]), INK, smooth=False)
    top = neck(c, f, 700, 90, 12, 6, head=False, top_w=62)
    strings(c, f, 6, 0, -700, 78, top * 0.8)
    # Head at the top of the neck, where the headstock would be; its tuners are horns.
    hf = Frame(*f(10, -760), 0, 1.35)
    c.poly(catmull_rom(hf.pts([(-55, 25), (-60, -40), (0, -72), (90, -62), (165, -30),
                               (175, 0), (150, 18), (40, 30)])), INK)
    c.line(hf(110, 8), hf(165, 2), 3, INK_SHADE, caps=False)
    for dx in (-30, 10):
        c.line(hf(dx, -55), hf(dx - 12, -100), 9, INK)
        c.disc(*hf(dx - 12, -100), 10, BRASS)
    c.eye(*hf(60, -30), 11, GREEN)
    # Ripples where the neck breaks the water.
    for i, w in enumerate((150, 230, 320)):
        y = GROUND + 75 + i * 26
        c.poly(catmull_rom([(380 - w, y), (380, y - 8), (380 + w, y), (380, y + 5)]),
               (120, 110, 130, 120 - i * 30))


def jersey_devil(c):
    sky(c, moon=(260, 360, 110), seed=41)
    pines(c, range(-30, 1060, 55), GROUND - 20, (32, 24, 28, 255), seed=12, hmin=180, hmax=300)
    ground(c, NEAR, GROUND - 20)

    # Bat wings first.
    for sx in (-1, 1):
        root = (500 + sx * 40, 640)
        tips = [(500 + sx * 370, 370), (500 + sx * 390, 560), (500 + sx * 340, 750),
                (500 + sx * 230, 820)]
        pts = [root, (500 + sx * 200, 420), tips[0]]
        for a, b in zip(tips, tips[1:]):
            mx, my = (a[0] + b[0]) / 2 - sx * 45, (a[1] + b[1]) / 2 + 10
            pts += [(mx, my), b]
        pts += [(500 + sx * 60, 820)]
        c.poly(pts, INK)
        for t in tips:
            c.line(root, t, 7, INK_SHADE)
    # Body, standing on hind legs.
    body = [(500, 560), (570, 600), (590, 760), (570, 900), (600, 1000), (640, 1140),
            (620, 1290), (570, 1300), (560, 1160), (500, 1040), (440, 1160), (430, 1300),
            (380, 1290), (360, 1140), (400, 1000), (430, 900), (410, 760), (430, 600)]
    c.poly(body, INK, smooth=True)
    for x in (400, 600):
        c.poly([(x - 30, 1285), (x + 30, 1285), (x + 25, 1320), (x - 25, 1320)], INK_SHADE)
    # Forked tail curling out to the right.
    tail = catmull_rom([(560, 1080), (700, 1160), (800, 1080), (820, 980)], closed=False)
    c.limb(tail[::4] + [tail[-1]], 22, 8, INK)
    c.poly([(820, 950), (850, 1000), (800, 990)], INK)
    # Long horse head, horns, ears.
    head = [(470, 560), (455, 470), (470, 400), (520, 380), (560, 400), (575, 470),
            (560, 560), (545, 610), (490, 610)]
    c.poly(head, INK, smooth=True)
    for sx in (-1, 1):
        c.limb(catmull_rom([(500 + sx * 30, 395), (500 + sx * 80, 330), (500 + sx * 70, 260)],
                           closed=False)[::3] + [(500 + sx * 70, 260)], 18, 4, INK)
    for ex in (482, 548):
        c.eye(ex, 450, 13, AMBER)
    for nx in (500, 530):
        c.disc(nx, 585, 6, BLACK)

    f = Frame(460, 910, 42, 0.85)
    # Fretting arm behind the neck; only the fingertips come over the top.
    fretting_arm(c, [(565, 640), (660, 700), f(10, -440)], 32, 22)
    banjo(c, f)
    fingertips(c, f, -440, 24)
    c.limb([(435, 640), (360, 820), f(-30, 20)], 32, 22, INK)
    c.poly([f(-30, 20), f(-60, 40), f(-50, -10)], INK)


def jackalope(c):
    sky(c, moon=(740, 330, 100), seed=51)
    # Mesas.
    for x0, x1, top in ((-40, 280, GROUND - 260), (600, 1040, GROUND - 200)):
        c.poly([(x0, GROUND), (x0 + 60, top), (x1 - 60, top), (x1, GROUND)], FAR)
    ground(c, NEAR)
    # Sagebrush.
    for x in (120, 250, 800, 900):
        c.poly(shaggy(ellipse_pts(x, GROUND + 10, 60, 36, 30), 10, seed=x), (40, 34, 30, 255))

    # Sitting upright on a rock.
    c.poly(catmull_rom([(300, 1340), (330, 1230), (500, 1200), (690, 1240), (720, 1340)]),
           (46, 36, 36, 255))
    body = [(500, 720), (590, 760), (640, 880), (660, 1050), (640, 1180), (560, 1220),
            (440, 1220), (360, 1180), (340, 1050), (360, 880), (410, 760)]
    c.poly(body, INK, smooth=True)
    c.poly(ellipse_pts(640, 1180, 90, 40), INK_SHADE)      # hind foot
    c.poly(ellipse_pts(360, 1180, 90, 40), INK_SHADE)
    c.disc(690, 1120, 30, INK)                             # tail
    head = [(500, 560), (570, 580), (600, 650), (580, 740), (500, 770), (420, 740), (400, 650),
            (430, 580)]
    c.poly(head, INK, smooth=True)
    # Ears, then antlers branching above them.
    for sx in (-1, 1):
        c.poly(catmull_rom([(500 + sx * 30, 590), (500 + sx * 90, 430), (500 + sx * 120, 420),
                            (500 + sx * 80, 600)]), INK)
        c.poly(catmull_rom([(500 + sx * 42, 580), (500 + sx * 90, 460), (500 + sx * 102, 460),
                            (500 + sx * 70, 590)]), (230, 180, 170, 255))
        stem = [(500 + sx * 20, 580), (500 + sx * 40, 460), (500 + sx * 150, 300)]
        c.limb(stem, 16, 8, INK_SHADE)
        for t, (dx, dy) in ((0.45, (70, -60)), (0.8, (-10, -90)), (0.95, (80, -20))):
            bx = stem[1][0] + (stem[2][0] - stem[1][0]) * t
            by = stem[1][1] + (stem[2][1] - stem[1][1]) * t
            c.limb([(bx, by), (bx + sx * dx, by + dy)], 10, 5, INK_SHADE)
    for ex in (465, 535):
        c.eye(ex, 660, 12, AMBER)
    c.poly([(490, 705), (510, 705), (500, 718)], (200, 110, 110, 255))

    f = Frame(470, 1030, 50, 1.0)
    fretting_arm(c, [(600, 820), (680, 860), f(12, -350)], 34, 26)
    acoustic_guitar(c, f, scale=0.72, n=4, length=230)
    fingertips(c, f, -350, 20)
    c.limb([(400, 820), (350, 960), f(-20, -60)], 34, 26, INK)


def chupacabra(c):
    sky(c, moon=(270, 330, 110), seed=61)
    hills(c, [(-50, GROUND - 60), (300, GROUND - 120), (700, GROUND - 50), (1050, GROUND - 110)])
    ground(c, NEAR)
    # Saguaros.
    for x, h in ((130, 360), (880, 420)):
        cac = (32, 38, 30, 255)
        c.limb([(x, GROUND + 10), (x, GROUND - h)], 44, 40, cac)
        c.limb([(x, GROUND - h * 0.45), (x - 70, GROUND - h * 0.5), (x - 70, GROUND - h * 0.75)],
               30, 28, cac)
        c.limb([(x, GROUND - h * 0.6), (x + 60, GROUND - h * 0.62), (x + 60, GROUND - h * 0.85)],
               28, 26, cac)

    # Hunched on hind legs, a row of spines down the back.
    body = [(520, 560), (600, 620), (640, 760), (640, 920), (680, 1060), (700, 1200),
            (740, 1300), (620, 1300), (600, 1200), (520, 1080), (440, 1180), (420, 1300),
            (300, 1300), (350, 1180), (370, 1040), (380, 880), (380, 720), (430, 610)]
    c.poly(body, INK, smooth=True)
    spine_path = catmull_rom([(560, 520), (650, 640), (670, 820), (680, 1000)], closed=False)
    for i in range(0, len(spine_path) - 1, 5):
        x, y = spine_path[i]
        c.poly([(x - 16, y), (x + 70, y - 30 + i * 0.4), (x + 10, y + 26)], (190, 60, 70, 255))
    tail = catmull_rom([(640, 1150), (780, 1220), (880, 1180)], closed=False)
    c.limb(tail[::4] + [tail[-1]], 26, 6, INK)
    # Big alien head with almond eyes.
    head = [(520, 380), (600, 410), (630, 480), (600, 570), (540, 640), (480, 640), (430, 570),
            (410, 480), (440, 410)]
    c.poly(head, INK, smooth=True)
    for sx in (-1, 1):
        pts = [(520 + sx * 25, 505), (520 + sx * 55, 470), (520 + sx * 85, 480),
               (520 + sx * 70, 520), (520 + sx * 35, 530)]
        c.poly(catmull_rom(pts), RED)
        c.eye(520 + sx * 58, 500, 9, (255, 120, 110, 255))
    for fx in (505, 535):
        c.poly([(fx - 5, 600), (fx + 5, 600), (fx, 625)], (255, 255, 255, 255))

    f = Frame(470, 950, 35, 0.85)
    fretting_arm(c, [(610, 660), (700, 700), f(12, -560)], 30, 20)
    acoustic_guitar(c, f)
    fingertips(c, f, -560, 20, size=0.9)
    c.limb([(420, 660), (340, 850), f(-40, -60)], 30, 20, INK)
    for d in (-1, 0, 1):
        c.line(f(-40, -60), f(-5, -60 + d * 20), 6, INK)


SCENES = {
    "mothman": mothman,
    "bigfoot": bigfoot,
    "nessie": nessie,
    "jersey_devil": jersey_devil,
    "jackalope": jackalope,
    "chupacabra": chupacabra,
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names or SCENES:
        c = Canvas()
        SCENES[name](c)
        img = c.img.resize((PX_W, PX_H), Image.LANCZOS).convert("RGB")
        img.save(os.path.join(OUT, f"{name}.png"), optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
