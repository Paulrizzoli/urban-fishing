"""Shared pixel-art helpers for Urban Fishing's sprites: colors, ramps, masks and the outline pass.

Every sprite is painted at its final size, one pixel at a time, with a small palette per part
(a shading ramp from shadow to highlight). Edges get a "selective" outline: each outline pixel is
a darker shade of the color it borders, so a pale belly gets a soft line and a dark back a hard one.
"""
import colorsys, math
import numpy as np
from PIL import Image, ImageDraw


def hexc(s, a=255):
    s = s.lstrip('#')
    return np.array([int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a], np.float64)


def shade(c, amt, hue=0.0, sat=0.0):
    """Lighten (amt > 0) or darken (amt < 0) a color, with a small hue shift (shadows go cooler,
    lights warmer, as pixel artists do)."""
    r, g, b = (c[:3] / 255.0).tolist()
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if amt < 0:
        l = l * (1 + amt)
        h = (h + hue * -amt) % 1.0
        s = min(1.0, s * (1 + 0.25 * -amt) + sat)
    else:
        l = l + (1 - l) * amt
        h = (h - hue * amt) % 1.0
        s = max(0.0, s * (1 - 0.35 * amt) + sat)
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return np.array([r * 255, g * 255, b * 255, c[3] if len(c) > 3 else 255])


def mix(a, b, t):
    return a * (1 - t) + b * t


def ramp_from(anchors, n=11):
    """anchors: list of (index, color). Returns n colors, interpolated between the anchors."""
    out = []
    for i in range(n):
        for (i0, c0), (i1, c1) in zip(anchors, anchors[1:]):
            if i0 <= i <= i1:
                t = (i - i0) / (i1 - i0) if i1 != i0 else 0
                out.append(mix(c0, c1, t))
                break
        else:
            out.append(anchors[0][1] if i < anchors[0][0] else anchors[-1][1])
    return [np.round(c).astype(np.uint8) for c in out]


def body_ramp(back, side, belly):
    """11 shades from the shadowed back down to the lit belly."""
    back, side, belly = hexc(back), hexc(side), hexc(belly)
    return ramp_from([(0, shade(back, -0.55, 0.04)), (2, shade(back, -0.25, 0.02)), (4, back),
                      (6.3, side), (8.8, belly), (10, shade(belly, 0.4, -0.02))])


def small_ramp(c, n=5):
    """5 shades of one color: deep shadow, shadow, base, light, highlight."""
    c = hexc(c) if isinstance(c, str) else c
    return ramp_from([(0, shade(c, -0.55, 0.04)), (1, shade(c, -0.28, 0.02)), (2, c), (3, shade(c, 0.22)), (4, shade(c, 0.45))], n)


def poly_mask(W, H, pts):
    im = Image.new('L', (W, H), 0)
    if len(pts) >= 3:
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.array(im) > 0


def line_mask(W, H, lines, width=1):
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    for (x0, y0, x1, y1) in lines:
        d.line([(x0, y0), (x1, y1)], fill=255, width=width)
    return np.array(im) > 0


def edge_of(mask):
    """Pixels of mask that touch a pixel outside it (4-neighbours)."""
    m = mask
    inner = m.copy()
    inner[1:, :] &= m[:-1, :]; inner[:-1, :] &= m[1:, :]
    inner[:, 1:] &= m[:, :-1]; inner[:, :-1] &= m[:, 1:]
    return m & ~inner


def outline(img, dark=0.5, corners=False):
    """Selective outline around everything opaque: each new pixel is a darkened copy of the
    neighbour it borders (the darkest one if several)."""
    H, W = img.shape[:2]
    a = img[:, :, 3] > 0
    out = img.copy()
    nbs = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, -1), (1, -1), (-1, 1)] if corners else [])
    for y in range(H):
        for x in range(W):
            if a[y, x]:
                continue
            best = None
            for dx, dy in nbs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and a[ny, nx]:
                    c = img[ny, nx].astype(np.float64)
                    lum = c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11
                    if best is None or lum < best[0]:
                        best = (lum, c)
            if best is not None:
                c = shade(best[1], -dark, 0.03)
                c[3] = 255
                out[y, x] = np.round(c).astype(np.uint8)
    return out


def crop(img, margin=1):
    a = img[:, :, 3] > 0
    ys, xs = np.where(a)
    y0, y1 = max(0, ys.min() - margin), min(img.shape[0], ys.max() + 1 + margin)
    x0, x1 = max(0, xs.min() - margin), min(img.shape[1], xs.max() + 1 + margin)
    return img[y0:y1, x0:x1]


def noise2(x, y, seed=0, scale=6.0):
    """Smooth value noise in 0..1, for blotches and mottling."""
    def h(ix, iy):
        n = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xffffffff
        n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
        return ((n ^ (n >> 16)) & 0xffff) / 65535.0
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = h(ix, iy) * (1 - tx) + h(ix + 1, iy) * tx
    b = h(ix, iy + 1) * (1 - tx) + h(ix + 1, iy + 1) * tx
    return a * (1 - ty) + b * ty


def fbm(x, y, seed=0, scale=6.0):
    return noise2(x, y, seed, scale) * 0.65 + noise2(x, y, seed + 7, scale / 2.2) * 0.35


BAYER = np.array([[0, 2], [3, 1]]) / 4.0


def dither(i, x, y):
    """Round a shade index with a 2x2 ordered dither, so bands blend into each other."""
    f = i - math.floor(i)
    return int(math.floor(i) + (1 if f > 0.25 + BAYER[y % 2, x % 2] * 0.5 else 0))


def save(img, path):
    Image.fromarray(img, 'RGBA').save(path)
