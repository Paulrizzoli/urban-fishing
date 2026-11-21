"""Builds every fish in Urban Fishing as a 3D model in Blender and renders it to a pixel-art sprite.

usage:  python3 tools/blender/fish3d.py [--only=bass,koi] [--sheet=contact.png] [--glb=DIR] [--samples=48]

Each kind starts from its numbers in godot/scripts/fish_art.gd (KINDS: depth, colors, tail, dorsal
fin, markings). SHAPE below adds the body outline, where the fins sit, eye color and special parts.
The model is a lofted body with a painted skin, flat fins with rays, glossy eyes, and extras
(whiskers, bills, gill slits, finlets...). It's rendered side-on in Cycles at 10x the sprite size,
then shrunk to pixels with a small palette and an outline (common.pixelate) into godot/art/fish/.
Named fish that look different from their kind (gold legends, glowing mutants) are VARIANTS.
"""
import json, math, os, re, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'art', 'fish')


def load_kinds():
    src = open(os.path.join(ROOT, 'godot', 'scripts', 'fish_art.gd')).read()
    return {m.group(1): json.loads(m.group(2)) for m in re.finditer(r'^\t"(\w+)": (\{.*\}),\s*$', src, re.M)}


# Shape and detail on top of KINDS. Keys:
#  pk      where the body is deepest, 0 nose .. 1 tail     he     head curve (<1 blunt, >1 pointed)
#  s0      snout depth (share of the body's depth)         ped    peduncle depth (share)
#  tshare  share of the depth above the midline            mo     nose height (+ = lower)
#  tl/ts   tail length (share of body) and spread           eye    iris color, er eye size
#  scale   scale size (0 = smooth skin)                     ss     scale strength
#  pelvic  "thoracic" (under the gill), "abdominal", "shark" or "none"
#  anal    mid, long, eel, eel_short, fringe, full, small, shark, back, two, none
#  w       body thickness (share of the depth)              W      sprite width in pixels
SHAPE = {
    "bluegill": dict(pk=0.42, he=0.7, s0=0.3, ped=0.24, tl=0.26, eye="#3a2a1a", scale=3, ss=1.0),
    "tilapia": dict(pk=0.4, he=0.75, s0=0.3, ped=0.3, tl=0.26, scale=3, ss=1.1, anal="long"),
    "bass": dict(pk=0.4, he=0.85, s0=0.26, ped=0.3, tl=0.28, scale=3, ss=0.9, mo=0.08, eye="#c89030"),
    "peacock": dict(pk=0.4, he=0.85, s0=0.24, ped=0.3, tl=0.28, scale=2, ss=0.7, eye="#c83a1a"),
    "catfish": dict(pk=0.3, he=0.55, s0=0.42, ped=0.32, tl=0.3, tshare=0.5, scale=0, adipose=True, anal="long", eye="#1a1a14", er=0.8, mo=0.15, w=0.8, W=101),
    "walking": dict(pk=0.3, he=0.55, s0=0.45, ped=0.4, tl=0.18, tshare=0.5, scale=0, anal="eel", eye="#1a1a14", er=0.8, mo=0.1, w=0.75, W=121),
    "mullet": dict(pk=0.42, he=0.8, s0=0.32, ped=0.3, tl=0.28, scale=3, ss=1.1, pelvic="abdominal", eye="#e8e0b0", er=1.1, anal="small", w=0.6),
    "snook": dict(pk=0.4, he=1.25, s0=0.16, ped=0.3, tl=0.28, scale=2, ss=0.6, mo=-0.05, eye="#e0c850"),
    "tarpon": dict(pk=0.42, he=0.95, s0=0.22, ped=0.22, tl=0.32, ts=1.25, scale=5, ss=1.4, pelvic="abdominal", eye="#e8e8e0", er=1.2, filament=True, anal="small", W=94),
    "bowfin": dict(pk=0.35, he=0.7, s0=0.35, ped=0.42, tl=0.22, scale=0, pelvic="abdominal", anal="small", eye="#c8a030", w=0.6),
    "goldfish": dict(pk=0.4, he=0.6, s0=0.4, ped=0.25, tl=0.42, ts=1.4, scale=3, ss=1.4, pelvic="abdominal", eye="#1a1a1a", er=1.2, anal="small", W=95),
    "koi": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.3, scale=4, ss=0.7, pelvic="abdominal", eye="#1a1a1a", anal="small", w=0.6, W=97),
    "butterfly": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.5, ts=1.5, scale=4, ss=0.6, pelvic="abdominal", eye="#1a1a1a", anal="small", w=0.6, W=99),
    "ogon": dict(pk=0.38, he=0.7, s0=0.36, ped=0.3, tl=0.3, scale=4, ss=1.3, pelvic="abdominal", eye="#1a1a1a", anal="small", w=0.6, W=97),
    "eel": dict(pk=0.2, he=0.6, s0=0.55, ped=0.0, scale=0, anal="eel", eye="#c8b050", er=0.8, mo=0.1, w=0.8, W=147),
    "jack": dict(pk=0.32, he=0.55, s0=0.3, ped=0.12, tl=0.32, ts=1.2, scale=2, ss=0.4, eye="#e0c040", er=1.2, scutes=True),
    "redfish": dict(pk=0.38, he=0.85, s0=0.3, ped=0.32, tl=0.26, scale=3, ss=1.4, mo=0.15, eye="#c89a40"),
    "gar": dict(pk=0.55, he=1.0, s0=0.5, ped=0.36, tl=0.15, ts=0.75, scale=3, ss=1.0, pelvic="abdominal", anal="back", beak=0.26, eye="#c8a030", er=0.9, w=0.8, W=142),
    "oscar": dict(pk=0.38, he=0.7, s0=0.32, ped=0.32, tl=0.24, scale=3, ss=0.6, anal="long", eye="#d84a1a"),
    "pacu": dict(pk=0.4, he=0.55, s0=0.32, ped=0.2, tl=0.26, scale=2, ss=0.5, adipose=True, pelvic="abdominal", eye="#1a1a1a"),
    "carp": dict(pk=0.4, he=0.8, s0=0.28, ped=0.3, tl=0.3, scale=4, ss=1.4, pelvic="abdominal", eye="#c89030", anal="small", longdorsal=True, w=0.55),
    "snakehead": dict(pk=0.25, he=0.65, s0=0.42, ped=0.4, tl=0.2, scale=2, ss=0.6, anal="eel_short", pelvic="thoracic", eye="#c89a30", er=0.9, w=0.7, W=114),
    "snapper": dict(pk=0.4, he=1.0, s0=0.24, ped=0.28, tl=0.28, scale=3, ss=1.1, eye="#c83a2a"),
    "ladyfish": dict(pk=0.45, he=1.1, s0=0.2, ped=0.2, tl=0.34, scale=1, ss=0.4, pelvic="abdominal", eye="#e8e8e0", er=1.2, anal="small", W=113),
    "cichlid": dict(pk=0.38, he=0.8, s0=0.28, ped=0.3, tl=0.24, scale=3, ss=0.9, anal="long", eye="#c83a1a"),
    "pinfish": dict(pk=0.4, he=0.7, s0=0.26, ped=0.24, tl=0.28, scale=2, ss=0.6, eye="#e0c040"),
    "seatrout": dict(pk=0.42, he=1.1, s0=0.2, ped=0.28, tl=0.26, scale=2, ss=0.5, eye="#e0c040"),
    "sheepshead": dict(pk=0.38, he=0.6, s0=0.3, ped=0.24, tl=0.28, scale=2, ss=0.5, eye="#e0c040", sheepteeth=True),
    "barracuda": dict(pk=0.5, he=1.5, s0=0.14, ped=0.32, tl=0.24, scale=1, ss=0.3, mo=-0.15, eye="#e0c040", er=0.9, anal="back", W=141),
    "shark": dict(pk=0.42, he=1.4, s0=0.16, ped=0.26, tl=0.36, ts=1.2, scale=0, mo=-0.5, pelvic="shark", anal="shark", eye="#1a1a1a", er=0.7, w=0.65, W=114),
    "bonnet": dict(pk=0.42, he=1.2, s0=0.2, ped=0.26, tl=0.36, ts=1.2, scale=0, mo=-0.3, pelvic="shark", anal="shark", eye="#1a1a1a", er=0.7, w=0.65, W=114),
    "mahi": dict(pk=0.2, he=0.45, s0=0.55, ped=0.14, tl=0.3, ts=1.2, scale=0, mo=0.35, anal="full", eye="#1a1a1a"),
    "kingfish": dict(pk=0.45, he=1.3, s0=0.14, ped=0.12, tl=0.3, ts=1.3, scale=0, eye="#e0e0d8", w=0.55, W=113),
    "tuna": dict(pk=0.4, he=1.1, s0=0.18, ped=0.08, tl=0.3, ts=1.3, scale=0, eye="#1a1a1a", er=1.1, w=0.65),
    "sailfish": dict(pk=0.38, he=1.2, s0=0.14, ped=0.12, tl=0.3, ts=1.4, scale=0, eye="#1a1a1a", W=113),
    "grouper": dict(pk=0.4, he=0.8, s0=0.3, ped=0.36, tl=0.24, scale=2, ss=0.6, mo=0.0, eye="#c8a040", er=0.8, w=0.55),
    "arowana": dict(pk=0.55, he=0.9, s0=0.32, ped=0.4, tl=0.2, scale=5, ss=1.4, pelvic="abdominal", anal="back", eye="#e0c040", er=1.1, mo=-0.4, W=117),
    "perch": dict(pk=0.4, he=1.0, s0=0.22, ped=0.26, tl=0.28, scale=2, ss=0.6, eye="#c8b040"),
    "crappie": dict(pk=0.45, he=0.85, s0=0.25, ped=0.22, tl=0.28, scale=2, ss=0.5, anal="long", eye="#3a3020", er=1.2),
    "smallmouth": dict(pk=0.4, he=0.9, s0=0.26, ped=0.3, tl=0.28, scale=3, ss=0.9, eye="#c82a1a"),
    "walleye": dict(pk=0.45, he=1.2, s0=0.18, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#d8d8b8", er=1.15, walleye=True),
    "sauger": dict(pk=0.45, he=1.2, s0=0.18, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#e0d8b0", er=1.2, walleye=True),
    "muskie": dict(pk=0.55, he=1.4, s0=0.18, ped=0.36, tl=0.24, scale=1, ss=0.3, pelvic="abdominal", anal="back", eye="#c8a040", mo=-0.1, W=113),
    "whitebass": dict(pk=0.38, he=0.9, s0=0.24, ped=0.24, tl=0.3, scale=2, ss=0.7, eye="#e0c040"),
    "striper": dict(pk=0.42, he=1.0, s0=0.22, ped=0.3, tl=0.28, scale=2, ss=0.6, eye="#c8c0a0"),
    "skipjack": dict(pk=0.42, he=1.0, s0=0.24, ped=0.2, tl=0.32, scale=2, ss=0.8, pelvic="abdominal", eye="#e8e8e0", er=1.2, mo=-0.2, anal="small", W=94),
    "drum": dict(pk=0.38, he=0.6, s0=0.3, ped=0.28, tl=0.26, scale=3, ss=1.0, mo=0.35, eye="#c8c8c0"),
    "flathead": dict(pk=0.3, he=0.5, s0=0.42, ped=0.34, tl=0.26, tshare=0.46, scale=0, adipose=True, anal="mid", eye="#c8a040", er=0.7, mo=0.1, w=0.85, W=101),
    "mirror": dict(pk=0.4, he=0.75, s0=0.28, ped=0.3, tl=0.3, scale=0, pelvic="abdominal", eye="#c89030", anal="small", mirror=True, longdorsal=True, w=0.55, W=101),
    "paddle": dict(pk=0.38, he=1.0, s0=0.3, ped=0.2, tl=0.3, ts=1.1, scale=0, pelvic="abdominal", anal="small", eye="#1a1a1a", er=0.6, W=114),
    "sturgeon": dict(pk=0.38, he=1.2, s0=0.16, ped=0.18, tl=0.3, ts=1.1, scale=0, pelvic="abdominal", anal="small", mo=-0.3, eye="#1a1a1a", er=0.7, scutes5=True, w=0.75, W=114),
    "rainbow": dict(pk=0.42, he=1.0, s0=0.22, ped=0.32, tl=0.26, scale=1, ss=0.4, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040"),
    "brown": dict(pk=0.42, he=1.0, s0=0.24, ped=0.34, tl=0.26, scale=1, ss=0.4, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040"),
    "brook": dict(pk=0.42, he=0.95, s0=0.24, ped=0.34, tl=0.26, scale=0, pelvic="abdominal", adipose=True, anal="small", eye="#c8b040", whiteedge=True),
    "chub": dict(pk=0.4, he=0.9, s0=0.28, ped=0.3, tl=0.28, scale=3, ss=1.0, pelvic="abdominal", anal="small", eye="#c8b040"),
    "pumpkinseed": dict(pk=0.42, he=0.7, s0=0.28, ped=0.24, tl=0.26, scale=2, ss=0.7, eye="#c83a1a"),
    "bluefish": dict(pk=0.42, he=1.0, s0=0.22, ped=0.22, tl=0.3, scale=1, ss=0.4, mo=-0.05, eye="#e0c040", er=1.1),
    "seabass": dict(pk=0.4, he=0.85, s0=0.26, ped=0.3, tl=0.26, scale=3, ss=1.0, eye="#3a3a3a"),
    "scup": dict(pk=0.38, he=0.55, s0=0.3, ped=0.22, tl=0.3, scale=2, ss=0.7, eye="#e0c040"),
    "tautog": dict(pk=0.38, he=0.6, s0=0.36, ped=0.36, tl=0.22, scale=2, ss=0.5, eye="#c8c0a0", lips=True),
    "flounder": dict(pk=0.4, he=0.6, s0=0.3, ped=0.3, tl=0.18, scale=0, dorsalk="fringe", anal="fringe", eye="#e0c060", er=0.8, flounder=True, pelvic="none", w=0.25),
    "mackerel": dict(pk=0.45, he=1.2, s0=0.16, ped=0.1, tl=0.3, ts=1.2, scale=0, eye="#1a1a1a", W=113),
    "cunner": dict(pk=0.4, he=0.75, s0=0.3, ped=0.32, tl=0.22, scale=2, ss=0.8, eye="#c8a040"),
    "dogfish": dict(pk=0.4, he=1.3, s0=0.18, ped=0.22, tl=0.34, ts=1.0, scale=0, mo=-0.5, pelvic="shark", anal="none", eye="#3ac8a0", er=0.9, dogspines=True, w=0.7, W=114),
    "searobin": dict(pk=0.25, he=0.55, s0=0.4, ped=0.3, tl=0.22, scale=0, eye="#c8a040", wings=True, w=0.8),
    "cod": dict(pk=0.38, he=0.9, s0=0.3, ped=0.24, tl=0.26, scale=0, eye="#c8a040", anal="two", three_dorsal=True),
    "pollock": dict(pk=0.4, he=1.0, s0=0.24, ped=0.22, tl=0.3, scale=0, eye="#e0e0d0", anal="two", three_dorsal=True, mo=-0.05),
    "haddock": dict(pk=0.38, he=0.95, s0=0.26, ped=0.22, tl=0.28, scale=0, eye="#e0e0d0", anal="two", three_dorsal=True),
    "albacore": dict(pk=0.4, he=1.1, s0=0.18, ped=0.1, tl=0.3, ts=1.3, scale=0, eye="#1a1a1a", w=0.65),
    "bonito": dict(pk=0.42, he=1.2, s0=0.16, ped=0.1, tl=0.3, ts=1.25, scale=0, eye="#1a1a1a", w=0.6),
    "bluefin": dict(pk=0.4, he=1.0, s0=0.18, ped=0.08, tl=0.3, ts=1.35, scale=0, eye="#1a1a1a", er=1.0, w=0.7),
    "whiteperch": dict(pk=0.4, he=0.9, s0=0.25, ped=0.24, tl=0.28, scale=2, ss=0.8, eye="#c8c0a0"),
    "conger": dict(pk=0.2, he=0.7, s0=0.5, ped=0.0, scale=0, anal="eel", eye="#c8c8b0", er=0.9, w=0.8, W=147),
    "monkfish": dict(pk=0.16, he=0.45, s0=0.75, ped=0.26, tl=0.18, tshare=0.42, scale=0, mo=0.0, eye="#c8a040", er=0.7, lure=True, anal="small", pelvic="none", wings=True, w=1.1, W=95),
    "mummichog": dict(pk=0.38, he=0.7, s0=0.34, ped=0.42, tl=0.22, scale=2, ss=0.8, pelvic="abdominal", anal="back", eye="#c8c050", mo=-0.2, dorsalk="back"),
    "shiner": dict(pk=0.42, he=0.9, s0=0.26, ped=0.24, tl=0.3, scale=3, ss=1.1, pelvic="abdominal", anal="small", eye="#c8b040", mo=-0.15),
    "other": dict(pk=0.4, he=0.9, s0=0.25, ped=0.28, tl=0.28, scale=2, ss=0.8),
}

GOLD = dict(back="#a8741a", side="#e9b23a", belly="#f8e08a", fin="#d8a02a", shine=True)
VARIANTS = {
    "glowing_bass": ("bass", dict(glow="#9cff5a")),
    "isotope": ("bass", dict(glow="#9cff5a", back="#3a5a1a", side="#9ac850")),
    "reactor_goliath": ("grouper", dict(glow="#9cff5a", back="#4a5a2a", side="#8aa04a")),
    "three_eyed_tilapia": ("tilapia", dict(eyes=3)),
    "another_dimension": ("tilapia", dict(eyes=3, back="#4a2a6a", side="#8a5ab0", belly="#d8b8f0", fin="#7a4aa0", glow="#c080ff")),
    "two_headed_catfish": ("catfish", dict(two=True, W=102)),
    "giant_tilapia": ("tilapia", dict(h=0.44)),
    "snook_xl": ("snook", dict(h=0.25)),
    "mr_chairman": ("koi", dict(GOLD, pat="scales", ss=1.4)),
    "golden_arowana": ("arowana", dict(GOLD)),
    "mayors_pet": ("goldfish", dict(GOLD)),
    "key_to_the_city": ("tarpon", dict(GOLD)),
    "volcano_pacu": ("pacu", dict(back="#4a2a2a", side="#a04a2a", belly="#f08a2a", fin="#6a2a1a", glow="#ff7020")),
    "escaped_koi": ("koi", dict(pat="koi_calico")),
    "old_glory": ("tarpon", dict(back="#2a3a6a", belly="#f1f4f5", pat="bigscales")),
    "gray_ghost": ("snook", dict(back="#6a7074", side="#b8bcbe")),
}

DEFAULTS = dict(pk=0.4, he=0.9, s0=0.25, ped=0.28, tshare=0.53, mo=0.0, tl=0.28, ts=1.0, scale=2, ss=0.8,
                pelvic="thoracic", anal="mid", eye="#c8a040", er=1.0, w=0.45, W=93)


class Fish:
    """A fish built in Blender units: body length 1 along x, tail base at x=0, nose at x=1."""

    def __init__(self, key, k, seed=1):
        self.key, self.k, self.seed = key, dict(DEFAULTS, **k), seed
        k = self.k
        self.D = k["h"] * 1.12                 # full body depth
        self.hl = 0.25 * min(1.5, k.get("snout", 1.0)) * (1.15 if k.get("flat") else 1.0)  # head length
        if k.get("lure") or k.get("mahi"):
            self.hl = 0.32
        self.gx = 1 - self.hl                  # gill cover
        self.longbody = 1.0 + (k.get("snout", 1.0) - 1) * 0.12

    # ---- body outline
    def half(self, x):
        k = self.k
        u = 1 - min(1.0, max(0.0, x))
        pk = k["pk"]
        if u < pk:
            f = k["s0"] + (1 - k["s0"]) * math.sin(math.pi / 2 * u / pk) ** k["he"]
        else:
            ped = k["ped"] if k["tail"] != "eel" else 0.02
            f = ped + (1 - ped) * math.cos(math.pi / 2 * (u - pk) / (1 - pk)) ** 1.25
        rn = max(0.02, k["s0"] * self.D * 0.45)
        if u < rn:
            f *= math.sqrt(max(0.0, 1 - (1 - u / rn) ** 2)) * 0.85 + 0.15 * (u / rn)
        return self.D / 2 * f

    def zc(self, x):
        k = self.k
        x = min(1.0, max(0.0, x))
        u = 1 - x
        z = (k["tshare"] - 0.5) * 2 * self.half(x)
        if u < k["pk"]:
            z -= k["mo"] * self.D * 0.3 * (1 - u / k["pk"]) ** 2
        return z

    def top(self, x): return self.zc(x) + self.half(x)
    def bot(self, x): return self.zc(x) - self.half(x)

    def width(self, x):
        k = self.k
        w = k["w"]
        if k.get("flat"):
            w *= 1.0 + 0.5 * max(0, (x - 0.6) / 0.4)
        return self.half(x) * w * (0.6 + 0.4 * math.sin(min(1, x / 0.5) * math.pi / 2))

    def point(self, x, th):
        c, s = math.cos(th), math.sin(th)
        e = 2.0 / 2.4
        cz = math.copysign(abs(c) ** e, c)
        sy = math.copysign(abs(s) ** e, s)
        z = self.zc(x) + self.half(x) * cz
        y = -self.width(x) * sy * (1.0 + 0.15 * max(0.0, -c))
        return y, z

    # ---- materials
    def colors(self):
        k = self.k
        return C.hexf(k["back"]), C.hexf(k["side"]), C.hexf(k["belly"]), C.hexf(k["fin"])

    def paint_skin(self, W=1024, H=512):
        k = self.k
        back, side, belly, fin = self.colors()
        u = (np.arange(W) + 0.5) / W
        v = (np.arange(H) + 0.5) / H
        X = np.broadcast_to(u[None, :], (H, W))
        th = np.broadcast_to((v * 2 * np.pi)[:, None], (H, W))
        c = np.cos(th)
        T = (1 - c) / 2                        # 0 back .. 1 belly
        zc = np.array([self.zc(x) for x in u])[None, :]
        hh = np.array([self.half(x) for x in u])[None, :]
        cz = np.sign(c) * np.abs(c) ** (2 / 2.4)
        Z = zc + hh * cz
        Y = (Z - zc) / np.maximum(hh, 1e-4)   # -1 belly .. 1 back on the flank
        sideflag = np.sign(np.sin(th))
        P, Q = X * 70 + sideflag * 300, Z * 70  # noise coords, about a sprite pixel apart
        sd = self.seed
        n1 = C.fbm(P, Q, 6.0, sd)
        n2 = C.fbm(P, Q, 2.4, sd + 1)
        n3 = C.vnoise_at(P, Q, 0.35, sd + 2)
        tt = T + (n1 - 0.5) * 0.05
        col = C.ramp(tt, [(0.0, C.lighten(back, -0.25)), (0.2, back), (0.42, C.mix(back, side, 0.65)), (0.52, side),
                          (0.64, C.mix(side, belly, 0.5)), (0.78, belly), (1.0, C.lighten(belly, 0.08))])
        flank = np.abs(c) < 0.97
        ink = np.zeros((H, W), bool)
        pat = k.get("pat", "none")
        dark = C.lighten(back, -0.45)
        R = lambda m: m[..., None]

        def darken(m, f):
            col[...] = col * (1 - f * R(m.astype(float)) if m.dtype == bool else 1 - f * R(m))
        # scales
        sz = k["scale"]
        if sz:
            cs = sz * 0.9 / 70
            a = X / cs
            b = Z / cs + 0.5 * np.floor(a)
            fa, fb = a - np.floor(a), b - np.floor(b)
            d = np.hypot(fa - 0.0, (fb - 0.5) * 1.1)
            edge = np.clip(1 - np.abs(d - 0.95) / 0.18, 0, 1) * (T < 0.85)
            darken(edge, 0.09 * k["ss"])
            col[...] += R(np.clip(1 - d / 0.6, 0, 1) * 0.03 * k["ss"])
        if pat == "bigscales" or k.get("mirror"):
            cs = 6.0 / 70
            a = X / cs
            b = Z / cs + 0.5 * np.floor(a)
            fa, fb = a - np.floor(a), b - np.floor(b)
            d = np.hypot(fa, (fb - 0.5) * 1.1)
            edge = (np.abs(d - 0.92) < 0.1) & (T < 0.82)
            if k.get("mirror"):
                edge &= (np.abs(Y - 0.75) < 0.2) | (np.abs(Y - 0.0) < 0.18)
                col[edge] = col[edge] * 0.62
                big = (d < 0.85) & ((np.abs(Y - 0.75) < 0.2) | (np.abs(Y) < 0.18))
                col[big] = col[big] * 1.08
            else:
                col[edge] = col[edge] * 0.72
                col[...] += R(np.clip(1 - d / 0.5, 0, 1) * 0.06 * (T < 0.8))
        # markings
        if pat in ("bars", "bars_faint", "bars3", "bold_bars", "dark_bars"):
            n = {"bars": 6, "bars_faint": 6, "bars3": 3, "bold_bars": 5, "dark_bars": 11}[pat]
            x0, x1 = (0.2, self.gx - 0.02) if pat != "bars3" else (0.25, self.gx - 0.08)
            bx = (X - x0) / (x1 - x0) * n + 0.1 * np.sin(Q * 0.3) + (n1 - 0.5) * 0.4
            wdt = {"bold_bars": 0.36, "bars3": 0.3, "dark_bars": 0.3}.get(pat, 0.26)
            bar = np.clip(1 - np.abs(bx - np.round(bx) - 0.0) / wdt, 0, 1) * (X > x0) * (X < x1)
            lim = {"dark_bars": 0.42, "bold_bars": 0.9}.get(pat, 0.75)
            bar *= np.clip((lim - T) / 0.15, 0, 1) * flank
            st = {"bars_faint": 0.22, "bold_bars": 0.75, "dark_bars": 0.5, "bars3": 0.55}.get(pat, 0.4)
            darken(bar ** 0.7, st)
        if pat == "blotch_line":
            yc = 0.05 + 0.12 * np.sin(Q * 0.0 + X * 30)
            hw = 0.16 + 0.14 * np.abs(np.sin(X * 37 + 0.4)) + (n2 - 0.5) * 0.3
            hw *= np.clip((self.gx - X) / 0.06, 0, 1) ** 0.6
            band = (np.abs(Y - yc) < hw) & (X > 0.02) & flank & (n2 > 0.2)
            col[band] = col[band] * 0.15 + dark * 0.85
            mot = (n2 > 0.62) & (T > 0.1) & (T < 0.4)
            col[mot] *= 0.75
        if pat in ("specks", "spots", "halo", "rainbow", "blue_spots"):
            cell = {"specks": 2.6, "spots": 4.5, "halo": 6.0, "rainbow": 3.4, "blue_spots": 5.0}[pat] / 70
            a, b = X / cell, Z / cell
            ia, ib = np.floor(a), np.floor(b)
            rng = C.vnoise_at(ia * 13.1, ib * 7.7, 1.0, sd + 9)
            ox = C.vnoise_at(ia * 3.3, ib * 5.1, 1.0, sd + 10) * 0.6 + 0.2
            oy = C.vnoise_at(ia * 5.9, ib * 2.3, 1.0, sd + 11) * 0.6 + 0.2
            d = np.hypot(a - ia - ox, b - ib - oy)
            lim = {"specks": 0.2, "spots": 0.28, "halo": 0.24, "rainbow": 0.2, "blue_spots": 0.26}[pat]
            dens = {"specks": 0.45, "spots": 0.5, "halo": 0.55, "rainbow": 0.6, "blue_spots": 0.55}[pat]
            region = (T < (0.62 if pat != "specks" else 0.7)) & flank
            if pat == "rainbow":
                region = (T < 0.55) & flank
            spot = (d < lim) & (rng < dens) & region
            if pat == "halo":
                halo = (d < lim * 1.9) & (rng < dens) & region
                col[halo] = C.mix(col[halo], C.lighten(side, 0.35), 0.6)
                red = spot & (C.vnoise_at(ia * 2.1, ib * 9.3, 1.0, sd + 12) < 0.3)
                col[spot] = dark if k["belly"] != "#e8783a" else C.hexf("#e8d8a0")
                col[red] = C.hexf("#c8402a")
            elif pat == "blue_spots":
                col[spot] = C.hexf("#3a7ad8") if k["back"] != "#4a6a5a" else C.hexf("#e88a3a")
            else:
                col[spot] = col[spot] * 0.25 + dark * 0.75
            if pat == "rainbow":
                band = np.clip(1 - np.abs(Y - 0.0) / 0.28, 0, 1) * flank * (X > 0.05) * (X < 0.92)
                col[...] = C.mix(col, C.hexf("#d87a8a"), R(band * 0.7))
            if pat == "blue_spots" and k["back"] == "#4a6a5a":       # pumpkinseed: blue cheek lines
                for off in (0.0, 0.18):
                    ln = (np.abs(Y - (-0.05 - off) - (X - 1) * 0.6) < 0.05) & (X > self.gx + 0.02) & flank
                    col[ln] = C.hexf("#3a7ad8")
        if pat in ("stripes", "stripes_gold", "gold_stripe", "line"):
            if pat == "stripes":
                rows = [0.65, 0.42, 0.2, -0.02, -0.25] if k["back"] != "#2a3f5a" else [0.82, 0.68, 0.54]
                for yy in rows:
                    off = yy + (0.25 * (X - 0.5) if k["back"] == "#2a3f5a" else 0)
                    ln = (np.abs(Y - off + 0.04 * np.sin(X * 25)) < 0.045) & flank & (X < self.gx)
                    col[ln] = col[ln] * 0.25 + dark * 0.75
            elif pat == "stripes_gold":
                for yy in (0.6, 0.35, 0.1, -0.15, -0.4):
                    ln = (np.abs(Y - yy) < 0.05) & flank & (X < self.gx)
                    col[ln] = C.mix(col[ln], C.hexf("#e0b840"), 0.7)
            elif pat == "gold_stripe":
                ln = (np.abs(Y - 0.18) < 0.09) & flank & (X < self.gx + 0.05)
                col[ln] = C.mix(col[ln], C.hexf("#d8c050"), 0.75)
            else:
                ln = (np.abs(Y - (0.12 + 0.25 * (X - 0.5))) < 0.035) & flank & (X < self.gx) & (X > 0.02)
                col[ln] = col[ln] * 0.3 + dark * 0.7
        if pat == "mottle":
            m = (n2 > 0.56) & (T < 0.75)
            col[m] = col[m] * 0.68
            m2 = (n2 < 0.3) & (T < 0.7)
            col[m2] = C.mix(col[m2], C.lighten(side, 0.3), 0.35)
        if pat in ("koi", "koi_calico"):
            red = C.hexf("#d8401e")
            patch = (C.fbm(P, Q, 9.0, sd + 20) > 0.52) & (T < 0.62)
            col[patch] = red * (0.9 + 0.1 * n3[patch, None])
            if pat == "koi_calico":
                blk = (C.fbm(P, Q, 5.0, sd + 30) > 0.6) & (T < 0.66)
                col[blk] = C.hexf("#1e1e22")
        if pat == "orange_blotch":
            m = (C.fbm(P, Q, 5.0, sd + 40) > 0.55) & (T < 0.8) & flank
            col[m] = C.mix(col[m], C.hexf("#e8702a"), 0.85)
        if pat == "gillspot":
            gs = np.hypot((X - (self.gx - 0.06)) * 70, (Y - 0.35) * hh * 70) < 2.4
            col[gs & flank] = dark
            if k["back"] == "#4a4a52":      # haddock: dark lateral line too
                ln = (np.abs(Y - (0.3 + 0.3 * (X - 0.5))) < 0.04) & flank
                col[ln] = dark
        if k.get("eyespot") or k.get("tailspot"):
            sx = 0.06 if not k.get("eyespot") or k["dorsal"] != "long" else 0.08
            r = np.hypot((X - sx) * 70, (Z - self.zc(sx) - self.half(sx) * 0.2) * 70)
            ring = (r < 3.0) & flank
            col[ring] = C.hexf("#e88a2a") if k.get("eyespot") else col[ring]
            col[(r < 2.0) & flank] = C.hexf("#141414")
        if pat == "scales" and k.get("shine"):
            col[...] += R(np.clip(n3 - 0.6, 0, 1) * 0.5)
        # gill cover line, and the mouth
        gx = self.gx
        ox = gx + 0.05 * ((Y - 0.0) / 0.9) ** 2
        oper = (np.abs(X - ox) < 0.009) & (Y > -0.75) & (Y < 0.65) & flank
        if k["dorsal"] == "shark" or k.get("gills5"):
            oper[:] = False
            for i in range(5):
                gxi = gx - 0.02 - i * 0.022
                sl = (np.abs(X - gxi - 0.03 * Y) < 0.0045) & (np.abs(Y + 0.05) < 0.4) & flank
                col[sl] = col[sl] * 0.5
                ink |= sl
        col[oper] = col[oper] * 0.6
        ink |= oper
        if k.get("ear"):
            ear = np.hypot((X - (gx + 0.02)) / 0.035, (Y - 0.35) / 0.28) < 1
            col[ear & flank] = C.hexf("#12161c")
            ink |= ear & flank
        if k.get("scutes"):
            sc = (np.abs(Y + 0.05) < 0.1) & (X < 0.3) & (X > 0.0) & flank & ((X * 70) % 2 < 1)
            col[sc] = col[sc] * 0.75
        mouth = float(k.get("mouth", 1.0))
        mx0 = 1 - self.hl * 0.32 * mouth
        mz = self.zc(1.0) - (0.0 if not k.get("upmouth") else -0.25)
        # the mouth runs back from the tip along a line just below the snout's middle
        mline = np.zeros((H, W), bool)
        xs_ = np.clip((X - mx0) / (1 - mx0 + 1e-6), 0, 1)
        target = (-0.15 if not k.get("upmouth") else 0.2) - (0.25 * (1 - xs_) if not k.get("upmouth") else -0.3 * (1 - xs_))
        mline = (np.abs(Y - target) < 0.07 + 0.0) & (X > mx0) & flank
        col[mline] = C.hexf("#16191a")
        ink |= mline
        if k.get("teeth") or k.get("sheepteeth"):
            tooth = (Y > target) & (Y < target + 0.12) & (X > mx0 + 0.02) & flank & ((X * 70 * (0.5 if k.get("sheepteeth") else 1)) % 1.4 < 0.7)
            col[tooth] = C.hexf("#f0eee4")
        if k.get("lips"):
            lip = (np.abs(Y - target) < 0.16) & (X > mx0 + 0.01) & flank & ~mline
            col[lip] = col[lip] * 0.85
        col *= (0.95 + 0.1 * n3[..., None])
        if k.get("glow"):
            col = C.mix(col, C.hexf(k["glow"]), 0.25)
        self.ink = ink
        return np.clip(col, 0, 1)

    # ---- the model
    def build(self, scene, root_x=0.0):
        k = self.k
        skin = self.paint_skin()
        ink_img = C.make_image(self.key + "_ink", np.dstack([self.ink.astype(float)] * 3), data=True)
        shine = k.get("shine")
        glow = k.get("glow")
        body_mat = C.tex_material("Skin", C.make_image(self.key + "_skin", skin), rough=0.25 if shine else 0.48,
                                  spec=0.6 if shine else 0.32, metal=0.55 if shine else 0.0,
                                  emit=tuple(C.hexf(glow) ** 2.2) if glow else None, emit_strength=0.35 if glow else 0,
                                  feat=ink_img.name)
        fc = C.hexf(k["fin"])
        stops = [(0.0, C.lighten(fc, -0.3)), (0.55, fc), (1.0, C.lighten(fc, 0.18))]
        self.fin_mat = C.tex_material("Fin", C.make_image(self.key + "_fin", C.fin_texture(
            stops, edge=C.hexf("#f4f2ea") if k.get("whiteedge") else None)), rough=0.3 if shine else 0.55,
            spec=0.5 if shine else 0.25, metal=0.4 if shine else 0.0,
            emit=tuple(C.hexf(glow) ** 2.2) if glow else None, emit_strength=0.25 if glow else 0)
        self.body(body_mat)
        self.fins()
        self.extras()
        self.eyes()

    def body(self, mat):
        NX, NT = 110, 48
        xs = [(0.5 - 0.5 * math.cos(math.pi * i / (NX - 1))) for i in range(NX)]
        verts = []
        for x in xs:
            for j in range(NT + 1):
                y, z = self.point(x, 2 * math.pi * j / NT)
                verts.append((x, y, z))
        tail_c = len(verts); verts.append((-0.004, 0, self.zc(0)))
        nose_c = len(verts); verts.append((1.004, 0, self.zc(1)))
        R = NT + 1
        faces = []
        for i in range(NX - 1):
            for j in range(NT):
                a, b = i * R + j, i * R + j + 1
                faces.append((a, b, b + R, a + R))
        for j in range(NT):
            faces.append((tail_c, j + 1, j))
            q = (NX - 1) * R
            faces.append((q + j, q + j + 1, nose_c))

        def uv(vi):
            if vi == tail_c: return (0.0, 0.5)
            if vi == nose_c: return (1.0, 0.5)
            i, j = divmod(vi, R)
            return (xs[i], 1 - j / NT)
        ob = C.mesh_object("Body", verts, faces, mat, uvs=uv)
        sub = ob.modifiers.new("smooth", "SUBSURF"); sub.levels = 1; sub.render_levels = 1
        self.body_ob = ob
        return ob

    # fins in (x, z): helpers to sit fins on the back and belly
    def fin_soft(self, name, x0, x1, hgt, up=True, lean=0.25, shape="round", y=0.0):
        """A soft fin with its base from x0 (front) to x1 (back), height hgt."""
        prof = self.top if up else self.bot
        sg = 1 if up else -1
        inset = 0.02 * self.D
        base0 = (x0, prof(x0) - sg * inset)
        base1 = (x1, prof(x1) - sg * inset)
        L = x0 - x1
        if shape == "round":
            pts = [base0, (x0 - L * (0.0 + lean * 0.3), prof(x0) + sg * hgt * 0.8), (x0 - L * (0.25 + lean * 0.3), prof(x0) + sg * hgt),
                   (x0 - L * (0.6 + lean * 0.4), prof(x0 - L * 0.6) + sg * hgt * 0.85), (x1 - L * lean * 0.3, prof(x1) + sg * hgt * 0.45), base1]
        elif shape == "tri":
            pts = [base0, (x0 - L * (0.3 + lean), prof(x0) + sg * hgt), (x1 - L * lean * 0.2, prof(x1) + sg * hgt * 0.2), base1]
        elif shape == "low":
            pts = [base0, (x0 - L * 0.04, prof(x0) + sg * hgt * 0.7)]
            for i in range(1, 6):
                xx = x0 - L * i / 6
                pts.append((xx, prof(xx) + sg * hgt * (1 - 0.15 * abs(math.sin(i)))))
            pts += [(x1 - L * 0.04, prof(x1) + sg * hgt * 0.6), base1]
        else:  # sail
            pts = [base0, (x0 - L * 0.08, prof(x0) + sg * hgt * 0.9), (x0 - L * 0.3, prof(x0) + sg * hgt),
                   (x0 - L * 0.6, prof(x0) + sg * hgt * 0.95), (x1 + L * 0.05, prof(x1) + sg * hgt * 0.4), base1]
        pts = C.chaikin(pts, 3 if shape != "tri" else 2)
        root = ((x0 + x1) / 2, prof((x0 + x1) / 2) - sg * self.D * 0.12)
        return C.poly_fin(name, pts, root, self.fin_mat, y=y, thick=0.006)

    def fin_spiny(self, name, x0, x1, hgt, n=9, up=True):
        prof = self.top if up else self.bot
        sg = 1 if up else -1
        base, tips = [], []
        steps = n * 4
        for i in range(steps + 1):
            s = i / steps
            x = x0 - (x0 - x1) * s
            env = hgt * (0.45 + 0.55 * math.sin(min(1.0, (1 - s) * 1.5) * math.pi / 2)) * (1 - 0.35 * s ** 2)
            h = env * (1.0 if i % 4 == 0 else 0.68)
            b = prof(x) - sg * 0.02 * self.D
            base.append((x, b))
            tips.append((x - 0.25 * h * (i % 4 == 0), prof(x) + sg * h))
        return C.strip_fin(name, base, tips, self.fin_mat, thick=0.006)

    def fins(self):
        k = self.k
        D = self.D
        dors = k.get("dorsalk", k["dorsal"])
        if dors == "spiny":
            self.fin_spiny("Dorsal1", 0.68, 0.43, D * 0.32)
            self.fin_soft("Dorsal2", 0.44, 0.2, D * 0.3, lean=0.2)
        elif dors == "small":
            if k.get("longdorsal"):
                self.fin_soft("Dorsal", 0.62, 0.25, D * 0.22, shape="low")
            else:
                self.fin_soft("Dorsal", 0.6, 0.44, D * 0.32, shape="tri", lean=0.25)
        elif dors == "long":
            self.fin_soft("Dorsal", 0.7, 0.14, D * 0.2, shape="low")
        elif dors == "two":
            self.fin_spiny("Dorsal1", 0.66, 0.5, D * 0.3, n=7)
            self.fin_soft("Dorsal2", 0.46, 0.24, D * 0.24, lean=0.15)
        elif dors == "back":
            self.fin_soft("Dorsal", 0.3, 0.1, D * 0.32, lean=0.2)
        elif dors == "eel":
            self.fin_soft("Dorsal", 0.65 if k["tail"] == "eel" else 0.6, -0.02, D * 0.16, shape="low")
        elif dors == "shark":
            self.fin_soft("Dorsal1", 0.62, 0.46, D * 0.55, shape="tri", lean=0.45)
            self.fin_soft("Dorsal2", 0.2, 0.12, D * 0.22, shape="tri", lean=0.4)
            if k.get("dogspines"):
                for xx in (0.63, 0.21):
                    C.poly_fin("Spine", [(xx, self.top(xx) - 0.01), (xx - 0.01, self.top(xx) + D * 0.22), (xx - 0.03, self.top(xx) - 0.01)],
                               (xx - 0.015, self.top(xx)), C.solid_material("SpineMat", "#e8e4d8"), thick=0.008, subdiv=0)
        elif dors == "sail":
            self.fin_soft("Dorsal", 0.8, 0.28, D * 1.5, shape="sail")
            self.fin_soft("Dorsal2", 0.14, 0.1, D * 0.12, shape="tri")
        elif dors == "full":
            self.fin_soft("Dorsal", 0.94, 0.08, D * 0.24, shape="low")
        elif dors == "fringe":
            self.fin_soft("Dorsal", 0.92, 0.05, D * 0.14, shape="low")
        if k.get("three_dorsal"):
            for nm in ("Dorsal1", "Dorsal2"):
                ob = bpy.data.objects.get(nm)
                if ob: bpy.data.objects.remove(ob)
            self.fin_soft("Dorsal1", 0.7, 0.56, D * 0.32, lean=0.2)
            self.fin_soft("Dorsal2", 0.52, 0.36, D * 0.26, lean=0.2)
            self.fin_soft("Dorsal3", 0.32, 0.16, D * 0.24, lean=0.2)
        if k.get("filament"):
            xb = 0.22
            C.tube("Filament", [(xb, 0, self.top(xb) + D * 0.3 * t) if t <= 1 else (xb - 0.05 * (t - 1), 0, self.top(xb) + D * 0.3)
                                for t in (0, 0.5, 1)] + [(xb - 0.09, 0, self.top(xb) + D * 0.22), (xb - 0.16, 0, self.top(xb) + D * 0.05)],
                   0.006, self.fin_mat)
        if k.get("adipose"):
            self.fin_soft("Adipose", 0.17, 0.09, D * 0.1, shape="round", lean=0.1)
        # anal fin
        an = k["anal"]
        if an == "mid": self.fin_soft("Anal", 0.36, 0.2, D * 0.25, up=False, lean=0.25)
        elif an == "long": self.fin_soft("Anal", 0.48, 0.16, D * 0.2, up=False, shape="low")
        elif an == "eel": self.fin_soft("Anal", 0.55, -0.02, D * 0.14, up=False, shape="low")
        elif an == "eel_short": self.fin_soft("Anal", 0.55, 0.1, D * 0.16, up=False, shape="low")
        elif an == "fringe": self.fin_soft("Anal", 0.75, 0.05, D * 0.14, up=False, shape="low")
        elif an == "full": self.fin_soft("Anal", 0.5, 0.08, D * 0.22, up=False, shape="low")
        elif an == "small": self.fin_soft("Anal", 0.26, 0.15, D * 0.22, up=False, shape="tri", lean=0.2)
        elif an == "shark": self.fin_soft("Anal", 0.2, 0.13, D * 0.16, up=False, shape="tri", lean=0.3)
        elif an == "back": self.fin_soft("Anal", 0.28, 0.12, D * 0.26, up=False, lean=0.2)
        elif an == "two":
            self.fin_soft("Anal1", 0.5, 0.36, D * 0.22, up=False, lean=0.2)
            self.fin_soft("Anal2", 0.32, 0.17, D * 0.2, up=False, lean=0.2)
        if k.get("finlets"):
            for i in range(5):
                xx = 0.2 - i * 0.035
                for up in (True, False):
                    prof = self.top if up else self.bot
                    sg = 1 if up else -1
                    C.poly_fin("Finlet", [(xx + 0.01, prof(xx) - sg * 0.004), (xx - 0.006, prof(xx) + sg * D * 0.07), (xx - 0.016, prof(xx) - sg * 0.004)],
                               (xx, prof(xx)), C.solid_material("FinletMat", "#e0c84a" if k["fin"] == "#d8c050" else k["fin"]), thick=0.006, subdiv=0)
        self.tail()
        # pelvic fins, under the belly
        pv = k["pelvic"]
        if pv != "none":
            px = {"thoracic": self.gx - 0.04, "abdominal": 0.5, "shark": 0.34}[pv]
            for side in (-1, 1):
                L = 0.13 if pv != "shark" else 0.1
                pts = C.chaikin([(px + 0.02, self.bot(px + 0.02) + 0.01), (px - L * 0.3, self.bot(px) - D * 0.2),
                                 (px - L, self.bot(px - L) - D * 0.18), (px - L * 0.8, self.bot(px - L * 0.8) + 0.01)], 2)
                C.poly_fin("Pelvic", pts, (px, self.bot(px) + 0.01), self.fin_mat, y=side * self.width(px) * 0.5,
                           thick=0.005, rot=(side * math.radians(-12), 0, 0))
        # pectoral fins on the flanks
        self.pectorals()

    def tail(self):
        k = self.k
        tt = k["tail"]
        if tt == "eel":
            return
        D = self.D
        L = k["tl"] * (1.0 if tt != "veil" else 1.25)
        S = D * 0.55 * k["ts"]
        z0 = self.zc(0)
        pz = self.half(0)
        b = 0.03
        top0, bot0 = (b, z0 + pz * 0.9), (b, z0 - pz * 0.9)
        if tt == "round":
            pts = [top0, (-L * 0.35, z0 + S * 0.85), (-L * 0.8, z0 + S * 0.7), (-L, z0 + S * 0.25), (-L * 1.02, z0), (-L, z0 - S * 0.25),
                   (-L * 0.8, z0 - S * 0.7), (-L * 0.35, z0 - S * 0.85), bot0]
        elif tt == "square":
            pts = [top0, (-L * 0.5, z0 + S * 0.8), (-L * 0.95, z0 + S), (-L, z0 + S * 0.5), (-L * 0.94, z0), (-L, z0 - S * 0.5),
                   (-L * 0.95, z0 - S), (-L * 0.5, z0 - S * 0.8), bot0]
        elif tt == "soft":
            pts = [top0, (-L * 0.5, z0 + S * 0.8), (-L * 0.95, z0 + S), (-L * 1.02, z0 + S * 0.6), (-L * 0.78, z0), (-L * 1.02, z0 - S * 0.6),
                   (-L * 0.95, z0 - S), (-L * 0.5, z0 - S * 0.8), bot0]
        elif tt == "fork":
            pts = [top0, (-L * 0.55, z0 + S * 0.75), (-L, z0 + S * 1.05), (-L * 0.95, z0 + S * 0.75), (-L * 0.55, z0), (-L * 0.95, z0 - S * 0.75),
                   (-L, z0 - S * 1.05), (-L * 0.55, z0 - S * 0.75), bot0]
        elif tt == "deepfork":
            pts = [top0, (-L * 0.55, z0 + S * 0.7), (-L * 1.05, z0 + S * 1.15), (-L * 0.85, z0 + S * 0.8), (-L * 0.3, z0), (-L * 0.85, z0 - S * 0.8),
                   (-L * 1.05, z0 - S * 1.15), (-L * 0.55, z0 - S * 0.7), bot0]
        elif tt == "lunate":
            pts = [(b, z0 + pz * 0.8), (-L * 0.3, z0 + S * 0.35), (-L * 0.85, z0 + S * 1.2), (-L * 0.9, z0 + S * 1.05),
                   (-L * 0.5, z0 + S * 0.3), (-L * 0.42, z0), (-L * 0.5, z0 - S * 0.3), (-L * 0.9, z0 - S * 1.05),
                   (-L * 0.85, z0 - S * 1.2), (-L * 0.3, z0 - S * 0.35), (b, z0 - pz * 0.8)]
        elif tt == "veil":
            pts = [top0, (-L * 0.4, z0 + S * 0.9), (-L * 0.9, z0 + S * 1.1), (-L * 1.1, z0 + S * 0.7), (-L * 0.75, z0 + S * 0.15), (-L * 0.6, z0),
                   (-L * 0.75, z0 - S * 0.15), (-L * 1.1, z0 - S * 0.7), (-L * 0.9, z0 - S * 1.1), (-L * 0.4, z0 - S * 0.9), bot0]
        elif tt == "shark":
            pts = [(b, z0 + pz * 0.8), (-L * 0.4, z0 + S * 0.5), (-L * 1.05, z0 + S * 1.25), (-L * 1.1, z0 + S * 1.1), (-L * 0.75, z0 + S * 0.1),
                   (-L * 0.55, z0 - S * 0.25), (-L * 0.5, z0 - S * 0.55), (-L * 0.3, z0 - S * 0.4), (b, z0 - pz * 0.8)]
        else:
            pts = [top0, (-L, z0 + S), (-L * 0.8, z0), (-L, z0 - S), bot0]
        pts = C.chaikin(pts, 2)
        C.poly_fin("Tail", pts, (0.06, z0), self.fin_mat, thick=0.008)

    def pectorals(self):
        k = self.k
        D = self.D
        px = self.gx - 0.02
        pz = self.zc(px) - self.half(px) * 0.35
        if k.get("wings"):
            L, Hh = 0.32, D * 0.55
            pts = C.chaikin([(px, pz + 0.02), (px - L * 0.4, pz + Hh * 0.6), (px - L, pz + Hh * 0.2), (px - L * 0.9, pz - Hh * 0.4),
                             (px - L * 0.3, pz - Hh * 0.5), (px, pz - 0.02)], 3)
        elif k["dorsal"] == "shark":
            L = 0.2
            pts = [(px + 0.02, pz), (px - L * 0.6, pz - D * 0.55), (px - L, pz - D * 0.5), (px - L * 0.2, pz - 0.02)]
            pz = self.bot(px) + D * 0.1
            pts = [(x, z - (self.zc(px) - self.half(px) * 0.35) + pz) for x, z in pts]
        elif k.get("longfins"):
            L = 0.3
            pts = C.chaikin([(px, pz + 0.02), (px - L * 0.5, pz + D * 0.1), (px - L, pz - D * 0.1), (px - L * 0.8, pz - D * 0.35), (px, pz - 0.03)], 3)
        else:
            L = 0.15 if k["dorsal"] not in ("sail",) else 0.18
            pts = C.chaikin([(px, pz + 0.015), (px - L * 0.45, pz + D * 0.07), (px - L, pz - D * 0.02), (px - L * 0.75, pz - D * 0.12),
                             (px - L * 0.2, pz - D * 0.08), (px, pz - 0.015)], 2)
        mat = self.fin_mat
        for side in (-1, 1):
            y, _ = self.point(px, math.pi * 0.62 if side < 0 else -math.pi * 0.62)
            C.poly_fin("Pectoral", pts, (px, pz), mat, y=y + side * 0.008, thick=0.005,
                       rot=(0, 0, side * math.radians(-14)))

    def extras(self):
        k = self.k
        D = self.D
        whisker_mat = C.solid_material("Whisker", C.lighten(C.hexf(k["back"]), -0.3), rough=0.6, feat=(1, 0, 0))
        nose = (1.0, self.zc(1.0))
        if k.get("whisk"):
            n = 4 if k["dorsal"] != "long" or k.get("pat") == "specks" else 2
            for i in range(n):
                sgn = -1 if i % 2 == 0 else 1
                bz = nose[1] + (0.01 if i < 2 else -0.02)
                ln = (0.28 if i < 2 else 0.16) * (1.0 if k.get("flat") else 0.55)
                pts = [(0.99, sgn * 0.015, bz)]
                for t in (0.3, 0.6, 1.0):
                    pts.append((0.99 - ln * t * 0.6 + ln * 0.15 * t, sgn * (0.02 + 0.05 * t), bz - ln * t * (0.9 if i >= 2 else 0.55)))
                C.tube("Whisker", pts, 0.011, whisker_mat)
        if k.get("barbels"):
            for sgn in (-1, 1):
                bx = 0.9 if k.get("scutes5") else 0.97
                bz = self.bot(bx) + 0.005
                C.tube("Barbel", [(bx, sgn * 0.012, bz), (bx - 0.01, sgn * 0.02, bz - 0.04), (bx - 0.02, sgn * 0.02, bz - 0.07)], 0.005, whisker_mat)
        if k.get("bill"):
            if k.get("paddle") or k.get("key") == "paddle" or self.key == "paddle":
                L = 0.36
                pts = C.chaikin([(0.94, nose[1] + 0.035), (1.0 + L * 0.5, nose[1] + 0.03), (1.0 + L, nose[1] + 0.045), (1.0 + L * 1.05, nose[1] + 0.0),
                                 (1.0 + L, nose[1] - 0.04), (1.0 + L * 0.5, nose[1] - 0.025), (0.94, nose[1] - 0.03)], 2)
                C.poly_fin("Paddle", pts, (0.96, nose[1]), C.solid_material("PaddleMat", C.mix(C.hexf(k["back"]), C.hexf(k["side"]), 0.4), rough=0.5),
                           thick=0.012)
            else:
                L = 0.34
                C.tube("Bill", [(0.97, 0, nose[1] + 0.012), (1.0 + L * 0.5, 0, nose[1] + 0.006), (1.0 + L, 0, nose[1])], 0.018,
                       C.solid_material("BillMat", C.lighten(C.hexf(k["back"]), 0.1), rough=0.4))
        if k.get("beak"):
            L = k["beak"] * 1.6
            bm = C.solid_material("BeakMat", C.mix(C.hexf(k["back"]), C.hexf(k["side"]), 0.5), rough=0.45)
            for dz, rr in ((0.012, 0.022), (-0.014, 0.018)):
                C.tube("Beak", [(0.95, 0, nose[1] + dz), (1.0 + L * 0.5, 0, nose[1] + dz * 0.7), (1.0 + L, 0, nose[1] + dz * 0.2)], rr, bm)
            for i in range(10):
                tx = 1.0 + L * (0.1 + 0.08 * i)
                C.sphere("Tooth", (tx, -0.012, nose[1] - 0.0), 0.005, C.solid_material("ToothMat", "#f0eee0"))
        if k.get("lure"):
            lx = 0.9
            C.tube("Rod", [(lx, 0, self.top(lx)), (lx + 0.04, 0, self.top(lx) + D * 0.3), (lx + 0.12, 0, self.top(lx) + D * 0.36)], 0.008, whisker_mat, taper=False)
            C.sphere("Lure", (lx + 0.13, 0, self.top(lx) + D * 0.33), 0.022, C.solid_material("LureMat", "#e8d890", emit=1.2))
            tm = C.solid_material("ToothMat", "#f0eee0")
            for i in range(9):
                tx = 0.88 + i * 0.013
                C.sphere("Tooth", (tx, -self.width(tx) * 0.95, self.zc(tx) + 0.006), 0.007, tm, scale=(0.5, 0.5, 1.6), seg=8, rings=4)
        if k.get("scutes5"):
            sm = C.solid_material("Scute", C.lighten(C.hexf(k["side"]), 0.2), rough=0.5)
            for i in range(11):
                x = 0.85 - i * 0.075
                C.sphere("Scute", (x, 0, self.top(x) - 0.004), 0.016, sm, scale=(1.4, 0.8, 1.0), seg=8, rings=4)
                C.sphere("Scute", (x, -self.width(x) * 0.95, self.zc(x) + self.half(x) * 0.15), 0.012, sm, scale=(1.4, 0.8, 1.0), seg=8, rings=4)
        if k.get("two"):
            pass  # handled in render_one by duplicating the head end

    def eyes(self):
        k = self.k
        D = self.D
        ex = 1 - self.hl * (0.36 if not k.get("flat") else 0.3)
        if k.get("lure"):
            ex = 0.88
        ez = self.zc(ex) + self.half(ex) * (0.42 if not k.get("flounder") else 0.55)
        r = max(0.022, 0.037 * k["er"] * (0.85 + 0.6 * min(0.5, k["h"]))) * (1.3 if self.key in ("goldfish",) else 1)
        eyes = [(ex, ez)]
        if k.get("flounder"):
            eyes = [(ex, ez), (ex - 0.06, ez - D * 0.08)]
        for i, (x, z) in enumerate(eyes):
            for side in (-1, 1):
                y, _ = self.point(x, math.acos(max(-1, min(1, (z - self.zc(x)) / max(1e-4, self.half(x))))) * (1 if side < 0 else -1))
                y = abs(y) * side * 0.82
                if k.get("flounder") and side > 0:
                    continue
                C.add_eye(x, y, z, r, k["eye"], side=side, walleye=k.get("walleye", False), name="Eye%d%s" % (i, "L" if side < 0 else "R"))
        if k.get("eyes") == 3:
            x = ex - 0.07
            z = self.top(x) - 0.012
            C.add_eye(x, -0.012, z, r * 0.95, k["eye"], side=-1, name="Eye3")


def merged(key, kinds):
    if key in VARIANTS:
        base, ov = VARIANTS[key]
        k = dict(kinds[base], **SHAPE.get(base, {}))
        k.update(ov)
        return base, k
    return key, dict(kinds[key], **SHAPE.get(key, {}))


def render_one(key, kinds, tmp, samples=48, glb_dir=None, views_dir=None):
    base, k = merged(key, kinds)
    scene = C.reset()
    f = Fish(key, k, seed=sum(map(ord, key)))
    f.build(scene)
    if k.get("two"):
        # a second head: copy the front of the fish and swing it up from inside the body
        import bmesh
        from mathutils import Matrix
        px_ = 0.42
        piv = bpy.data.objects.new("Pivot2", None); C.link(piv); piv.location = (px_, 0, f.zc(px_))
        for o in [o for o in scene.objects if o.type in ("MESH", "CURVE")]:
            if o.type == "MESH":
                xs = [(o.matrix_world @ v.co).x for v in o.data.vertices]
                if max(xs) < px_ + 0.05:
                    continue
            elif o.location.x < px_ and not o.name.startswith("Whisker"):
                continue
            c = o.copy(); c.data = o.data.copy()
            C.link(c)
            if o.name == "Body":
                bm = bmesh.new(); bm.from_mesh(c.data)
                bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x < px_ - 0.02], context="VERTS")
                bm.to_mesh(c.data); bm.free()
            elif o.type == "MESH" and min(xs) < px_:
                continue
            c.parent = piv
            c.matrix_parent_inverse = Matrix.Translation(-piv.location)
        piv.rotation_euler = (0, math.radians(-24), 0)
        piv.location.y = 0.03
    C.parent_all()
    C.setup_render(samples)
    sw, sh, ppu = C.side_frame(target_w=f.k["W"])
    rgba, feat = C.render_side(tmp, sw, sh)
    spr = C.pixelate(rgba, feat)
    C.save_png(spr, os.path.join(OUT, key + ".png"))
    if glb_dir:
        os.makedirs(glb_dir, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(glb_dir, key + ".glb"), export_format='GLB', export_apply=True)
    if views_dir:
        os.makedirs(views_dir, exist_ok=True)
        x0, x1, z0, z1, _, _ = C.bbox()
        cx, cz, Lx = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0)
        C.render_view(os.path.join(views_dir, key + "_3q.png"), 700, 400, (cx + Lx * 0.55, -Lx * 1.25, cz + Lx * 0.22),
                      (math.radians(81), 0, math.radians(24)), lens=50)
    return spr


if __name__ == "__main__":
    only, sheet, glb, views, samples = None, None, None, None, 48
    for a in sys.argv[1:]:
        if a.startswith("--only="): only = a[7:].split(",")
        if a.startswith("--sheet="): sheet = a[8:]
        if a.startswith("--glb="): glb = a[6:]
        if a.startswith("--views="): views = a[8:]
        if a.startswith("--samples="): samples = int(a[10:])
    kinds = load_kinds()
    keys = only or (list(kinds) + list(VARIANTS))
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "fish3d")
    done = []
    for key in keys:
        spr = render_one(key, kinds, tmp, samples, glb, views)
        done.append((key, spr))
        print("fish", key, spr.shape[1], "x", spr.shape[0], flush=True)
    if sheet:
        C.contact_sheet(done, sheet)
