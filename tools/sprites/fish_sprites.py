"""Paints a pixel-art sprite of every fish in Urban Fishing into godot/art/fish/.

usage: python3 tools/sprites/fish_sprites.py [--only=bass,koi] [--sheet=contact.png]

Each kind of fish starts from its numbers in godot/scripts/fish_art.gd (KINDS: depth, colors,
tail, dorsal fin, markings), and SHAPE below adds what a sprite needs on top: the outline of the
body, where the fins sit, eye color, special features. The painter then works pixel by pixel:
fins behind the body, the body shaded from a dark back to a pale belly with scales and markings,
then the head (gill cover, mouth, eye), the side fins, and a selective outline.
Named fish that look different from their kind (gold legends, glowing mutants) are VARIANTS.
The odd non-fish catches (crab, ray, python, gator, rat, shrimp) are painted in creatures.py.
"""
import json, math, os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel import (hexc, shade, mix, body_ramp, small_ramp, poly_mask, line_mask, edge_of, outline,
                   crop, fbm, noise2, dither, save, ramp_from)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'art', 'fish')

# ---------------------------------------------------------------- the fish, from fish_art.gd
def load_kinds():
    src = open(os.path.join(ROOT, 'godot', 'scripts', 'fish_art.gd')).read()
    return {m.group(1): json.loads(m.group(2)) for m in re.finditer(r'^\t"(\w+)": (\{.*\}),\s*$', src, re.M)}

# Shape and detail on top of KINDS. Keys:
#  pk      where the body is deepest, 0 nose .. 1 tail     he/te  head and tail curve exponents
#  s0      snout depth (share of the body's depth)         ped    peduncle depth (share)
#  tshare  share of the depth above the midline            mo     nose height (+ = lower)
#  tl/ts   tail length (share of body) and spread           eye    iris color, er eye size
#  scale   scale size in px (0 = smooth skin)               ss     scale strength
#  pelvic  "thoracic" (under the gill) or "abdominal"       adipose  small fin before the tail
#  anal    anal fin kind: mid, long, eel, fringe, full, small, shark
SHAPE = {
    "bluegill": dict(pk=0.42, he=0.7, s0=0.3, ped=0.24, tl=0.26, eye="#3a2a1a", scale=3, ss=1.0),
    "tilapia": dict(pk=0.4, he=0.75, s0=0.3, ped=0.3, tl=0.26, scale=3, ss=1.1, anal="long"),
    "bass": dict(pk=0.4, he=0.85, s0=0.26, ped=0.3, tl=0.28, scale=3, ss=0.9, mo=0.08),
    "peacock": dict(pk=0.4, he=0.85, s0=0.24, ped=0.3, tl=0.28, scale=2, ss=0.7, eye="#c83a1a"),
    "catfish": dict(pk=0.3, he=0.55, s0=0.42, ped=0.32, tl=0.3, tshare=0.5, scale=0, adipose=True, anal="long", eye="#1a1a14", er=0.8, mo=0.15),
    "walking": dict(pk=0.3, he=0.55, s0=0.45, ped=0.4, tl=0.18, tshare=0.5, scale=0, anal="eel", eye="#1a1a14", er=0.8, mo=0.1),
    "mullet": dict(pk=0.42, he=0.8, s0=0.32, ped=0.3, tl=0.28, scale=3, ss=1.1, pelvic="abdominal", eye="#e8e0b0", er=1.1, anal="small"),
    "snook": dict(pk=0.4, he=1.25, s0=0.16, ped=0.3, tl=0.28, scale=2, ss=0.6, mo=-0.05, eye="#e0c850"),
    "tarpon": dict(pk=0.42, he=0.95, s0=0.22, ped=0.22, tl=0.32, ts=1.25, scale=5, ss=1.4, pelvic="abdominal", eye="#e8e8e0", er=1.2, filament=True, anal="small"),
    "bowfin": dict(pk=0.35, he=0.7, s0=0.35, ped=0.42, tl=0.22, scale=0, pelvic="abdominal", anal="small", eye="#c8a030"),
    "goldfish": dict(pk=0.4, he=0.6, s0=0.4, ped=0.25, tl=0.42, ts=1.4, scale=3, ss=1.4, pelvic="abdominal", eye="#1a1a1a", er=1.2, anal="small"),
    "koi": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.3, scale=4, ss=0.7, pelvic="abdominal", eye="#1a1a1a", anal="small"),
    "butterfly": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.5, ts=1.5, scale=4, ss=0.6, pelvic="abdominal", eye="#1a1a1a", anal="small"),
    "ogon": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.3, scale=4, ss=1.3, pelvic="abdominal", eye="#1a1a1a", anal="small"),
    "eel": dict(pk=0.2, he=0.6, s0=0.55, ped=0.0, scale=0, anal="eel", eye="#c8b050", er=0.8, mo=0.1),
    "jack": dict(pk=0.32, he=0.55, s0=0.3, ped=0.12, tl=0.32, ts=1.2, scale=2, ss=0.4, eye="#e0c040", er=1.2, scutes=True),
    "redfish": dict(pk=0.38, he=0.85, s0=0.3, ped=0.32, tl=0.26, scale=3, ss=1.4, mo=0.15, eye="#c89a40"),
    "gar": dict(pk=0.55, he=1.0, s0=0.5, ped=0.36, tl=0.15, ts=0.75, scale=3, ss=1.0, pelvic="abdominal", anal="back", beak=0.26, eye="#c8a030", er=0.9),
    "oscar": dict(pk=0.38, he=0.7, s0=0.32, ped=0.32, tl=0.24, scale=3, ss=0.6, anal="long", eye="#d84a1a"),
    "pacu": dict(pk=0.4, he=0.55, s0=0.32, ped=0.2, tl=0.26, scale=2, ss=0.5, adipose=True, pelvic="abdominal", eye="#1a1a1a"),
    "carp": dict(pk=0.4, he=0.8, s0=0.28, ped=0.3, tl=0.3, scale=4, ss=1.4, pelvic="abdominal", eye="#c89030", anal="small", longdorsal=True),
    "snakehead": dict(pk=0.25, he=0.65, s0=0.42, ped=0.4, tl=0.2, scale=2, ss=0.6, anal="eel_short", pelvic="thoracic", eye="#c89a30", er=0.9),
    "snapper": dict(pk=0.4, he=1.0, s0=0.24, ped=0.28, tl=0.28, scale=3, ss=1.1, eye="#c83a2a"),
    "ladyfish": dict(pk=0.45, he=1.1, s0=0.2, ped=0.2, tl=0.34, scale=1, ss=0.4, pelvic="abdominal", eye="#e8e8e0", er=1.2, anal="small"),
    "cichlid": dict(pk=0.38, he=0.8, s0=0.28, ped=0.3, tl=0.24, scale=3, ss=0.9, anal="long", eye="#c83a1a"),
    "pinfish": dict(pk=0.4, he=0.7, s0=0.26, ped=0.24, tl=0.28, scale=2, ss=0.6, eye="#e0c040"),
    "seatrout": dict(pk=0.42, he=1.1, s0=0.2, ped=0.28, tl=0.26, scale=2, ss=0.5, eye="#e0c040"),
    "sheepshead": dict(pk=0.38, he=0.6, s0=0.3, ped=0.24, tl=0.28, scale=2, ss=0.5, eye="#e0c040", sheepteeth=True),
    "barracuda": dict(pk=0.5, he=1.5, s0=0.14, ped=0.32, tl=0.24, scale=1, ss=0.3, mo=-0.15, eye="#e0c040", er=0.9, anal="back"),
    "shark": dict(pk=0.42, he=1.4, s0=0.16, ped=0.26, tl=0.36, ts=1.2, scale=0, mo=-0.5, pelvic="shark", anal="shark", eye="#1a1a1a", er=0.7),
    "bonnet": dict(pk=0.42, he=1.2, s0=0.2, ped=0.26, tl=0.36, ts=1.2, scale=0, mo=-0.3, pelvic="shark", anal="shark", eye="#1a1a1a", er=0.7),
    "mahi": dict(pk=0.2, he=0.45, s0=0.55, ped=0.14, tl=0.3, ts=1.2, scale=0, mo=0.35, anal="full", eye="#1a1a1a"),
    "kingfish": dict(pk=0.45, he=1.3, s0=0.14, ped=0.12, tl=0.3, ts=1.3, scale=0, eye="#e0e0d8"),
    "tuna": dict(pk=0.4, he=1.1, s0=0.18, ped=0.08, tl=0.3, ts=1.3, scale=0, eye="#1a1a1a", er=1.1),
    "sailfish": dict(pk=0.38, he=1.2, s0=0.14, ped=0.12, tl=0.3, ts=1.4, scale=0, eye="#1a1a1a"),
    "grouper": dict(pk=0.4, he=0.8, s0=0.3, ped=0.36, tl=0.24, scale=2, ss=0.6, mo=0.0, eye="#c8a040", er=0.8),
    "arowana": dict(pk=0.55, he=0.9, s0=0.32, ped=0.4, tl=0.2, scale=5, ss=1.4, pelvic="abdominal", anal="back", eye="#e0c040", er=1.1, mo=-0.4),
    "perch": dict(pk=0.4, he=1.0, s0=0.22, ped=0.26, tl=0.28, scale=2, ss=0.6, eye="#c8b040"),
    "crappie": dict(pk=0.45, he=0.85, s0=0.25, ped=0.22, tl=0.28, scale=2, ss=0.5, anal="long", eye="#3a3020", er=1.2),
    "smallmouth": dict(pk=0.4, he=0.9, s0=0.26, ped=0.3, tl=0.28, scale=3, ss=0.9, eye="#c82a1a"),
    "walleye": dict(pk=0.45, he=1.2, s0=0.18, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#d8d8b8", er=1.15, walleye=True),
    "sauger": dict(pk=0.45, he=1.2, s0=0.18, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#e0d8b0", er=1.2),
    "muskie": dict(pk=0.55, he=1.4, s0=0.18, ped=0.36, tl=0.24, scale=1, ss=0.3, pelvic="abdominal", anal="back", eye="#c8a040", mo=-0.1),
    "whitebass": dict(pk=0.38, he=0.9, s0=0.24, ped=0.24, tl=0.3, scale=2, ss=0.7, eye="#e0c040"),
    "striper": dict(pk=0.42, he=1.0, s0=0.22, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#c8c0a0"),
    "skipjack": dict(pk=0.42, he=1.0, s0=0.24, ped=0.2, tl=0.32, scale=2, ss=0.8, pelvic="abdominal", eye="#e8e8e0", er=1.2, mo=-0.2, anal="small"),
    "drum": dict(pk=0.38, he=0.6, s0=0.3, ped=0.28, tl=0.26, scale=3, ss=1.0, mo=0.35, eye="#c8c8c0"),
    "flathead": dict(pk=0.3, he=0.5, s0=0.42, ped=0.34, tl=0.26, tshare=0.46, scale=0, adipose=True, anal="mid", eye="#c8a040", er=0.7, mo=0.1),
    "mirror": dict(pk=0.4, he=0.75, s0=0.28, ped=0.3, tl=0.3, scale=0, pelvic="abdominal", eye="#c89030", anal="small", mirror=True),
    "paddle": dict(pk=0.38, he=1.0, s0=0.3, ped=0.2, tl=0.3, ts=1.1, scale=0, pelvic="abdominal", anal="small", eye="#1a1a1a", er=0.6, paddle=True),
    "sturgeon": dict(pk=0.38, he=1.2, s0=0.16, ped=0.18, tl=0.3, ts=1.1, scale=0, pelvic="abdominal", anal="small", mo=-0.3, eye="#1a1a1a", er=0.7, scutes5=True),
    "rainbow": dict(pk=0.42, he=1.0, s0=0.22, ped=0.32, tl=0.26, scale=1, ss=0.4, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040"),
    "brown": dict(pk=0.42, he=1.0, s0=0.24, ped=0.34, tl=0.26, scale=1, ss=0.4, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040"),
    "brook": dict(pk=0.42, he=0.95, s0=0.24, ped=0.34, tl=0.26, scale=0, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040", whiteedge=True),
    "chub": dict(pk=0.4, he=0.9, s0=0.28, ped=0.3, tl=0.28, scale=3, ss=1.0, pelvic="abdominal", anal="small", eye="#c8b040"),
    "pumpkinseed": dict(pk=0.42, he=0.7, s0=0.28, ped=0.24, tl=0.26, scale=2, ss=0.7, eye="#c83a1a"),
    "bluefish": dict(pk=0.42, he=1.0, s0=0.22, ped=0.22, tl=0.3, scale=1, ss=0.4, mo=-0.05, eye="#e0c040", er=1.1),
    "seabass": dict(pk=0.4, he=0.85, s0=0.26, ped=0.3, tl=0.26, scale=3, ss=1.0, eye="#3a3a3a"),
    "scup": dict(pk=0.38, he=0.55, s0=0.3, ped=0.22, tl=0.3, scale=2, ss=0.7, eye="#e0c040"),
    "tautog": dict(pk=0.38, he=0.6, s0=0.36, ped=0.36, tl=0.22, scale=2, ss=0.5, eye="#c8c0a0", lips=True),
    "flounder": dict(pk=0.4, he=0.6, s0=0.3, ped=0.3, tl=0.18, scale=0, dorsalk="fringe", anal="fringe", eye="#e0c060", er=0.8, flounder=True, pelvic="none"),
    "mackerel": dict(pk=0.45, he=1.2, s0=0.16, ped=0.1, tl=0.3, ts=1.2, scale=0, eye="#1a1a1a"),
    "cunner": dict(pk=0.4, he=0.75, s0=0.3, ped=0.32, tl=0.22, scale=2, ss=0.8, eye="#c8a040"),
    "dogfish": dict(pk=0.4, he=1.3, s0=0.18, ped=0.22, tl=0.34, ts=1.0, scale=0, mo=-0.5, pelvic="shark", anal="none", eye="#3ac8a0", er=0.9, dogspines=True),
    "searobin": dict(pk=0.25, he=0.55, s0=0.4, ped=0.3, tl=0.22, scale=0, eye="#c8a040", wings=True),
    "cod": dict(pk=0.38, he=0.9, s0=0.3, ped=0.24, tl=0.26, scale=0, eye="#c8a040", anal="two", three_dorsal=True),
    "pollock": dict(pk=0.4, he=1.0, s0=0.24, ped=0.22, tl=0.3, scale=0, eye="#e0e0d0", anal="two", three_dorsal=True, mo=-0.05),
    "haddock": dict(pk=0.38, he=0.95, s0=0.26, ped=0.22, tl=0.28, scale=0, eye="#e0e0d0", anal="two", three_dorsal=True),
    "albacore": dict(pk=0.4, he=1.1, s0=0.18, ped=0.1, tl=0.3, ts=1.3, scale=0, eye="#1a1a1a"),
    "bonito": dict(pk=0.42, he=1.2, s0=0.16, ped=0.1, tl=0.3, ts=1.25, scale=0, eye="#1a1a1a"),
    "bluefin": dict(pk=0.4, he=1.0, s0=0.18, ped=0.08, tl=0.3, ts=1.35, scale=0, eye="#1a1a1a", er=1.0),
    "whiteperch": dict(pk=0.4, he=0.9, s0=0.25, ped=0.24, tl=0.28, scale=2, ss=0.8, eye="#c8c0a0"),
    "conger": dict(pk=0.2, he=0.7, s0=0.5, ped=0.0, scale=0, anal="eel", eye="#c8c8b0", er=0.9),
    "monkfish": dict(pk=0.16, he=0.45, s0=0.75, ped=0.26, tl=0.18, tshare=0.42, scale=0, mo=0.0, eye="#c8a040", er=0.7, lure=True, anal="small", pelvic="none", wings=True),
    "mummichog": dict(pk=0.38, he=0.7, s0=0.34, ped=0.42, tl=0.22, scale=2, ss=0.8, pelvic="abdominal", anal="back", eye="#c8c050", mo=-0.2, dorsalk="back"),
    "shiner": dict(pk=0.42, he=0.9, s0=0.26, ped=0.24, tl=0.3, scale=3, ss=1.1, pelvic="abdominal", anal="small", eye="#c8b040", mo=-0.15),
    "other": dict(pk=0.4, he=0.9, s0=0.25, ped=0.28, tl=0.28, scale=2, ss=0.8),
}

# Named fish that don't look like their kind: (kind, overrides).
GOLD = dict(back="#a8741a", side="#e9b23a", belly="#f8e08a", fin="#d8a02a", shine=True)
VARIANTS = {
    "glowing_bass": ("bass", dict(glow=True)),
    "isotope": ("bass", dict(glow=True, back="#3a5a1a", side="#9ac850")),
    "reactor_goliath": ("grouper", dict(glow=True, back="#4a5a2a", side="#8aa04a")),
    "three_eyed_tilapia": ("tilapia", dict(eyes=3)),
    "another_dimension": ("tilapia", dict(eyes=3, back="#4a2a6a", side="#8a5ab0", belly="#d8b8f0", fin="#7a4aa0", glow=True, glow_col="#c080ff")),
    "two_headed_catfish": ("catfish", dict(two=True)),
    "giant_tilapia": ("tilapia", dict(h=0.44)),
    "snook_xl": ("snook", dict(h=0.25)),
    "mr_chairman": ("koi", dict(GOLD, pat="scales", ss=1.4)),
    "golden_arowana": ("arowana", dict(GOLD)),
    "mayors_pet": ("goldfish", dict(GOLD)),
    "key_to_the_city": ("tarpon", dict(GOLD)),
    "volcano_pacu": ("pacu", dict(back="#4a2a2a", side="#a04a2a", belly="#f08a2a", fin="#6a2a1a", glow=True, glow_col="#ff7020")),
    "escaped_koi": ("koi", dict(pat="koi_calico")),
    "old_glory": ("tarpon", dict(back="#2a3a6a", belly="#f1f4f5", pat="bigscales")),
    "gray_ghost": ("snook", dict(back="#6a7074", side="#b8bcbe")),
}

# ---------------------------------------------------------------- the painter
def smooth01(t): return t * t * (3 - 2 * t)


class Fish:
    def __init__(self, key, k, seed=1):
        self.key, self.k, self.seed = key, k, seed
        g = lambda name, d: k.get(name, d)
        self.h = g("h", 0.3)
        self.eel = k["tail"] == "eel"
        long_ = self.h <= 0.2
        vlong = self.h <= 0.14 or self.eel
        TW = 140 if vlong else (112 if long_ else 92)
        self.tl = 0.0 if self.eel else g("tl", 0.28)
        bill = 0.36 if g("bill", False) and not g("paddle", False) else (0.42 if g("paddle", False) else 0.0)
        beak = g("beak", 0.0)
        self.L = L = TW / (1 + self.tl + bill + beak)
        self.D = self.h * 1.25 * L                     # body depth, px
        self.W, self.H = 260, 200
        self.xn = self.W - 30 - (bill + beak) * L     # nose
        self.xp = self.xn - L                         # peduncle (tail base)
        self.cy = 100.0
        self.img = np.zeros((self.H, self.W, 4), np.uint8)
        self.body = np.zeros((self.H, self.W), bool)
        self.fin = np.zeros((self.H, self.W), bool)
        self.br = body_ramp(k["back"], k["side"], k["belly"])
        self.fr = small_ramp(k["fin"])
        self.rng = np.random.default_rng(seed)

    # body outline: u 0 at the nose, 1 at the peduncle
    def X(self, u): return self.xn - u * self.L
    def U(self, x): return (self.xn - x) / self.L

    def prof(self, u, top):
        k = self.k
        pk = k.get("pk", 0.4) if top else k.get("pk", 0.4) + 0.05
        he, te = k.get("he", 0.9), k.get("te", 1.1)
        s0, ped = k.get("s0", 0.25), k.get("ped", 0.28)
        u = min(max(u, 0.0), 1.0)
        if self.eel:
            # eels: a round head, then an even tube that tapers to a point
            if u < 0.12: return s0 + (1 - s0) * math.sin(u / 0.12 * math.pi / 2) ** 0.7
            return 1.0 - 0.15 * (u - 0.12) - 0.85 * smooth01(max(0, (u - 0.55) / 0.45)) ** 1.3
        if u < pk:
            a = u / pk
            return s0 + (1 - s0) * math.sin(a * math.pi / 2) ** he
        a = (u - pk) / (1 - pk)
        return ped + (1 - ped) * math.cos(a * math.pi / 2) ** te

    def mid(self, u):
        mo = self.k.get("mo", 0.0)
        wave = 0.0
        if self.eel:   # eels swim in an S
            wave = math.sin(u * 5.2 - 0.6) * self.D * 0.32 * smooth01(min(1, u * 3))
        return self.cy + mo * self.D * 0.5 * (1 - min(u, 1)) ** 2.2 + wave

    def top(self, u):
        ts = self.k.get("tshare", 0.54)
        return self.mid(u) - self.D * ts * self.prof(u, True)

    def bot(self, u):
        ts = self.k.get("tshare", 0.54)
        flat = 1.08 if self.k.get("flat", False) else 1.0
        return self.mid(u) + self.D * (1 - ts) * self.prof(u, False) * flat

    def at(self, u, v):   # v -1 = back edge, 0 middle, 1 belly edge
        t, b = self.top(u), self.bot(u)
        return (self.X(u), (t + b) / 2 + v * (b - t) / 2)

    # -------------------------------------------------- fins
    def fin_poly(self, edge, spans, inset=2.0):
        """A fin along the back (edge=-1) or belly (edge=1): spans is a list of (u, height in body
        depths, rake in px) from front to back. Returns polygon points."""
        pts = []
        u0, u1 = spans[0][0], spans[-1][0]
        for u, hgt, rake in spans:
            x, y = self.at(u, edge)
            pts.append((x - rake, y + edge * hgt * self.D))
        n = 10
        for i in range(n + 1):
            u = u1 + (u0 - u1) * i / n
            x, y = self.at(u, edge)
            pts.append((x, y - edge * inset))
        return pts

    def paint_fin(self, pts, rays=None, base=2, edge_light=True, alpha_body=False, ray_shade=1, mem=None):
        m = poly_mask(self.W, self.H, pts)
        if mem is not None: m &= mem
        e = edge_of(m)
        rm = line_mask(self.W, self.H, rays) if rays else np.zeros_like(m)
        ys, xs = np.where(m)
        for y, x in zip(ys, xs):
            s = base
            if rm[y, x]: s = ray_shade
            if e[y, x] and edge_light and not rm[y, x]: s = min(4, base + 1)
            self.img[y, x] = self.fr[s]
        self.fin |= m
        return m

    def soft_fin(self, edge, u0, u1, hgt, rake=0.0, shape="round", n_rays=None, base=2):
        """A soft-rayed fin: rounded, tall in front (shape 'front'), or a flat strip ('strip')."""
        spans = []
        N = 12
        for i in range(N + 1):
            f = i / N
            if shape == "front":     # tall leading edge, falling away (trout, carp)
                hh = hgt * (math.sin(min(1, f * 2.6) * math.pi / 2) ** 0.6) * (1 - 0.7 * smooth01(f))
            elif shape == "strip":
                hh = hgt * min(1, f * 6, (1 - f) * 6) ** 0.5
            elif shape == "tri":     # swept triangle (shark)
                hh = hgt * (f / 0.35 if f < 0.35 else max(0, 1 - (f - 0.35) / 0.65 * 1.15))
            else:
                hh = hgt * math.sin(math.pi * f) ** 0.7
            u = u0 + (u1 - u0) * f
            spans.append((u, max(hh, 0.0), rake * hh / max(hgt, 1e-6) * self.D * 0.5))
        pts = self.fin_poly(edge, spans)
        rays = []
        nr = n_rays or max(3, int(abs(self.X(u0) - self.X(u1)) / 2.2))
        for i in range(nr + 1):
            u = u0 + (u1 - u0) * (i + 0.5) / (nr + 1)
            f = (u - u0) / (u1 - u0)
            x, y = self.at(u, edge)
            j = min(int(f * N + 0.5), N)
            hh = spans[j][1]
            rays.append((x, y, x - spans[j][2] - 1, y + edge * hh * self.D))
        return self.paint_fin(pts, rays if nr > 0 else None, base=base)

    def spiny_fin(self, u0, u1, heights, soft_to=None, soft_h=0.0):
        """Spiny dorsal: spines with membrane sagging between them, then an optional soft lobe."""
        n = len(heights)
        spans = []
        sp = []
        for i, hgt in enumerate(heights):
            u = u0 + (u1 - u0) * i / (n - 1)
            spans.append((u, hgt, 0.8))
            sp.append((u, hgt))
            if i < n - 1:
                un = u0 + (u1 - u0) * (i + 0.5) / (n - 1)
                spans.append((un, (hgt + heights[i + 1]) / 2 * 0.62, 0.4))
        if soft_to:
            N = 8
            for i in range(1, N + 1):
                f = i / N
                u = u1 + (soft_to - u1) * f
                hh = soft_h * math.sin(math.pi * (0.25 + 0.75 * f)) ** 0.6 * (0.55 + 0.45 * math.sin(math.pi * min(1, f * 1.4)))
                spans.append((u, hh, 1.2 * f))
        # spans must run front (small u) to back
        spans.sort(key=lambda s: s[0])
        pts = self.fin_poly(-1, spans)
        rays = []
        for u, hgt in sp:
            x, y = self.at(u, -1)
            rays.append((x, y + 1, x - 0.8, y - hgt * self.D))
        if soft_to:
            nr = max(3, int(abs(self.X(u1) - self.X(soft_to)) / 2.2))
            for i in range(1, nr):
                u = u1 + (soft_to - u1) * i / nr
                x, y = self.at(u, -1)
                rays.append((x, y, x - 1.5, y - soft_h * self.D * 0.9))
        m = self.paint_fin(pts, rays, base=2, ray_shade=1)
        # spines darker at the base, lighter tips
        for u, hgt in sp:
            x, y = self.at(u, -1)
            xi = int(round(x - 0.4))
            for yy in range(int(y - hgt * self.D + 0.5), int(y) + 1):
                if 0 <= yy < self.H and m[yy, xi]:
                    self.img[yy, xi] = self.fr[0] if yy > y - hgt * self.D * 0.5 else self.fr[1]
        return m

    def tail(self):
        k = self.k
        kind = k["tail"]
        if self.eel: return
        L, D = self.L, self.D
        tl = L * self.tl
        ts = D * 0.5 * k.get("ts", 1.0)
        ox = self.xp + 2
        oy = (self.top(1) + self.bot(1)) / 2
        ph = (self.bot(1) - self.top(1)) / 2 + 0.6
        P = None
        if kind in ("fork", "deepfork"):
            nk = 0.5 if kind == "fork" else 0.3
            P = [(0, -ph), (0.3, -0.45), (0.7, -0.82), (1.0, -1.02), (0.95, -0.86), (0.75, -0.5), (nk, 0),
                 (0.75, 0.5), (0.95, 0.86), (1.0, 1.02), (0.7, 0.82), (0.3, 0.45), (0, ph)]
        elif kind == "lunate":
            P = [(0, -ph), (0.3, -0.35), (0.65, -0.78), (1.0, -1.15), (0.92, -0.98), (0.6, -0.5), (0.42, -0.14), (0.4, 0),
                 (0.42, 0.14), (0.6, 0.5), (0.92, 0.98), (1.0, 1.15), (0.65, 0.78), (0.3, 0.35), (0, ph)]
        elif kind in ("square", "soft"):
            nk = 0.92 if kind == "square" else 0.8
            P = [(0, -ph), (0.4, -0.6), (0.85, -0.92), (1.0, -0.9), (0.97, -0.5), (nk, 0), (0.97, 0.5), (1.0, 0.9), (0.85, 0.92), (0.4, 0.6), (0, ph)]
        elif kind == "round":
            # a fan that widens from the peduncle and ends in a round edge
            P = [(0, -ph), (0.3, -0.62)]
            for i in range(11):
                a = -math.pi / 2 * 0.8 + i * math.pi * 0.8 / 10
                P.append((0.45 + 0.55 * math.cos(a) ** 0.7, math.sin(a) * 0.82))
            P += [(0.3, 0.62), (0, ph)]
        elif kind == "veil":
            P = [(0, -ph)]
            for i in range(17):
                a = -math.pi / 2 + i * math.pi / 16
                rr = 0.55 + 0.45 * abs(math.sin(a)) ** 0.7 - 0.25 * math.exp(-(a / 0.25) ** 2)
                P.append((rr * (1.0 + 0.06 * math.sin(i * 1.7)), math.sin(a) * 1.05))
            P.append((0, ph))
        elif kind == "shark":
            P = [(0, -ph), (0.35, -0.6), (0.75, -1.05), (1.05, -1.5), (1.0, -1.3), (0.82, -0.75), (0.7, -0.3), (0.62, 0.05),
                 (0.55, 0.3), (0.45, 0.68), (0.32, 0.62), (0.18, 0.4), (0, ph)]
        if P is None: return
        pts = []
        for dx, dy in P:
            if isinstance(dy, float) and abs(dy) == ph and dx == 0:
                pts.append((ox, oy + dy))
            else:
                pts.append((ox - dx * tl, oy + dy * ts))
        rays = []
        for i in range(1, len(pts) - 1):
            rays.append((ox - 1, oy, pts[i][0] + (1 if kind != "round" else 0.5), pts[i][1]))
        # extra rays between the vertices
        n = 9 if kind not in ("shark", "lunate") else 5
        for i in range(n):
            a = -0.9 + 1.8 * i / (n - 1)
            rays.append((ox - 1, oy, ox - tl * 1.1, oy + a * ts * 1.1))
        m = self.paint_fin(pts, rays, base=2, ray_shade=1)
        # darker near the peduncle, lighter thin trailing edge
        ys, xs = np.where(m)
        for y, x in zip(ys, xs):
            if x > ox - tl * 0.22 and self.img[y, x][3] and (y + x) % 2 == 0:
                self.img[y, x] = self.fr[1]
        if kind == "veil" or k.get("pat") in ("koi",) and kind == "veil":
            pass

    def dorsal(self):
        k = self.k
        d = k.get("dorsalk", k["dorsal"])
        D = self.D
        if d == "spiny":
            hs = [0.2, 0.33, 0.35, 0.32, 0.27, 0.2, 0.13]
            if self.key in ("bluegill", "pumpkinseed", "sheepshead", "scup", "pinfish", "snapper", "seabass", "grouper"): hs = [0.16, 0.25, 0.27, 0.26, 0.24, 0.22, 0.2, 0.18]
            if self.key in ("jack",): hs = [0.12, 0.2, 0.2, 0.16, 0.12, 0.08]
            soft_to = 0.8 if self.key != "jack" else 0.86
            sh = 0.28 if self.key not in ("jack", "seatrout", "snook") else 0.24
            if self.key in ("bluegill", "pumpkinseed", "sheepshead", "scup", "seabass"): sh = 0.3
            if self.key == "seabass": soft_to = 0.84
            self.spiny_fin(0.27, 0.52, hs, soft_to=soft_to, soft_h=sh)
            if k.get("filament_top"):
                x, y = self.at(0.82, -1)
                self.paint_fin([(x, y), (x - 6, y - D * 0.5), (x - 4, y - D * 0.5), (x + 3, y)], None, base=2)
        elif d == "two":
            three = k.get("three_dorsal")
            if three:
                self.soft_fin(-1, 0.28, 0.43, 0.22, rake=0.5)
                self.soft_fin(-1, 0.47, 0.66, 0.2, rake=0.4)
                self.soft_fin(-1, 0.7, 0.86, 0.17, rake=0.3)
            else:
                hs = [0.18, 0.3, 0.32, 0.3, 0.25, 0.18, 0.1]
                self.spiny_fin(0.27, 0.5, hs)
                self.soft_fin(-1, 0.56, 0.78, 0.26, rake=0.9, shape="front")
        elif d == "small":
            if k.get("longdorsal"):
                self.soft_fin(-1, 0.35, 0.78, 0.24, rake=0.4, shape="front")
            else:
                self.soft_fin(-1, 0.38, 0.56, 0.36 if self.h < 0.3 else 0.3, rake=1.0, shape="front")
            if k.get("filament"):
                x, y = self.at(0.53, -1)
                self.paint_fin([(x + 1, y), (x - 9, y - D * 0.62), (x - 11, y - D * 0.6), (x - 2, y)], None, base=2)
        elif d == "long":
            if self.key == "crappie":
                self.spiny_fin(0.4, 0.55, [0.2, 0.28, 0.3, 0.3, 0.28], soft_to=0.82, soft_h=0.34)
            elif self.key in ("koi", "butterfly", "ogon", "goldfish"):
                self.soft_fin(-1, 0.34, 0.8, 0.28 if self.key != "butterfly" else 0.4, rake=0.6, shape="front")
            else:
                self.soft_fin(-1, 0.3, 0.9, 0.17, rake=0.3, shape="strip")
        elif d == "fringe":
            self.soft_fin(-1, 0.06, 0.98, 0.13, rake=0.3, shape="strip")
        elif d == "full":
            spans = []
            N = 14
            for i in range(N + 1):
                f = i / N
                u = 0.04 + 0.88 * f
                hh = 0.26 * (1 - 0.55 * f) * min(1, f * 8) ** 0.5 * min(1, (1 - f) * 10) ** 0.5
                spans.append((u, hh, 0.5))
            pts = self.fin_poly(-1, spans)
            rays = []
            for i in range(1, N):
                u, hh, _ = spans[i]
                x, y = self.at(u, -1)
                rays.append((x, y, x - 1, y - hh * self.D))
            self.paint_fin(pts, rays)
        elif d == "sail":
            spans = []
            N = 16
            for i in range(N + 1):
                f = i / N
                u = 0.1 + 0.58 * f
                hh = 1.05 * math.sin(math.pi * (0.12 + 0.88 * f) ** 0.9) ** 0.8 * (1 - 0.35 * f) + 0.04
                spans.append((u, hh, 1.5))
            pts = self.fin_poly(-1, spans)
            rays = []
            for i in range(0, N + 1, 2):
                u, hh, _ = spans[i]
                x, y = self.at(u, -1)
                rays.append((x, y, x - 1.5, y - hh * self.D))
            m = self.paint_fin(pts, rays, base=2)
            # the sail's dark spots
            for i in range(12):
                u = 0.16 + 0.04 * i
                x, y = self.at(u, -1)
                for j in range(2):
                    yy = int(y - self.D * (0.32 + 0.28 * j + 0.05 * (i % 2)))
                    xx = int(x - 1)
                    if m[yy, xx]: self.img[yy, xx] = self.fr[0]
            self.soft_fin(-1, 0.82, 0.88, 0.1)
        elif d == "shark":
            x0, y0 = self.at(0.34, -1); x1, y1 = self.at(0.52, -1)
            pts = [(x0, y0 + 2), (x0 - (x0 - x1) * 0.55, y0 - D * 0.62), (x1 - 2, y1 - D * 0.58), (x1 - 1, y1 - D * 0.5), (x1, y1 + 2)]
            self.paint_fin(pts, None, base=2)
            u2 = 0.8 if self.key != "dogfish" else 0.74
            x0, y0 = self.at(u2, -1); x1, y1 = self.at(u2 + 0.08, -1)
            self.paint_fin([(x0, y0 + 2), (x0 - 3, y0 - D * 0.28), (x1 - 2, y1 - D * 0.24), (x1, y1 + 2)], None, base=2)
            if k.get("dogspines"):
                for uu in (0.34, u2):
                    x, y = self.at(uu, -1)
                    self.img[int(y - D * 0.3):int(y), int(x)] = self.fr[4]
        elif d == "back":
            self.soft_fin(-1, 0.68, 0.86, 0.3, rake=0.8, shape="front")
        elif d == "eel":
            if self.eel:
                self.eel_fins()
            else:   # snakehead, walking catfish: a long low dorsal to the tail
                self.soft_fin(-1, 0.3, 0.98, 0.14, rake=0.2, shape="strip")
        if k.get("adipose"):
            x0, y0 = self.at(0.84, -1); x1, y1 = self.at(0.92, -1)
            self.paint_fin([(x0, y0 + 1.5), (x0 - 2, y0 - D * 0.1), (x1 - 1, y1 - D * 0.12), (x1, y1 + 1.5)], None, base=2)
        if k.get("finlets"):
            for i in range(5):
                u = 0.8 + i * 0.035
                for edge in (-1, 1):
                    x, y = self.at(u, edge)
                    c = hexc("#e8c840") if self.key in ("tuna", "bluefin", "albacore", "mackerel", "bonito", "kingfish") else None
                    pts = [(x, y + edge * -1), (x - 1.5, y + edge * D * 0.1), (x - 3, y + edge * -1)]
                    m = poly_mask(self.W, self.H, pts)
                    col = small_ramp("#e0c040")[2] if self.key in ("tuna", "bluefin") else self.fr[3]
                    self.img[m] = col
                    self.fin |= m

    def eel_fins(self):
        # one long fin along the back, round the tail point and along the belly
        D = self.D
        spans_t = [(u, 0.2 * min(1, (u - 0.28) * 8), 0.2) for u in np.linspace(0.28, 1.0, 30)]
        spans_b = [(u, 0.17 * min(1, (u - 0.5) * 8), 0.2) for u in np.linspace(0.5, 1.0, 24)]
        rays = lambda sp, e: [(self.at(u, e)[0], self.at(u, e)[1], self.at(u, e)[0] - 1, self.at(u, e)[1] + e * hh * D) for u, hh, _ in sp[1::2]]
        self.paint_fin(self.fin_poly(-1, spans_t), rays(spans_t, -1), base=1, ray_shade=0)
        self.paint_fin(self.fin_poly(1, spans_b), rays(spans_b, 1), base=1, ray_shade=0)
        x, y = self.at(1.0, 0)
        self.paint_fin([(x + 4, y - D * 0.18), (x - 4, y - 1), (x - 4, y + 1), (x + 4, y + D * 0.18)], None, base=2)

    def lower_fins(self):
        k = self.k
        D = self.D
        an = k.get("anal")
        if an is None:
            an = "mid"
        if k.get("longfins"): an = "longfins"
        if an == "mid": self.soft_fin(1, 0.62, 0.8, 0.24, rake=0.8)
        elif an == "small": self.soft_fin(1, 0.7, 0.82, 0.24, rake=0.8, shape="front")
        elif an == "long": self.soft_fin(1, 0.56, 0.86, 0.2, rake=0.6, shape="front" if self.key not in ("catfish",) else "strip")
        elif an == "longfins": self.soft_fin(1, 0.55, 0.85, 0.5, rake=1.2)
        elif an == "eel_short": self.soft_fin(1, 0.5, 0.96, 0.14, rake=0.2, shape="strip")
        elif an == "fringe": self.soft_fin(1, 0.2, 0.98, 0.13, rake=0.3, shape="strip")
        elif an == "full": self.soft_fin(1, 0.48, 0.92, 0.2, rake=0.4, shape="strip")
        elif an == "back": self.soft_fin(1, 0.7, 0.86, 0.26, rake=0.7, shape="front")
        elif an == "two":
            self.soft_fin(1, 0.45, 0.65, 0.17, rake=0.3)
            self.soft_fin(1, 0.69, 0.86, 0.15, rake=0.3)
        elif an == "shark":
            self.soft_fin(1, 0.76, 0.82, 0.16, rake=1.2, shape="tri")
        elif an == "eel":
            pass
        # pelvic fins
        pv = k.get("pelvic")
        if pv is None:
            pv = "thoracic" if k["dorsal"] in ("spiny", "two", "full") or self.key in ("crappie", "oscar", "cichlid", "snakehead") else "abdominal"
        if self.eel: pv = "none"
        if pv == "thoracic":
            self.soft_fin(1, 0.27, 0.38, 0.26, rake=1.4, shape="front", base=1)
        elif pv == "abdominal":
            self.soft_fin(1, 0.5, 0.6, 0.24 if not k.get("longfins") else 0.4, rake=1.4, shape="front", base=1)
        elif pv == "shark":
            self.soft_fin(1, 0.62, 0.7, 0.14, rake=1.2, shape="tri", base=1)

    # -------------------------------------------------- body
    def paint_body(self):
        k = self.k
        x0, x1 = int(math.floor(self.xp)) + 1, int(math.ceil(self.xn))
        for x in range(x0, x1):
            u = self.U(x + 0.5)
            if u < 0 or u > 1.0: continue
            t, b = self.top(u), self.bot(u)
            for y in range(int(t), int(b) + 2):
                if t <= y + 0.5 <= b:
                    self.body[y, x] = True
        if k.get("beak"):
            # gar: long narrow jaws
            bl = k["beak"] * self.L
            yy = self.at(0.0, 0)[1]
            hw = max(1.6, self.D * 0.09)
            pts = [(self.xn - 2, yy - hw * 1.5), (self.xn + bl, yy - hw * 0.3), (self.xn + bl, yy + hw * 0.4), (self.xn - 2, yy + hw * 1.6)]
            self.beak = poly_mask(self.W, self.H, pts)
            self.body |= self.beak
        sc = k.get("scale", 2)
        ss = k.get("ss", 0.8)
        pat = k.get("pat", "none")
        if pat == "scales": ss = max(ss, 1.2)
        if pat == "bigscales": sc = max(sc, 5); ss = max(ss, 1.3)
        ys, xs = np.where(self.body)
        self.bodyi = {}
        for y, x in zip(ys, xs):
            u = self.U(x + 0.5)
            uc = min(max(u, 0), 1)
            t, b = self.top(uc), self.bot(uc)
            v = (y + 0.5 - t) / max(1.0, b - t)
            v = min(max(v, 0), 1)
            if v < 0.5: i = 1.5 + v / 0.5 * 4.8
            else: i = 6.3 + (v - 0.5) / 0.5 * 4.2
            i += 0.9 * math.exp(-((v - 0.27) / 0.09) ** 2)          # light from above on the upper flank
            i -= 2.0 * max(0, v - 0.9) / 0.1                       # belly turns under, into shadow
            if u < 0.25: i -= 0.6 * (1 - v)                        # head a touch darker on top
            if u > 0.85: i -= 0.5
            # scales: staggered rows; each scale's rear edge dark, its front lit
            if sc and 0.18 < u < 0.97 and 0.06 < v < 0.9:
                sw, sh = sc + 1, sc
                r = y // sh
                lx = (x + (r % 2) * (sw // 2)) % sw
                ly = y % sh
                if sc >= 4:
                    # big scales: a dark rim arc on the back of each
                    cxs, cys = sw - 1.0, sh / 2 - 0.5
                    d = ((lx - cxs) / sw) ** 2 + ((ly - cys) / (sh * 0.62)) ** 2
                    if 0.55 < d < 1.0 and lx < sw - 1: i -= 1.1 * ss
                    elif lx == sw - 1 and ly == 1: i += 0.6 * ss
                else:
                    if (lx == 0 and ly >= 1) or (lx == 1 and ly == sh - 1): i -= 0.9 * ss
                    elif lx == sw - 2 and ly == 0: i += 0.6 * ss
            self.bodyi[(y, x)] = [i, None, u, v]   # shade index, alt ramp, u, v
        self.markings()
        # write the body pixels
        for (y, x), (i, alt, u, v) in self.bodyi.items():
            if alt is None:
                self.img[y, x] = self.br[max(0, min(10, dither(i, x, y)))]
            else:
                ramp = alt
                j = (i - 1.5) / 9.0 * (len(ramp) - 1)
                self.img[y, x] = ramp[max(0, min(len(ramp) - 1, dither(j, x, y)))]

    def markings(self):
        k = self.k
        pat = k.get("pat", "none")
        B = self.bodyi
        rng = np.random.default_rng(self.seed * 31 + 5)
        L, D = self.L, self.D
        def dark(y, x, amt):
            if (y, x) in B: B[(y, x)][0] -= amt
        def color(y, x, ramp, keep=0.0):
            if (y, x) in B: B[(y, x)][1] = ramp
        items = list(B.items())
        if pat in ("bars", "bars_faint", "bars3", "bold_bars"):
            n = {"bars": 7, "bars_faint": 7, "bars3": 3, "bold_bars": 6}[pat]
            s = {"bars": 2.2, "bars_faint": 1.2, "bars3": 3.4, "bold_bars": 4.2}[pat]
            w = {"bars": 0.04, "bars_faint": 0.045, "bars3": 0.065, "bold_bars": 0.05}[pat]
            vmax = {"bars": 0.75, "bars_faint": 0.7, "bars3": 0.85, "bold_bars": 0.92}[pat]
            u0, u1 = (0.3, 0.86) if pat != "bars3" else (0.34, 0.72)
            if pat == "bold_bars": u0, u1 = 0.22, 0.86
            cs = [u0 + (u1 - u0) * j / (n - 1) for j in range(n)]
            for (y, x), (i, alt, u, v) in items:
                for c in cs:
                    d = abs(u - (c + (v - 0.5) * 0.04 + 0.006 * math.sin(v * 9 + c * 20)))
                    if d < w and v < vmax:
                        f = 1 - max(0, v - vmax * 0.6) / (vmax * 0.4)
                        dark(y, x, s * f * (1 if d < w * 0.7 else 0.5))
        elif pat == "dark_bars":
            n = 13
            for (y, x), (i, alt, u, v) in items:
                if v > 0.5 or u < 0.22: continue
                for j in range(n):
                    c = 0.25 + 0.7 * j / (n - 1)
                    wob = 0.018 * math.sin(v * 14 + j * 2.1)
                    if abs(u - c - wob - (v - 0.2) * 0.05) < 0.012 + 0.006 * (j % 2):
                        dark(y, x, 2.6 * (1 - v / 0.5) + 0.6)
        elif pat == "blotch_line":
            for (y, x), (i, alt, u, v) in items:
                if u < 0.28 or u > 0.98: continue
                X = x
                wob = math.sin(X * 0.75) * 1.3 + math.sin(X * 0.31 + 1) * 0.9
                yc = self.top(u) + (self.bot(u) - self.top(u)) * 0.47 + wob
                half = (1.5 + 1.0 * abs(math.sin(X * 0.5))) * self.D / 28
                dd = abs(y + 0.5 - yc) - half
                if dd < 0: dark(y, x, 3.6 if dd < -1 else 2.6)
                elif dd < 0.8 and (x + y) % 2 == 0: dark(y, x, 2.0)
            for _ in range(10):
                u = rng.uniform(0.3, 0.85); v = rng.uniform(0.15, 0.35)
                x, y = self.at(u, v * 2 - 1)
                dark(int(y), int(x), 2.5)
        elif pat == "line":
            for (y, x), (i, alt, u, v) in items:
                if u < 0.28: continue
                yc = self.top(u) + (self.bot(u) - self.top(u)) * (0.46 - 0.05 * (u - 0.3))
                if abs(y + 0.5 - yc) < 0.55: dark(y, x, 5.0)
        elif pat in ("stripes", "stripes_gold"):
            gold = small_ramp("#e8c040", 5) if pat == "stripes_gold" else None
            nst = 6 if self.key in ("striper",) else (5 if self.key != "mullet" else 6)
            for (y, x), (i, alt, u, v) in items:
                if u < 0.24 or v > 0.8: continue
                for j in range(nst):
                    vc = 0.12 + 0.62 * j / (nst - 1)
                    if abs(v - vc) * (self.bot(u) - self.top(u)) < 0.5 + (0.1 if self.key != "mullet" else 0):
                        if gold is not None: B[(y, x)][1] = gold
                        else:
                            brk = self.key == "striper" and noise2(x, y * 3, self.seed, 3.0) < 0.2
                            if not brk: dark(y, x, 1.5 if self.key in ("mullet", "whitebass", "bonito") else 3.4)
            if pat == "stripes_gold":
                x, y = self.at(0.3, -0.4)
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        dark(int(y) + dy, int(x) + dx, 4)
        elif pat == "gold_stripe":
            gold = small_ramp("#e0c050", 5)
            for (y, x), (i, alt, u, v) in items:
                if 0.3 < u < 0.95 and abs(v - 0.43) < 0.06: B[(y, x)][1] = gold
        elif pat in ("spots", "specks"):
            n = int(L * (0.5 if pat == "spots" else 0.9))
            for _ in range(n):
                u = rng.uniform(0.18, 0.98); v = rng.uniform(0.02, 0.62 if self.key != "flounder" else 0.95)
                x, y = self.at(u, v * 2 - 1)
                r = (rng.uniform(0.5, 1.1) * max(1, D / 20)) if pat == "spots" else 0.4
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        if dx * dx + dy * dy <= r * r + 0.3:
                            dark(int(y) + dy, int(x) + dx, 3.6 if pat == "spots" else 2.4)
            if self.key in ("seatrout", "gar", "sauger", "rainbow"):
                self.fin_spots = True
        elif pat == "mottle":
            for (y, x), (i, alt, u, v) in items:
                n = fbm(x, y * 1.2, self.seed, 5.0)
                if n < 0.36 and v < 0.85: dark(y, x, 2.8 if n < 0.3 else 1.6)
                elif n > 0.72 and v > 0.2: dark(y, x, -0.8)
        elif pat in ("koi", "koi_calico"):
            red = small_ramp("#e8502a", 5)
            blk = small_ramp("#2a2a2a", 5)
            for (y, x), (i, alt, u, v) in items:
                n = fbm(x, y * 1.3, self.seed + 3, 7.0)
                if v < 0.72 and n > 0.52 and u < 0.92: B[(y, x)][1] = red
                if pat == "koi_calico" and fbm(x * 1.2, y, self.seed + 11, 4.5) > 0.66 and v < 0.6: B[(y, x)][1] = blk
            # a red crown on the head, as on a kohaku
            hx, hy = self.at(0.1, -0.5)
            for (y, x), (i, alt, u, v) in items:
                if (x - hx) ** 2 / 9 + (y - hy) ** 2 / 4 < 1: B[(y, x)][1] = red
        elif pat == "orange_blotch":
            org = small_ramp("#e8782a", 5)
            for (y, x), (i, alt, u, v) in items:
                n = fbm(x * 1.1, y, self.seed + 5, 4.0)
                if n > 0.56 and 0.25 < v < 0.95 and u > 0.2: B[(y, x)][1] = org
        elif pat == "blue_spots":
            blue = small_ramp("#3a8ad8", 5)
            for _ in range(int(L * 0.7)):
                u = rng.uniform(0.15, 0.92); v = rng.uniform(0.15, 0.8)
                x, y = self.at(u, v * 2 - 1)
                if (int(y), int(x)) in B: B[(int(y), int(x))][1] = blue
            if self.key == "pumpkinseed":
                org = small_ramp("#e89a3a", 5)
                for (y, x), (i, alt, u, v) in items:
                    if u < 0.24 and 0.4 < v < 0.8 and (x + y * 2) % 5 == 0: B[(y, x)][1] = blue
        elif pat == "gillspot":
            if self.key == "haddock":
                for (y, x), (i, alt, u, v) in items:
                    yc = self.top(u) + (self.bot(u) - self.top(u)) * 0.35
                    if u > 0.24 and abs(y + 0.5 - yc) < 0.55: dark(y, x, 4)
                cx, cy = self.at(0.32, -0.15)
                for (y, x), (i, alt, u, v) in items:
                    if (x - cx) ** 2 / 6 + (y - cy) ** 2 / 4 < 1: dark(y, x, 4)
            else:
                cx, cy = self.at(0.22, -0.55)
                for (y, x), (i, alt, u, v) in items:
                    if (x - cx) ** 2 + (y - cy) ** 2 < 2.2: dark(y, x, 5)
        elif pat == "rainbow":
            pink = small_ramp("#e07a8a", 5)
            for (y, x), (i, alt, u, v) in items:
                if abs(v - 0.5) < 0.1 + 0.02 * math.sin(x * 0.5) and u > 0.08: B[(y, x)][1] = pink
            for _ in range(int(L * 0.9)):
                u = rng.uniform(0.15, 0.98); v = rng.uniform(0.0, 0.5)
                x, y = self.at(u, v * 2 - 1)
                dark(int(y), int(x), 4)
            self.fin_spots = True
        elif pat == "halo":
            red = small_ramp("#d83a2a", 5)
            if self.key == "brook":
                for (y, x), (i, alt, u, v) in items:   # wormy pale marks on the back
                    n = noise2(x * 1.6, y * 1.6, self.seed + 2, 3.0)
                    if v < 0.4 and 0.47 < n < 0.55: dark(y, x, -2.5)
                    elif v < 0.62 and n > 0.8: dark(y, x, -1.6)
                halo = small_ramp("#5a8ad8", 5)
            else:
                halo = small_ramp("#e8dcc0", 5)
                for _ in range(int(L * 0.4)):
                    u = rng.uniform(0.15, 0.85); v = rng.uniform(0.05, 0.5)
                    x, y = self.at(u, v * 2 - 1)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if abs(dx) + abs(dy) < 2: dark(int(y) + dy, int(x) + dx, 4)
            for _ in range(int(L * 0.18)):
                u = rng.uniform(0.25, 0.85); v = rng.uniform(0.35, 0.62)
                x, y = self.at(u, v * 2 - 1)
                xi, yi = int(x), int(y)
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        d2 = dx * dx + dy * dy
                        if d2 <= 1 and (yi + dy, xi + dx) in B: B[(yi + dy, xi + dx)][1] = red
                        elif d2 <= 4 and (yi + dy, xi + dx) in B: B[(yi + dy, xi + dx)][1] = halo
        if k.get("mirror"):
            # mirror carp: a few big, shiny scales along the back and lateral line
            gold = small_ramp("#d8b060", 5)
            for j in range(9):
                for row, vc in ((0, -0.72), (1, -0.05)):
                    if row == 1 and j % 2: continue
                    u = 0.25 + j * 0.075 + rng.uniform(-0.01, 0.01)
                    cx, cy = self.at(u, vc)
                    rr = rng.uniform(1.8, 2.8) * D / 26
                    for (y, x), (i, alt, uu, v) in items:
                        d = math.hypot(x - cx, (y - cy) * 1.1)
                        if d < rr: B[(y, x)][0] += 1.4 if d < rr - 1 else -1.8
        if k.get("eyespot") and k["tail"] in ("round",):
            cx, cy = self.at(0.92, -0.3)
            orange = small_ramp("#f2a030", 5)
            for (y, x), (i, alt, u, v) in items:
                d = math.hypot(x - cx, y - cy)
                rr = max(1.8, D * 0.1)
                if d < rr: B[(y, x)][0] -= 6
                elif d < rr + 1.1: B[(y, x)][1] = orange
        if k.get("tailspot") or (k.get("eyespot") and k["tail"] != "round"):
            cx, cy = self.at(0.95, -0.2)
            orange = small_ramp("#f2a030", 5)
            for (y, x), (i, alt, u, v) in items:
                d = math.hypot(x - cx, y - cy)
                rr = max(1.5, D * 0.09)
                if d < rr: B[(y, x)][0] -= 6
                elif d < rr + 1 and k.get("eyespot"): B[(y, x)][1] = orange
        if k.get("scutes"):
            # jack: the hard scutes along the tail end of the lateral line
            for (y, x), (i, alt, u, v) in items:
                if u > 0.7 and abs(v - 0.5) * (self.bot(u) - self.top(u)) < 0.8: B[(y, x)][0] += (1.6 if x % 2 else -1.2)
        if k.get("scutes5"):
            # sturgeon: rows of pale bony plates
            for row, vc in ((0, 0.04), (1, 0.42), (2, 0.86)):
                for j in range(14):
                    u = 0.2 + j * 0.055
                    if u > 0.96: continue
                    cx, cy = self.at(u, vc * 2 - 1)
                    for (dx, dy, a) in ((0, 0, 2.4), (-1, 0, 1.2), (1, 0, 1.4), (0, -1, 0.8), (-2, 0, -1.5)):
                        if (int(cy) + dy, int(cx) + dx) in B: B[(int(cy) + dy, int(cx) + dx)][0] += a
        if k.get("shine"):
            for (y, x), (i, alt, u, v) in items:
                if abs(v - 0.3 - 0.04 * math.sin(u * 9)) < 0.035 and u > 0.1: B[(y, x)][0] += 2.0

    # -------------------------------------------------- head
    def head(self):
        k = self.k
        D, L = self.D, self.L
        dark = self.br[0]
        # gill cover: a curved line behind the eye, lit on its rear side
        gu = 0.22 if k.get("snout", 1.0) < 1.4 else 0.27
        if k.get("beak"): gu = 0.2
        if self.key in ("monkfish",): gu = 0.3
        if self.key in ("shark", "bonnet", "dogfish", "sturgeon", "paddle", "eel", "conger"): gu = None
        if gu is not None:
            for y in range(self.H):
                for xi in range(int(self.X(gu + 0.08)), int(self.X(gu - 0.06)) + 1):
                    if not self.body[y, xi]: continue
                    u = self.U(xi + 0.5)
                    t, b = self.top(u), self.bot(u)
                    v = (y + 0.5 - t) / max(1, b - t)
                    gx = self.X(gu) - L * 0.045 * math.sin(math.pi * min(max(v, 0), 1)) ** 1.2
                    if 0.1 < v < 0.94:
                        if abs(xi + 0.5 - gx) < 0.55:
                            self.img[y, xi] = self.br[1 if v < 0.6 else 4]
                        elif 0.55 <= (gx - xi - 0.5) < 1.5 and v < 0.8:
                            c = self.img[y, xi].astype(np.float64)
                            self.img[y, xi] = np.round(shade(c, 0.18)).astype(np.uint8)
            if k.get("ear"):
                # sunfish "ear": the dark flap at the back of the gill cover
                cx, cy = self.at(gu + 0.02, -0.25)
                for y in range(int(cy) - 3, int(cy) + 4):
                    for xi in range(int(cx) - 4, int(cx) + 3):
                        if self.body[y, xi] and ((xi - cx + 1) / 2.6) ** 2 + ((y - cy) / 1.9) ** 2 < 1:
                            self.img[y, xi] = self.br[0]
                if self.key == "pumpkinseed":
                    self.img[int(cy), int(cx) - 3] = small_ramp("#e83a2a")[2]
                    self.img[int(cy) + 1, int(cx) - 3] = small_ramp("#e83a2a")[2]
        if self.key in ("shark", "bonnet", "dogfish"):
            # five gill slits
            for j in range(5 if self.key != "dogfish" else 5):
                u = 0.2 + j * 0.028
                x, yt = self.at(u, -0.3); _, yb = self.at(u, 0.5)
                for y in range(int(yt), int(yb) + 1):
                    if self.body[y, int(x)]: self.img[y, int(x)] = self.br[2]
        # mouth
        mouth = k.get("mouth", 1.0)
        mo = k.get("mo", 0.0)
        nose_y = self.at(0.0, 0.0)[1]
        if self.key in ("shark", "bonnet", "dogfish", "sturgeon", "paddle"):
            # mouth on the underside, behind the snout
            pts = [self.at(0.1, 0.75), self.at(0.14, 0.82), self.at(0.19, 0.78)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                for m in line_mask_pts(x0, y0, x1, y1):
                    self.put(m, dark)
        elif k.get("upmouth"):
            # tarpon/arowana: big up-turned jaw, lower jaw jutting out
            x0, y0 = self.at(0.0, -0.4)
            x1, y1 = self.at(0.12 * mouth, 0.35)
            for m in line_mask_pts(x0, y0, x1, y1): self.put(m, dark)
            x2, y2 = self.at(0.0, 0.1)
            for m in line_mask_pts(x0 + 1, y0 + 1, x1, y1 + 1): self.put(m, self.br[8])
        else:
            mv = 0.12 if self.key not in ("catfish", "flathead", "walking", "monkfish") else 0.05
            if self.key in ("drum", "mahi", "redfish", "sturgeon"): mv = 0.55
            if self.key == "monkfish": mv = -0.1
            mlen = 0.05 + 0.055 * mouth
            if self.key in ("catfish", "flathead", "walking", "snakehead"): mlen = 0.1
            n = 8
            pts = []
            for j in range(n + 1):
                f = j / n
                u = mlen * f
                x, y = self.at(u, mv + 0.18 * f)
                pts.append((x, y))
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                for m in line_mask_pts(x0, y0, x1, y1): self.put(m, dark)
            # lit lip below, and a corner
            for (x, y) in pts[:-1]:
                self.put((int(x), int(y) + 1), self.br[8], body_only=True)
            if k.get("teeth"):
                for (x, y) in pts[1:-1:2]: self.put((int(x), int(y) - 1), np.array([245, 245, 235, 255], np.uint8), body_only=True)
            if k.get("sheepteeth"):
                for dx in range(0, 3):
                    self.put((int(pts[0][0]) - dx, int(pts[0][1]) - 1), np.array([240, 236, 220, 255], np.uint8), body_only=True)
            if k.get("lips"):
                for (x, y) in pts[:3]:
                    self.put((int(x), int(y) - 1), self.br[7], body_only=True)
                    self.put((int(x), int(y) + 1), self.br[8], body_only=True)
        # eye
        er = max(1.6, min(L * 0.04, 3.6)) * k.get("er", 1.0)
        if self.D < 10: er = max(1.4, min(er, 2.2))
        eu = 0.1 * (1.3 if k.get("snout", 1.0) > 1.2 else 1.0)
        if k.get("beak"): eu = 0.06
        if self.key in ("monkfish",): eu = 0.16
        if self.key in ("catfish", "flathead", "walking", "snakehead"): eu = 0.08
        if self.eel: eu = 0.05
        if self.key in ("shark", "bonnet", "dogfish", "sturgeon"): eu = 0.13
        if self.key == "paddle": eu = 0.06
        ev = -0.32 if self.key not in ("catfish", "flathead", "walking") else -0.2
        if self.key == "mahi": ev = 0.1
        if self.key == "flounder": ev = -0.6
        if k.get("upmouth"): ev = -0.2
        ex, ey = self.at(eu, ev)
        ex += 0.5
        self.eye(ex, ey, er, k.get("eye", "#c8902a"), walleye=k.get("walleye", False))
        if self.key == "flounder":
            ex2, ey2 = self.at(eu + 0.05, -0.82)
            self.eye(ex2, ey2 + 1, er * 0.9, k.get("eye", "#c8902a"))
        if k.get("eyes", 1) == 3:
            ex3, ey3 = self.at(eu + 0.07, -0.62)
            self.eye(ex3, ey3, er * 0.8, k.get("eye", "#c8902a"))
        # whiskers and barbels
        if k.get("whisk"):
            x, y = self.at(0.0, 0.1)
            koi = self.key in ("koi", "butterfly", "ogon")
            curves = [((x, y), (x + 3, y + 2), (x + 4, y + 5))] if koi else [
                ((x - 1, y - 1), (x + 4, y - 2), (x + 7, y + 1), (x + 8, y + 4)),
                ((x - 1, y + 1), (x + 3, y + 3), (x + 4, y + 6)),
                ((x - 2, y + 2), (x, y + 5), (x - 1, y + 7))]
            if self.key == "flathead" or self.key == "walking":
                curves = curves[:2]
            for c in curves:
                for (x0, y0), (x1, y1) in zip(c, c[1:]):
                    for m in line_mask_pts(x0, y0, x1, y1): self.put(m, self.br[2] if not koi else self.br[5], over=True)
        if k.get("barbels"):
            x, y = self.at(0.06, 0.95) if self.key != "arowana" else self.at(0.0, 0.4)
            for dx in (0, 2, 4) if self.key == "sturgeon" else (0,):
                for dy in range(1, 4):
                    self.put((int(x) - dx + (dy if self.key == "arowana" else 0), int(y) + dy), self.br[3], over=True)
        if k.get("lure"):
            # monkfish: the fishing-rod spine on its head, with a fleshy lure
            x, y = self.at(0.1, -1)
            c = [(x, y), (x + 2, y - 5), (x + 5, y - 8), (x + 8, y - 8)]
            for (x0, y0), (x1, y1) in zip(c, c[1:]):
                for m in line_mask_pts(x0, y0, x1, y1): self.put(m, self.fr[1], over=True)
            for dx, dy in ((8, -8), (9, -8), (8, -7), (9, -7), (10, -8)):
                self.put((int(x + dx), int(y + dy)), small_ramp("#e8d0a0")[3], over=True)
            # the jaw full of teeth
            for j in range(6):
                xx, yy = self.at(0.02 + j * 0.03, 0.3)
                self.put((int(xx), int(yy) - 1), np.array([240, 236, 220, 255], np.uint8), body_only=True)

    def eye(self, ex, ey, er, iris, walleye=False):
        ir = small_ramp(iris, 5)
        for y in range(int(ey - er - 2), int(ey + er + 2)):
            for x in range(int(ex - er - 2), int(ex + er + 2)):
                d = math.hypot(x + 0.5 - ex, y + 0.5 - ey)
                if d < er:
                    if d > er - 0.8 and er > 1.8: c = self.br[0]
                    else: c = ir[3] if (y + 0.5 < ey - 0.3) else ir[2]
                    if d <= er - 0.8 and y + 0.5 > ey + er * 0.35: c = ir[1]
                    self.img[y, x] = c
        # pupil
        pr = er * (0.45 if not walleye else 0.4)
        for y in range(int(ey - er), int(ey + er + 1)):
            for x in range(int(ex - er), int(ex + er + 1)):
                if math.hypot(x + 0.5 - ex, y + 0.5 - ey) < max(pr, 0.75):
                    self.img[y, x] = np.array([14, 16, 14, 255], np.uint8)
        # catchlight, up and forward
        self.img[int(ey - er * 0.45), int(ex - er * 0.15 + 0.5) if er > 2 else int(ex)] = np.array([255, 255, 240, 255], np.uint8)
        if walleye:
            self.img[int(ey), int(ex) - 1] = np.array([220, 230, 200, 255], np.uint8)

    def put(self, p, c, body_only=False, over=False):
        x, y = int(p[0]), int(p[1])
        if 0 <= x < self.W and 0 <= y < self.H:
            if body_only and not self.body[y, x]: return
            self.img[y, x] = c

    def pectoral(self):
        k = self.k
        D, L = self.D, self.L
        if self.key in ("shark", "bonnet", "dogfish"):
            x, y = self.at(0.27, 0.6)
            pts = [(x + 2, y - 1), (x - L * 0.12, y + D * 0.62), (x - L * 0.14, y + D * 0.58), (x - L * 0.08, y)]
            self.paint_fin(pts, None, base=1)
            return
        if k.get("wings"):
            # searobin/monkfish: big fan-shaped pectorals
            px, py = self.at(0.3, 0.3)
            col = small_ramp(k["fin"])
            for y in range(self.H):
                for x in range(self.W):
                    dx, dy = px - (x + 0.5), (y + 0.5) - py
                    ang = math.atan2(dy, dx); r = math.hypot(dx, dy)
                    R = D * (0.9 if self.key == "searobin" else 0.6)
                    if -0.9 < ang < 1.1 and r < R:
                        ray = abs(math.sin(ang * 7)) < 0.3
                        self.img[y, x] = col[1 if ray else (3 if r > R - 1.2 else 2)]
                        self.fin[y, x] = True
            return
        if self.eel:
            px, py = self.at(0.1, 0.1)
            R = max(3, D * 0.4)
        else:
            px, py = self.at(0.26 if k.get("snout", 1.0) < 1.4 else 0.3, 0.25)
            R = max(4, D * (0.42 if self.h > 0.25 else 0.55))
            if self.key in ("mahi",): px, py = self.at(0.3, 0.1)
        if self.key == "flounder": return
        tint = self.fr[3]
        for y in range(int(py - R), int(py + R + 2)):
            for x in range(int(px - R - 2), int(px + 2)):
                dx, dy = px - (x + 0.5), (y + 0.5) - py
                ang = math.atan2(dy, dx); r = math.hypot(dx, dy)
                lim = R - abs(ang - 0.15) * R * 0.38
                if -0.55 < ang < 0.85 and r < lim and self.img[y, x][3] > 0:
                    base = self.img[y, x].astype(np.float64)
                    ray = abs(math.sin(ang * 9)) < 0.32
                    t = np.array(self.fr[2 if ray else 4], np.float64)
                    c = base * 0.35 + t * 0.65
                    if r > lim - 1.0 or abs(ang + 0.52) < 0.07: c = np.array(self.fr[1], np.float64)
                    c[3] = 255
                    self.img[y, x] = np.round(c).astype(np.uint8)

    def bill(self):
        k = self.k
        if not k.get("bill"): return
        x0, y0 = self.at(0.0, -0.15 if not k.get("paddle") else -0.1)
        if k.get("paddle"):
            bl = 0.42 * self.L
            w = self.D * 0.2
            pts = [(x0 - 2, y0 - w * 0.8), (x0 + bl * 0.4, y0 - w * 0.5), (x0 + bl * 0.85, y0 - w * 1.2), (x0 + bl, y0 - w * 0.7),
                   (x0 + bl, y0 + w * 0.3), (x0 + bl * 0.85, y0 + w * 0.9), (x0 + bl * 0.4, y0 + w * 0.5), (x0 - 2, y0 + w * 1.5)]
            m = poly_mask(self.W, self.H, pts)
            ys, xs = np.where(m & ~self.body)
            for y, x in zip(ys, xs):
                v = (y - (y0 - w)) / (2.4 * w)
                self.img[y, x] = self.br[max(0, min(10, dither(3 + v * 6 + (1 if (x * 3 + y) % 7 == 0 else 0), x, y)))]
            self.body |= m
        else:
            bl = 0.36 * self.L
            pts = [(x0 - 2, y0 - 1.6), (x0 + bl, y0 + 0.2), (x0 + bl, y0 + 0.8), (x0 - 2, y0 + 2.2)]
            m = poly_mask(self.W, self.H, pts)
            ys, xs = np.where(m & ~self.body)
            for y, x in zip(ys, xs):
                self.img[y, x] = self.br[2 if y < y0 + 0.5 else 5]
            self.body |= m

    def extras(self):
        k = self.k
        D = self.D
        if k.get("whiteedge"):
            # brook trout: white leading edge, black stripe, on the lower fins
            ys, xs = np.where(self.fin & ~self.body)
            for y, x in zip(ys, xs):
                if y > self.cy + D * 0.3:
                    lx = x + 1
                    if lx < self.W and not self.fin[y, lx] and not self.body[y, lx]:
                        self.img[y, x] = np.array([246, 244, 236, 255], np.uint8)
                        if x - 1 >= 0 and self.fin[y, x - 1]: self.img[y, x - 1] = np.array([30, 30, 30, 255], np.uint8)
        if getattr(self, "fin_spots", False):
            rng = np.random.default_rng(self.seed + 99)
            ys, xs = np.where(self.fin & ~self.body)
            for j in rng.choice(len(ys), size=min(len(ys) // 9, 40), replace=False):
                y, x = ys[j], xs[j]
                if y < self.cy or self.key in ("gar", "rainbow"): self.img[y, x] = self.fr[0]
        if k.get("glow"):
            gc = hexc(k.get("glow_col", "#9aff5a"))
            ys, xs = np.where(self.img[:, :, 3] > 0)
            for y, x in zip(ys, xs):
                c = self.img[y, x].astype(np.float64)
                n = fbm(x, y, self.seed + 4, 3.0)
                t = 0.18 + (0.4 if n > 0.68 else 0)
                c[:3] = c[:3] * (1 - t) + gc[:3] * t
                self.img[y, x] = np.round(c).astype(np.uint8)
        if k.get("shine"):
            rng = np.random.default_rng(self.seed + 7)
            ys, xs = np.where(self.body)
            for j in rng.choice(len(ys), size=6, replace=False):
                y, x = ys[j], xs[j]
                if self.top(self.U(x)) + 2 < y < self.cy:
                    self.img[y, x] = np.array([255, 250, 220, 255], np.uint8)

    def rim(self):
        # a lit row just inside the top of the back
        for x in range(int(self.X(0.9)), int(self.X(0.12))):
            t = self.top(self.U(x + 0.5))
            y = int(math.ceil(t - 0.5))
            if 0 <= y + 1 < self.H and self.body[y, x] and self.body[y + 1, x]:
                c = self.img[y + 1, x].astype(np.float64)
                self.img[y + 1, x] = np.round(shade(c, 0.22)).astype(np.uint8)

    def paint(self):
        self.tail()
        self.dorsal()
        self.lower_fins()
        self.paint_body()
        self.bill()
        self.head()
        self.pectoral()
        self.extras()
        if self.k.get("two"):
            self.second_head()
        self.rim()
        img = outline(self.img, 0.52)
        return crop(img, 0)

    def second_head(self):
        # Two-Headed Catfish: a second head grows up and forward from the shoulders
        x0 = int(self.X(0.34))
        head = self.img[:, x0:].copy()
        m = head[:, :, 3] > 0
        dy, dx = -int(self.D * 0.8), 1
        sub = np.zeros_like(self.img)
        for y, x in zip(*np.where(m)):
            yy, xx = y + dy, x0 + x + dx
            if 0 <= yy < self.H and 0 <= xx < self.W:
                c = head[y, x].astype(np.float64)
                sub[yy, xx] = np.round(shade(c, -0.1)).astype(np.uint8)
        orig = self.img[:, :, 3] > 0
        under = ~orig & (sub[:, :, 3] > 0)
        self.img[under] = sub[under]
        # a dark seam where the second head tucks behind the first
        for y, x in zip(*np.where(under)):
            if (y + 1 < self.H and orig[y + 1, x]) or (x + 1 < self.W and orig[y, x + 1]):
                self.img[y, x] = np.round(shade(self.img[y, x].astype(np.float64), -0.5)).astype(np.uint8)
        self.body |= under

def outline_inner(img): return img


def line_mask_pts(x0, y0, x1, y1):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    seen = []
    for i in range(n + 1):
        t = i / n
        p = (int(math.floor(x0 + (x1 - x0) * t)), int(math.floor(y0 + (y1 - y0) * t)))
        if not seen or seen[-1] != p: seen.append(p)
    return seen


# ---------------------------------------------------------------- run
def build(only=None):
    kinds = load_kinds()
    os.makedirs(OUT, exist_ok=True)
    jobs = []
    for key, k in kinds.items():
        jobs.append((key, dict(k, **SHAPE.get(key, {}))))
    for vkey, (base, ov) in VARIANTS.items():
        k = dict(kinds[base], **SHAPE.get(base, {}))
        k.update(ov)
        jobs.append((vkey, k, base))
    done = {}
    for j in jobs:
        key, k = j[0], j[1]
        if only and key not in only: continue
        f = Fish(j[2] if len(j) > 2 else key, k, seed=sum(map(ord, key)))
        img = f.paint()
        save(img, os.path.join(OUT, key + ".png"))
        done[key] = img
    return done


def sheet(done, path, scale=2):
    keys = list(done)
    cols = 6
    cw, ch = 150 * scale // 2 * 2, 70 * scale
    rows = (len(keys) + cols - 1) // cols
    from PIL import ImageDraw
    S = Image.new('RGBA', (cols * cw, rows * (ch + 14)), (238, 244, 242, 255))
    d = ImageDraw.Draw(S)
    for i, key in enumerate(keys):
        im = Image.fromarray(done[key], 'RGBA')
        s = max(1, min((cw - 8) // im.width, (ch - 6) // im.height))
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        x = (i % cols) * cw + (cw - im.width) // 2
        y = (i // cols) * (ch + 14) + (ch - im.height) // 2
        S.alpha_composite(im, (x, y))
        d.text(((i % cols) * cw + 4, (i // cols) * (ch + 14) + ch), key, fill=(34, 49, 58, 255))
    S.save(path)


if __name__ == "__main__":
    only = None
    sh = None
    for a in sys.argv[1:]:
        if a.startswith("--only="): only = set(a[7:].split(","))
        if a.startswith("--sheet="): sh = a[8:]
    done = build(only)
    print(len(done), "sprites")
    if sh: sheet(done, sh)
