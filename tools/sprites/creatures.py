"""Pixel-art sprites of the catches that aren't fish: blue crab, stingray, Burmese python,
baby gator, sewer rat and the glow-in-the-dark shrimp. Same style as fish_sprites.py:
shading ramps, painted pixel by pixel, a selective outline. Written to godot/art/fish/.
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import hexc, shade, small_ramp, body_ramp, poly_mask, edge_of, outline, crop, fbm, noise2, dither, save, ramp_from

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'art', 'fish')
WHITE = np.array([255, 255, 240, 255], np.uint8)
BLACK = np.array([16, 18, 16, 255], np.uint8)


class Pic:
    def __init__(self, W, H):
        self.W, self.H = W, H
        self.img = np.zeros((H, W, 4), np.uint8)

    def fill(self, mask, fn):
        for y, x in zip(*np.where(mask)):
            self.img[y, x] = fn(x, y)

    def ellipse(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:self.H, 0:self.W]
        return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0

    def px(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.W and 0 <= y < self.H: self.img[y, x] = c

    def line(self, pts, c, w=1):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
            for i in range(n + 1):
                t = i / n
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                for dx in range(w):
                    for dy in range(w):
                        self.px(x + dx - w // 2, y + dy - w // 2, c)

    def done(self, dark=0.5):
        return crop(outline(self.img, dark), 0)


def shaded(ramp, cx, cy, rx, ry, light=(-0.45, -0.55)):
    """A shade function for a rounded shape lit from the upper left."""
    def f(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        d = dx * light[0] + dy * light[1]
        i = 2 + d * 1.6 - max(0, dx * dx + dy * dy - 0.6) * 1.5
        return ramp[max(0, min(len(ramp) - 1, dither(i, x, y)))]
    return f


# ------------------------------------------------------------------ blue crab (from above)
def crab():
    P = Pic(76, 52)
    shell = small_ramp("#3f6f8f")
    claw = small_ramp("#3a7ac8")
    leg = small_ramp("#4f86a8")
    tip = small_ramp("#d8503a")
    cx, cy = 38, 30
    # legs behind the shell: three walking legs a side, and the paddle legs at the back
    for side in (-1, 1):
        for j in range(3):
            a = 0.15 + j * 0.35
            x0, y0 = cx + side * 10, cy + 2 + j * 3
            x1, y1 = x0 + side * 12 * math.cos(a), y0 + 9 * math.sin(a) + 2
            x2, y2 = x1 + side * 6, y1 + 6
            P.line([(x0, y0), (x1, y1), (x2, y2)], leg[2], 2)
            P.px(x2, y2, leg[0]); P.px(x2 + side, y2 + 1, leg[0])
        # swimming paddle
        x0, y0 = cx + side * 8, cy + 7
        P.line([(x0, y0), (x0 + side * 6, y0 + 8)], leg[1], 2)
        P.fill(P.ellipse(x0 + side * 8, y0 + 11, 3, 2), lambda x, y: leg[3])
    # claws: arms reaching forward and out, then big pincers with red tips
    for side in (-1, 1):
        x0, y0 = cx + side * 11, cy - 6
        x1, y1 = cx + side * 20, cy - 12
        x2, y2 = cx + side * 16, cy - 19
        P.line([(x0, y0), (x1, y1)], claw[1], 3)
        P.line([(x1, y1), (x2, y2)], claw[2], 3)
        # the palm of the claw, then two fingers
        m = P.ellipse(x2 - side * 1, y2 - 3, 5.5, 3.6)
        P.fill(m, shaded(claw, x2, y2 - 3, 5.5, 3.6))
        fx = x2 - side * 5
        P.line([(fx, y2 - 5), (fx - side * 5, y2 - 6), (fx - side * 8, y2 - 4)], tip[2], 2)
        P.line([(fx, y2 - 1), (fx - side * 5, y2 - 1), (fx - side * 7, y2 - 2)], tip[1], 2)
        P.px(fx - side * 8, y2 - 4, tip[4])
    # the shell: wide, with a long point at each side
    pts = [(cx - 25, cy - 3), (cx - 14, cy - 8), (cx - 6, cy - 10), (cx, cy - 10), (cx + 6, cy - 10), (cx + 14, cy - 8), (cx + 25, cy - 3),
           (cx + 13, cy + 1), (cx + 11, cy + 7), (cx + 5, cy + 10), (cx - 5, cy + 10), (cx - 11, cy + 7), (cx - 13, cy + 1)]
    m = poly_mask(P.W, P.H, pts)
    def sh(x, y):
        dx, dy = (x + 0.5 - cx) / 16, (y + 0.5 - cy) / 10
        i = 2.4 - dy * 1.1 - abs(dx) * 0.6
        if abs(x + 0.5 - cx) < 0.6 and y < cy + 4: i += 0.6
        n = fbm(x, y, 3, 2.5)
        if n > 0.7: i += 0.8
        if n < 0.3: i -= 0.6
        return shell[max(0, min(4, dither(i, x, y)))]
    P.fill(m, sh)
    # little teeth along the front edge, and eyes on stalks
    for i in range(-4, 5):
        P.px(cx + i * 2.5, cy - 10 - (i % 2), shell[1])
    for side in (-1, 1):
        P.px(cx + side * 3, cy - 12, BLACK); P.px(cx + side * 3, cy - 11, shell[1])
        P.px(cx + side * 3, cy - 13, WHITE)
    return P.done()


# ------------------------------------------------------------------ stingray (from above)
def ray():
    P = Pic(90, 64)
    r = small_ramp("#8a7a62")
    cx, cy = 34, 30
    # the tail first, long and thin, with the barb
    tail = [(cx - 12, cy)]
    for i in range(1, 16):
        tail.append((cx - 12 - i * 3, cy + math.sin(i * 0.4) * 3))
    P.line(tail, r[1], 2)
    P.line(tail[8:], r[0], 1)
    bx, by = tail[6]
    P.line([(bx, by), (bx - 5, by - 3)], np.array([230, 222, 200, 255], np.uint8), 1)
    # the disc: wide wings out to a point on each side, a rounded nose to the right
    half = [(17, 0), (16, -6), (12, -13), (5, -20), (-1, -26), (-4, -25), (-8, -17), (-12, -8), (-14, -3), (-15, 0)]
    pts = [(cx + x, cy + y) for x, y in half] + [(cx + x, cy - y) for x, y in reversed(half[1:-1])]
    m = poly_mask(P.W, P.H, pts)
    def sh(x, y):
        dx, dy = (x + 0.5 - cx) / 16, (y + 0.5 - cy) / 10
        i = 2.4 - dy * 1.1 - abs(dx) * 0.6
        if abs(x + 0.5 - cx) < 0.6 and y < cy + 4: i += 0.6
        n = fbm(x, y, 3, 2.5)
        if n > 0.7: i += 0.8
        if n < 0.3: i -= 0.6
        return shell[max(0, min(4, dither(i, x, y)))]
    P.fill(m, sh)
    # little teeth along the front edge, and eyes on stalks
    for i in range(-4, 5):
        P.px(cx + i * 2.5, cy - 10 - (i % 2), shell[1])
    for side in (-1, 1):
        P.px(cx + side * 3, cy - 12, BLACK); P.px(cx + side * 3, cy - 11, shell[1])
        P.px(cx + side * 3, cy - 13, WHITE)
    return P.done()


# ------------------------------------------------------------------ stingray (from above)
def ray():
    P = Pic(90, 64)
    r = small_ramp("#8a7a62")
    cx, cy = 34, 30
    # the tail first, long and thin, with the barb
    tail = [(cx - 12, cy)]
    for i in range(1, 16):
        tail.append((cx - 12 - i * 3, cy + math.sin(i * 0.4) * 3))
    P.line(tail, r[1], 2)
    P.line(tail[8:], r[0], 1)
    bx, by = tail[6]
    P.line([(bx, by), (bx - 5, by - 3)], np.array([230, 222, 200, 255], np.uint8), 1)
    # the disc: wide wings out to a point on each side, a rounded nose to the right
    pts = []
    for i in range(64):
        a = i / 64 * math.tau
        ca, sa = math.cos(a), math.sin(a)
        rx = 17 if ca > 0 else 13
        ry = 27
        # pull the wing tips out and the back edge in
        w = abs(sa) ** 3
        x = ca * rx * (1 - 0.55 * w) + (-4 * w)
        y = sa * ry * (0.62 + 0.38 * abs(sa) ** 0.6)
        pts.append((cx + x, cy + y))
    m = poly_mask(P.W, P.H, pts)
    def sh(x, y):
        dx, dy = (x + 0.5 - cx) / 16, (y + 0.5 - cy) / 27
        i = 2.5 - (dx * dx + dy * dy * 1.4) * 1.2 + dx * 0.5 - dy * 0.4
        if abs(dy) < 0.24 and -0.8 < dx < 0.7: i += 0.6    # the raised body down the middle
        n = fbm(x, y, 9, 3.0)
        if n < 0.3: i -= 0.8
        if noise2(x * 2, y * 2, 4, 2.0) > 0.86: i -= 1.5   # freckles
        return r[max(0, min(4, dither(i, x, y)))]
    P.fill(m, sh)
    # eyes and spiracles near the front
    for side in (-1, 1):
        P.px(cx + 11, cy + side * 4, BLACK); P.px(cx + 12, cy + side * 4, r[0])
        P.px(cx + 11, cy + side * 4 - side, WHITE)
        P.px(cx + 8, cy + side * 5, r[0])
    return P.done()


# ------------------------------------------------------------------ Burmese python
def python():
    P = Pic(170, 48)
    base = body_ramp("#5a4a2a", "#a88a4a", "#e8d8a8")
    blot = small_ramp("#4a3220")
    # the body: an S-curve from the tail on the left to the head on the right
    N = 160
    path = []
    for i in range(N + 1):
        f = i / N
        x = 6 + f * 150
        y = 24 + math.sin(f * math.tau * 1.5 + 0.3) * 9 * (0.5 + 0.5 * f)
        path.append((x, y))
    def thick(f): return 1.2 + 5.8 * min(1, f * 3) ** 0.8 * (1 - 0.25 * max(0, f - 0.85) / 0.15)
    for i, (x, y) in enumerate(path):
        f = i / N
        t = thick(f)
        # normal to the path
        x2, y2 = path[min(i + 1, N)]; x1, y1 = path[max(i - 1, 0)]
        nx, ny = -(y2 - y1), (x2 - x1)
        L = math.hypot(nx, ny) or 1
        nx, ny = nx / L, ny / L
        for k in np.linspace(-t, t, int(t * 4) + 2):
            px, py = x + nx * k, y + ny * k
            v = (k + t) / (2 * t)   # 0 one side .. 1 the other
            xi, yi = int(px), int(py)
            if not (0 <= xi < P.W and 0 <= yi < P.H): continue
            i_ = 2 + (0.5 - abs(v - 0.35)) * 6
            # the python's big dark saddles with pale edges
            sp = (f * 26) % 1.0
            blotch = abs(sp - 0.5) < 0.22 and 0.12 < v < 0.8 and f < 0.96
            c = base[max(0, min(10, dither(i_ + 2, xi, yi)))]
            if blotch:
                c = blot[max(0, min(4, dither(i_ / 3, xi, yi)))]
                if abs(abs(sp - 0.5) - 0.2) < 0.03: c = base[9]
            P.img[yi, xi] = c
    # head: wedge-shaped, with the dark arrow mark on top
    hx, hy = path[-1]
    m = P.ellipse(hx + 4, hy, 8, 5)
    P.fill(m & (P.img[:, :, 3] == 0) | m, shaded(base[2:9], hx + 4, hy, 8, 5))
    for i in range(6):
        P.px(hx + 1 + i, hy - 1 + abs(i - 3) * 0.3, blot[1])
    P.px(hx + 7, hy - 2, BLACK); P.px(hx + 7, hy - 3, WHITE)
    P.line([(hx + 8, hy + 2), (hx + 12, hy + 1)], blot[0])
    # tongue
    P.line([(hx + 12, hy + 1), (hx + 15, hy + 1), (hx + 17, hy), ], np.array([200, 40, 40, 255], np.uint8))
    P.px(hx + 17, hy + 2, np.array([200, 40, 40, 255], np.uint8))
    return P.done()


# ------------------------------------------------------------------ baby gator (side view)
def gator():
    P = Pic(150, 46)
    base = body_ramp("#2a3a1e", "#4a6030", "#d8d0a0")
    cy = 26
    def top(x):
        # snout at the right, tail tapering to the left
        if x > 118: return cy - 4 + (x - 118) * 0.12
        if x > 100: return cy - 7 + (118 - x) * -0.15 + (x - 100) * 0.1
        if x > 60: return cy - 10
        return cy - 10 + (60 - x) * 0.13
    def bot(x):
        if x > 118: return cy + 2 - (x - 118) * 0.05
        if x > 60: return cy + 6
        return cy + 6 - (60 - x) * 0.1
    body = np.zeros((P.H, P.W), bool)
    for x in range(6, 143):
        t, b = top(x), bot(x)
        for y in range(int(t), int(b) + 1):
            if t <= y + 0.5 <= b: body[y, x] = True
    # legs: two pairs, bent at the elbow, with toes (the far ones darker, drawn first)
    for lx, far in ((97, True), (61, True), (103, False), (67, False)):
        r = base if not far else [np.round(shade(c.astype(float), -0.3)).astype(np.uint8) for c in base]
        P.line([(lx, cy - 2), (lx - 1, cy + 6), (lx - 4, cy + 9), (lx - 1, cy + 12)], r[5], 3)
        P.line([(lx + 1, cy + 6), (lx - 2, cy + 9)], r[3], 1)
        for t_ in range(4): P.px(lx - 1 + t_, cy + 13, r[4])
        P.px(lx + 3, cy + 13, r[2])
    def sh(x, y):
        t, b = top(x), bot(x)
        v = (y + 0.5 - t) / max(1, b - t)
        i = 1.5 + v * 7.5 + 1.0 * math.exp(-((v - 0.2) / 0.1) ** 2)
        if v < 0.25 and (x % 6 < 2): i += 1.6 if (x // 6) % 2 else -1.0   # the ridge of scutes
        if 0.25 < v < 0.75 and (x // 3 + y // 3) % 2 == 0: i -= 0.6     # square scales
        if x < 60 and v < 0.6 and (x // 8) % 2 == 0: i -= 1.2           # tail bands, yellow on a baby
        if x < 100 and 0.3 < v < 0.6 and (x // 7) % 2 == 1 and x > 30: i += 2.2
        return base[max(0, min(10, dither(i, x, y)))]
    P.fill(body, sh)
    # the tail's double crest
    for x in range(8, 60, 3):
        P.px(x, top(x) - 1, base[2]); P.px(x + 1, top(x) - 1, base[3])
    # eye bump, nostril, the toothy smile
    P.fill(P.ellipse(116, cy - 7, 3.5, 2.5), lambda x, y: base[3])
    P.px(116, cy - 8, np.array([230, 190, 60, 255], np.uint8)); P.px(117, cy - 8, BLACK); P.px(115, cy - 9, WHITE)
    P.px(140, cy - 3, BLACK)
    P.line([(141, cy + 1), (126, cy + 1), (114, cy - 1)], base[0])
    for x in range(118, 140, 3): P.px(x, cy + 2, WHITE)
    return P.done()


# ------------------------------------------------------------------ sewer rat (side view)
def rat():
    P = Pic(90, 40)
    fur = small_ramp("#6a625a")
    pink = small_ramp("#d89a98")
    cx, cy = 44, 22
    # tail, long and pink, curling behind
    tail = [(cx - 14, cy + 6)]
    for i in range(1, 12): tail.append((cx - 14 - i * 2.6, cy + 6 + math.sin(i * 0.5) * 4 - i * 0.2))
    P.line(tail, pink[2], 2)
    P.line(tail[6:], pink[1], 1)
    # feet
    for fx in (cx - 8, cx + 10):
        P.line([(fx, cy + 8), (fx + 1, cy + 11), (fx + 3, cy + 11)], pink[2], 1)
    body = P.ellipse(cx, cy, 17, 9)
    head = P.ellipse(cx + 18, cy - 1, 10, 6.5)
    snout = poly_mask(P.W, P.H, [(cx + 22, cy - 6), (cx + 34, cy + 1), (cx + 22, cy + 5)])
    m = body | head | snout
    def sh(x, y):
        dy = (y + 0.5 - (cy - 8)) / 18
        i = 3.2 - dy * 3.0
        if (x * 7 + y * 3) % 5 == 0: i -= 0.7          # fur texture
        if (x * 3 + y * 5) % 7 == 0: i += 0.6
        return fur[max(0, min(4, dither(i, x, y)))]
    P.fill(m, sh)
    # ear, eye, nose, whiskers
    P.fill(P.ellipse(cx + 15, cy - 8, 3.2, 3.6), lambda x, y: pink[2] if (x + y) % 3 else pink[1])
    P.px(cx + 24, cy - 3, BLACK); P.px(cx + 24, cy - 4, WHITE)
    P.px(cx + 34, cy + 1, pink[1]); P.px(cx + 33, cy + 1, pink[1])
    for w in ((cx + 30, cy, cx + 38, cy - 3), (cx + 30, cy + 1, cx + 38, cy + 3)):
        P.line([(w[0], w[1]), (w[2], w[3])], fur[4])
    return P.done()


# ------------------------------------------------------------------ glow-in-the-dark shrimp
def shrimp():
    P = Pic(72, 44)
    g = small_ramp("#78e868")
    # a side view: head and shell on the right, the tail curling down and under on the left
    spine = []
    for i in range(13):
        f = i / 12
        a = math.pi * 0.05 + f * math.pi * 0.95
        x = 34 + math.cos(a) * 18
        y = 20 - math.sin(a) * 8 + f * f * 10
        spine.append((x, y, 6.5 - f * 3.6))
    for i in range(len(spine) - 1, -1, -1):
        x, y, s_ = spine[i]
        m = P.ellipse(x, y, s_ * 0.85, s_)
        P.fill(m, shaded(g, x, y, s_, s_))
        if i % 2 == 0 and i > 1:
            e = edge_of(m)
            P.fill(e & (np.mgrid[0:P.H, 0:P.W][1] < x), lambda xx, yy: g[1])
    # the head shell, pointed rostrum forward
    hx, hy = 52, 17
    head = poly_mask(P.W, P.H, [(hx - 8, hy - 5), (hx + 6, hy - 4), (hx + 15, hy - 3), (hx + 6, hy + 1), (hx + 2, hy + 6), (hx - 8, hy + 6)])
    P.fill(head, shaded(g, hx, hy, 9, 6))
    P.px(hx + 3, hy - 2, BLACK); P.px(hx + 4, hy - 2, BLACK); P.px(hx + 3, hy - 3, WHITE)
    P.line([(hx + 6, hy - 3), (hx + 14, hy - 10), (hx + 19, hy - 12)], g[3])
    P.line([(hx + 7, hy - 2), (hx + 16, hy - 5), (hx + 19, hy - 2)], g[2])
    # legs and swimmerets underneath
    for i in range(6):
        x = hx - 2 - i * 3.5
        P.line([(x, hy + 5 + i * 0.6), (x - 1, hy + 10 + i * 0.4)], g[1])
    # the tail fan at the curled end
    x, y, s_ = spine[-1]
    P.fill(poly_mask(P.W, P.H, [(x + 2, y - 1), (x - 2, y + 8), (x + 5, y + 9), (x + 6, y + 2)]), lambda xx, yy: g[3] if (xx + yy) % 2 else g[2])
    for i in range(1, 11, 2):
        x, y, s_ = spine[i]
        P.px(x, y - s_ * 0.5, np.array([236, 255, 214, 255], np.uint8))
    return P.done(0.45)


ALL = {"blue_crab": crab, "stingray": ray, "burmese_python": python, "baby_gator": gator, "sewer_rat": rat, "glow_shrimp": shrimp}


def build(only=None):
    os.makedirs(OUT, exist_ok=True)
    done = {}
    for k, fn in ALL.items():
        if only and k not in only: continue
        img = fn()
        save(img, os.path.join(OUT, k + ".png"))
        done[k] = img
    return done


if __name__ == "__main__":
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="): only = set(a[7:].split(","))
    d = build(only)
    sys.path.insert(0, os.path.dirname(__file__))
    for a in sys.argv[1:]:
        if a.startswith("--sheet="):
            from fish_sprites import sheet
            sheet(d, a[8:], 2)
    print(len(d), "creatures")
