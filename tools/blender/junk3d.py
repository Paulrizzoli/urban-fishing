"""Every bit of junk you can reel in, modelled in Blender and rendered to sprites in godot/art/junk/.

usage:  python3 tools/blender/junk3d.py [--only=rubber_duck] [--sheet=contact.png] [--glb=DIR]

Each item is a small scene built from simple parts (boxes, cylinders, tori, lathed shapes,
extruded outlines, tubes) with painted labels where the item has writing on it. Colors follow
the old drawings in godot/scripts/junk_art.gd. The sprite file is the item's name in snake_case
(see KEYS); JunkArt draws it when it exists.
"""
import math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
import bpy, bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'art', 'junk')
FONT = os.path.join(ROOT, 'godot', 'fonts', 'AtkinsonHyperlegible-Bold.ttf')
R = math.radians
_mats = {}


# ---------------------------------------------------------------- building blocks
def M(c, r=0.5, s=0.4, metal=0.0, emit=0.0, feat=None, alpha=1.0):
    key = (c, r, s, metal, emit, str(feat), alpha)
    if key not in _mats or _mats[key].name not in bpy.data.materials:
        _mats[key] = C.solid_material("m_" + c.strip('#'), c, rough=r, spec=s, metal=metal, emit=emit, feat=feat, alpha=alpha)
    return _mats[key]


def METAL(c, r=0.25): return M(c, r=r, s=0.6, metal=0.85)
def INKY(c, r=0.5): return M(c, r=r, feat=(1, 0, 0))


def _fin(ob, m, smooth=True, bevel=0.0, segs=3):
    ob.data.materials.clear(); ob.data.materials.append(m)
    if smooth:
        for p in ob.data.polygons: p.use_smooth = True
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL"); b.width = bevel; b.segments = segs; b.limit_method = "ANGLE"
    return ob


def box(n, size, loc=(0, 0, 0), m=None, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.object; ob.name = n; ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _fin(ob, m, smooth=False, bevel=bevel)


def cyl(n, r, d, loc=(0, 0, 0), m=None, rot=(0, 0, 0), v=40, bevel=0.01):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=d, location=loc, rotation=rot)
    ob = bpy.context.object; ob.name = n
    ob = _fin(ob, m, smooth=True, bevel=bevel)
    ob.data.polygons.foreach_set("use_smooth", [len(p.vertices) == 4 for p in ob.data.polygons])
    return ob


def cone(n, r1, r2, d, loc=(0, 0, 0), m=None, rot=(0, 0, 0), v=40):
    bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r1, radius2=r2, depth=d, location=loc, rotation=rot)
    ob = bpy.context.object; ob.name = n
    return _fin(ob, m)


def tor(n, Rr, r, loc=(0, 0, 0), m=None, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=Rr, minor_radius=r, location=loc, rotation=rot, major_segments=48, minor_segments=16)
    ob = bpy.context.object; ob.name = n; ob.scale = scale
    return _fin(ob, m)


def ball(n, r, loc=(0, 0, 0), m=None, scale=(1, 1, 1), rot=(0, 0, 0)):
    ob = C.sphere(n, loc, r, m, scale=scale, seg=32, rings=16)
    ob.rotation_euler = rot
    return ob


def slab(n, pts, th, m, z=0.0, bevel=0.012, uv_box=None):
    """An outline in the xy plane, extruded up by th (from z). UVs map the outline's box to 0..1."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, y in pts]
    f = bm.faces.new(vs)
    if f.normal.z < 0: f.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, th))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    x0, x1, y0, y1 = uv_box or (min(xs), max(xs), min(ys), max(ys))
    uvl = bm.loops.layers.uv.new("UVMap")
    for fc in bm.faces:
        for lp in fc.loops:
            lp[uvl].uv = ((lp.vert.co.x - x0) / (x1 - x0), (lp.vert.co.y - y0) / (y1 - y0))
    me = bpy.data.meshes.new(n); bm.to_mesh(me); bm.free()
    ob = C.link(bpy.data.objects.new(n, me))
    me.materials.append(m)
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL"); b.width = bevel; b.segments = 3; b.limit_method = "ANGLE"
    return ob


def lathe(n, prof, m, seg=40, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Revolve a (radius, z) profile around the z axis."""
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for r, z in prof:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    P = len(prof)
    for i in range(seg):
        j = (i + 1) % seg
        for k in range(P - 1):
            faces.append((i * P + k, j * P + k, j * P + k + 1, i * P + k + 1))
    ob = C.mesh_object(n, verts, faces, m, uvs=lambda vi: ((vi // P) / seg, (vi % P) / max(1, P - 1)))
    ob.location, ob.rotation_euler = loc, rot
    return ob


def ring_pts(rx, ry, n=48, cx=0.0, cy=0.0, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cy + ry * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n)]


def rrect(w, h, r, n=6, cx=0.0, cy=0.0):
    pts = []
    for qx, qy, a in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for i in range(n + 1):
            t = R(a + 90 * i / n)
            pts.append((cx + qx * (w / 2 - r) + r * math.cos(t), cy + qy * (h / 2 - r) + r * math.sin(t)))
    return pts


def label(w, h, bg, lines, border=None, px=256, noise=0.0, extra=None):
    """A painted label: lines = [(text, height as share of the label, color, y center share)]."""
    W, H = px, max(8, int(px * h / w))
    im = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(im)
    if border:
        bw = max(2, H // 14)
        d.rectangle((bw, bw, W - 1 - bw, H - 1 - bw), outline=border, width=bw)
    for text, size, col, yc in lines:
        f = ImageFont.truetype(FONT, max(6, int(H * size)))
        tw = d.textlength(text, font=f)
        if tw > W * 0.92:
            f = ImageFont.truetype(FONT, max(6, int(H * size * W * 0.92 / tw)))
            tw = d.textlength(text, font=f)
        d.text(((W - tw) / 2, H * yc), text, font=f, fill=col, anchor="lm" if False else None)
    if extra:
        extra(d, W, H)
    a = np.asarray(im).astype(float) / 255
    if noise:
        a *= (1 - noise / 2 + noise * C.vnoise_at(*np.meshgrid(np.arange(W), np.arange(H)), 6.0, 5))[..., None]
    return a


def decal(n, w, h, arr, loc, rot=(0, 0, 0), r=0.5, metal=0.0):
    """A flat textured card facing -y."""
    verts = [(-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2)]
    m = C.tex_material(n + "Mat", C.make_image(n + "Img", arr), rough=r, metal=metal)
    ob = C.mesh_object(n, verts, [(0, 1, 2, 3)], m, smooth=False, uvs=lambda vi: [(0, 0), (1, 0), (1, 1), (0, 1)][vi])
    ob.location, ob.rotation_euler = loc, rot
    return ob


def wire(n, pts, r, color="#9aa6ad", metal=True):
    m = M(color, r=0.3, s=0.6, metal=0.7 if metal else 0.0, feat=(1, 0, 0))
    return C.tube(n, pts, r, m, taper=False)


def weed(x, y, z, length=0.35, lean=1.0):
    pts = [(x + math.sin(i * 1.2) * 0.03 * lean, y, z + i * length / 7) for i in range(8)]
    return C.tube("Weed", pts, 0.022, M("#3f8a4a", r=0.6))


def pose(tilt, spin, roll=0.0):
    root = C.parent_all()
    root.rotation_mode = "ZYX"
    root.rotation_euler = (R(tilt), R(roll), R(spin))
    return root


# ---------------------------------------------------------------- the junk
def soggy_flip_flop():
    foot = [(-0.5 + 1.0 * i / 40, 0.0) for i in range(41)]
    out = []
    for i in range(48):
        a = 2 * math.pi * i / 48
        x = 0.5 * math.cos(a)
        wid = 0.15 + 0.06 * math.cos(a) + 0.03 * math.cos(2 * a)
        out.append((x, wid * math.sin(a) * (1.25 if math.cos(a) > 0 else 1.0)))
    slab("Sole", out, 0.05, M("#2b7ea6", r=0.7))
    inner = [(x * 0.92, y * 0.85) for x, y in out]
    slab("Top", inner, 0.012, M("#5bb5a9", r=0.8), z=0.05, bevel=0.004)
    y_ = M("#f2b134", r=0.5)
    C.tube("Strap", [(0.3, 0.0, 0.06), (0.12, 0.05, 0.13), (-0.06, 0.15, 0.07)], 0.025, y_, taper=False)
    C.tube("Strap", [(0.3, 0.0, 0.06), (0.12, -0.05, 0.13), (-0.06, -0.15, 0.07)], 0.025, y_, taper=False)
    ball("Post", 0.03, (0.3, 0, 0.07), y_)
    weed(0.45, -0.1, 0.05, 0.3)
    pose(58, -18)


def shopping_cart():
    w = M("#9aa6ad", r=0.3, s=0.6, metal=0.7, feat=(1, 0, 0))
    top = [(-0.55, -0.3), (0.5, -0.3), (0.5, 0.3), (-0.55, 0.3)]
    bot = [(-0.42, -0.24), (0.38, -0.24), (0.38, 0.24), (-0.42, 0.24)]
    zt, zb = 0.25, -0.15
    for i in range(4):
        j = (i + 1) % 4
        C.tube("Rim", [(top[i][0], top[i][1], zt), (top[j][0], top[j][1], zt)], 0.014, w, taper=False)
        C.tube("Rim", [(bot[i][0], bot[i][1], zb), (bot[j][0], bot[j][1], zb)], 0.012, w, taper=False)
        C.tube("Post", [(top[i][0], top[i][1], zt), (bot[i][0], bot[i][1], zb)], 0.012, w, taper=False)
    for k in range(1, 9):
        f = k / 9
        for side in (-1, 1):
            xa = top[0][0] + (top[1][0] - top[0][0]) * f
            xb = bot[0][0] + (bot[1][0] - bot[0][0]) * f
            C.tube("Wire", [(xa, side * 0.3, zt), (xb, side * 0.24, zb)], 0.007, w, taper=False)
    for k in range(1, 3):
        f = k / 3
        z = zb + (zt - zb) * f
        C.tube("Wire", [(-0.42 - 0.13 * f, -0.24 - 0.06 * f, z), (0.38 + 0.12 * f, -0.24 - 0.06 * f, z)], 0.007, w, taper=False)
    C.tube("Handle", [(0.5, -0.32, zt + 0.02), (0.62, -0.32, zt + 0.14), (0.62, 0.32, zt + 0.14), (0.5, 0.32, zt + 0.02)], 0.022, M("#e2583e", r=0.4), taper=False)
    for x, y in ((-0.42, -0.2), (0.36, -0.2), (-0.42, 0.2), (0.36, 0.2)):
        C.tube("Leg", [(x, y, zb), (x, y, zb - 0.16)], 0.012, w, taper=False)
        cyl("Wheel", 0.055, 0.035, (x, y, zb - 0.2), M("#22313a", r=0.6), rot=(R(90), 0, 0))
    weed(-0.1, -0.31, zb, 0.4); weed(0.15, -0.31, zb, 0.28)
    pose(14, -28)


def bicycle():
    blk = M("#22313a", r=0.6)
    fr = M("#e2583e", r=0.35, s=0.6)
    spoke = M("#b8bec4", r=0.3, s=0.6, metal=0.8, feat=(1, 0, 0))
    for x in (-0.42, 0.42):
        tor("Tire", 0.27, 0.025, (x, 0, 0), blk, rot=(R(90), 0, 0))
        tor("Rim", 0.245, 0.01, (x, 0, 0), M("#b8bec4", r=0.3, metal=0.8), rot=(R(90), 0, 0))
        for i in range(12):
            a = i * 2 * math.pi / 12
            C.tube("Spoke", [(x, 0, 0), (x + 0.24 * math.cos(a), 0, 0.24 * math.sin(a))], 0.004, spoke, taper=False)
        cyl("Hub", 0.03, 0.06, (x, 0, 0), M("#b8bec4", r=0.3, metal=0.8), rot=(R(90), 0, 0))
    seat_t, head_t, bb = (-0.12, 0, 0.36), (0.26, 0, 0.36), (0.0, 0, 0.0)
    for a, b in ((bb, seat_t), (bb, head_t), (seat_t, head_t), ((-0.42, 0, 0), bb), ((-0.42, 0, 0), seat_t), ((0.42, 0, 0), (0.28, 0, 0.42))):
        C.tube("Frame", [a, b], 0.022, fr, taper=False)
    C.tube("Post", [(-0.12, 0, 0.36), (-0.14, 0, 0.46)], 0.016, blk, taper=False)
    ball("Seat", 0.07, (-0.15, 0, 0.48), blk, scale=(1.4, 0.7, 0.35))
    C.tube("Bars", [(0.28, 0, 0.42), (0.3, 0, 0.5), (0.3, -0.16, 0.5), (0.24, -0.18, 0.5)], 0.016, blk, taper=False)
    C.tube("Bars", [(0.3, 0, 0.5), (0.3, 0.16, 0.5), (0.24, 0.18, 0.5)], 0.016, blk, taper=False)
    cyl("Crank", 0.06, 0.02, (0, -0.03, 0), M("#b8bec4", r=0.3, metal=0.8), rot=(R(90), 0, 0))
    weed(-0.55, -0.05, -0.27, 0.35)
    pose(6, -12)


def dozen_golf_balls():
    green = M("#2f6a3a", r=0.7)
    box("Carton", (0.92, 0.36, 0.1), (0, 0, -0.04), green, bevel=0.015)
    for x0, sg in ((-0.47, 1), (0.47, -1)):
        pass
    U, V = np.meshgrid(np.linspace(0, 1, 128), np.linspace(0, 1, 64))
    dimple = 0.96 + 0.04 * (np.sin(U * 120) * np.sin(V * 120) > 0.2)
    gm = C.tex_material("Golf", C.make_image("golf", np.dstack([C.hexf("#f6f6f2")[k] * dimple for k in range(3)])), rough=0.35, spec=0.5)
    for i in range(6):
        for j in range(2):
            ball("Ball", 0.068, (-0.375 + i * 0.15, -0.075 + j * 0.15, 0.06), gm)
    decal("Label", 0.8, 0.08, label(0.8, 0.08, (47, 106, 58), [("PELICAN POINT", 0.8, (244, 239, 228), 0.12)]), (0, -0.185, -0.04))
    box("Lid", (0.92, 0.04, 0.3), (0, 0.2, 0.12), green, bevel=0.012, rot=(R(-12), 0, 0))
    weed(0.47, -0.15, -0.09, 0.25)
    pose(42, -14)


def cracked_phone():
    box("Phone", (0.36, 0.05, 0.72), (0, 0, 0), M("#22313a", r=0.3, s=0.6), bevel=0.04)

    def cracks(d, W, H):
        pts = [(0.1, 0.12), (0.45, 0.38), (0.32, 0.55), (0.62, 0.78), (0.9, 0.9)]
        d.line([(x * W, y * H) for x, y in pts], fill=(240, 248, 250), width=3)
        d.line([(0.45 * W, 0.38 * H), (0.85 * W, 0.24 * H)], fill=(240, 248, 250), width=2)
        d.line([(0.32 * W, 0.55 * H), (0.08 * W, 0.7 * H)], fill=(240, 248, 250), width=2)
        d.line([(0.62 * W, 0.78 * H), (0.4 * W, 0.95 * H)], fill=(240, 248, 250), width=2)
    scr = label(0.3, 0.6, (70, 104, 122), [], extra=cracks, px=128)
    yy = np.linspace(0, 1, scr.shape[0])[:, None, None]
    scr = scr * (0.85 + 0.3 * (1 - yy))
    decal("Screen", 0.3, 0.6, scr, (0, -0.0262, 0.0), r=0.08)
    ball("Camera", 0.012, (0, -0.026, 0.33), M("#5a6a74", r=0.2))
    weed(0.17, -0.03, -0.36, 0.25)
    pose(10, -24, roll=-16)


def tri_county_hard_hat():
    y_ = M("#f2b134", r=0.35, s=0.5)
    prof = [(0.0, 0.42), (0.12, 0.41), (0.24, 0.37), (0.33, 0.28), (0.38, 0.16), (0.4, 0.04), (0.4, 0.0)]
    dome = lathe("Dome", prof, y_)
    dome.scale = (1.0, 0.82, 1.0)
    tor("Brim", 0.42, 0.04, (0, 0, 0.0), M("#e0a020", r=0.35, s=0.5), scale=(1.1, 0.92, 0.6))
    box("Ridge", (0.07, 0.62, 0.05), (0, 0, 0.41), y_, bevel=0.02)
    decal("Label", 0.34, 0.09, label(0.34, 0.09, (242, 177, 52), [("TRI-COUNTY", 0.78, (32, 36, 40), 0.1)]), (0, -0.335, 0.18))
    weed(0.38, -0.2, -0.02, 0.25)
    pose(14, -14)


def rubber_duck():
    yel = M("#f6d23a", r=0.3, s=0.6)
    ball("Body", 0.32, (0, 0, 0), yel, scale=(1.25, 0.95, 0.78))
    ball("Tail", 0.12, (-0.36, 0, 0.12), yel, scale=(1.2, 0.8, 0.9), rot=(0, R(-30), 0))
    ball("Head", 0.2, (0.24, 0, 0.34), yel)
    ball("Beak", 0.1, (0.43, 0, 0.3), M("#f08a2a", r=0.35, s=0.6), scale=(1.2, 0.9, 0.42))
    ball("Wing", 0.13, (-0.04, -0.27, 0.04), M("#f0c020", r=0.35), scale=(1.4, 0.4, 0.8), rot=(0, R(-14), 0))
    eye = M("#141414", r=0.1, s=0.9, feat=(0, 0, 1))
    for s in (-1, 1):
        ball("Eye", 0.032, (0.33, s * 0.15, 0.4), eye)
    pose(6, -22)


def single_sneaker():
    sole = [(x, y) for x, y in ring_pts(0.5, 0.16, 48)]
    sole = [(x, y * (1.15 if x > 0.1 else 0.95)) for x, y in sole]
    slab("Sole", sole, 0.07, M("#f4efe4", r=0.6))
    n = 40
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -0.46 + 0.92 * s
        hgt = 0.2 * math.sin(math.pi * min(1, (s + 0.06) * 0.95)) ** 0.5
        if s < 0.3: hgt = max(hgt, 0.26)
        path.append((x, 0.07 + hgt * 0.45)); radii.append((0.15 * (1.05 if s > 0.5 else 0.95), hgt * 0.55 + 0.02))
    up = C.loft("Upper", path, radii, M("#e2583e", r=0.55))
    C.sphere("Collar", (-0.3, 0, 0.32), 0.1, M("#22313a", r=0.7), scale=(1.3, 1.0, 0.25))
    for i in range(4):
        x = -0.12 + i * 0.08
        C.tube("Lace", [(x, -0.08, 0.26 - i * 0.025), (x, 0.08, 0.26 - i * 0.025)], 0.012, M("#f4efe4", r=0.6), taper=False)
    C.tube("Swoosh", [(-0.3, -0.155, 0.14), (0.0, -0.162, 0.1), (0.2, -0.155, 0.17)], 0.02, M("#2b7ea6", r=0.5), taper=False)
    weed(0.48, -0.1, 0.05, 0.22)
    pose(12, -20)


def toy_alligator():
    g = M("#5bb04a", r=0.35, s=0.55)
    n = 60
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -0.6 + 1.2 * s
        if s < 0.45: r = 0.03 + 0.09 * (s / 0.45)
        elif s < 0.75: r = 0.12
        else: r = 0.12 * (1 - 0.6 * (s - 0.75) / 0.25)
        path.append((x, 0.04 * math.sin(s * 9))); radii.append((r * 1.1, r * 0.8))
    C.loft("Body", path, radii, g)
    for i in range(12):
        x = -0.4 + i * 0.07
        ball("Bump", 0.03, (x, 0, 0.09 + 0.04 * math.sin((x + 0.6) / 1.2 * 9)), g)
    for lx in (-0.1, 0.25):
        for s in (-1, 1):
            ball("Leg", 0.05, (lx, s * 0.13, -0.08), g, scale=(1.3, 0.8, 0.6))
    eye = M("#141414", r=0.1, feat=(0, 0, 1))
    for s in (-1, 1):
        ball("EyeW", 0.035, (0.4, s * 0.06, 0.1), M("#f2f2e8", r=0.2))
        ball("Eye", 0.018, (0.42, s * 0.085, 0.11), eye)
    C.tube("Mouth", [(0.42, -0.1, 0.0), (0.6, -0.05, -0.0)], 0.008, INKY("#2a4a20"), taper=False)
    pose(20, -15)


def lost_retainer():
    pink = M("#f3a6a0", r=0.25, s=0.6, alpha=1.0)
    out = ring_pts(0.36, 0.3, 40, 0, 0, R(200), R(-20 + 360))
    inn = ring_pts(0.2, 0.14, 40, 0, 0.0, R(-20 + 360), R(200))
    slab("Palate", out + inn, 0.06, pink)
    for i in range(10):
        a = R(205 + i * 13)
        ball("Tooth", 0.04, (0.3 * math.cos(a), 0.25 * math.sin(a) + 0.01, 0.065), M("#f6f6f2", r=0.3), scale=(1, 1, 0.6))
    wire("Wire", [(0.33 * math.cos(R(a)), 0.28 * math.sin(R(a)), 0.07) for a in range(200, 341, 10)], 0.008, "#c8ccd0")
    pose(52, 180 + 10)


def somebodys_car_keys():
    silver = METAL("#b8c1c6")
    tor("Ring", 0.14, 0.014, (0, 0, 0.18), silver, rot=(R(90), 0, 0))
    for ang, col in ((-30, "#c8ccd0"), (20, "#d8b860")):
        k = [(0, -0.03), (0.42, -0.03), (0.44, -0.005), (0.4, 0.0), (0.38, -0.01), (0.34, 0.01), (0.3, -0.005), (0.26, 0.01), (0.2, 0.03), (0, 0.03)]
        key = slab("Key", [(x, y) for x, y in k], 0.015, METAL(col), bevel=0.004)
        head = cyl("KeyHead", 0.07, 0.016, (0, 0, 0.007), METAL(col))
        for o in (key, head):
            o.rotation_euler = (R(90), R(ang), 0)
            o.location = (0.05 * math.cos(R(ang)), 0, 0.06)
    fob = box("Fob", (0.18, 0.06, 0.3), (-0.22, 0, -0.08), M("#22313a", r=0.4, s=0.5), bevel=0.04, rot=(0, R(10), 0))
    decal("FobLogo", 0.12, 0.06, label(0.12, 0.06, (34, 49, 58), [("KIA", 0.9, (255, 255, 255), 0.05)]), (-0.21, -0.031, -0.02), rot=(0, R(10), 0))
    for i in range(2):
        cyl("Btn", 0.03, 0.02, (-0.23 + 0.012 * i, -0.03, -0.12 - 0.08 * i), M("#5a6a74", r=0.4), rot=(R(90), 0, 0))
    C.tube("Link", [(-0.16, 0, 0.06), (-0.05, 0, 0.1)], 0.012, silver, taper=False)
    pose(8, -10)


def florida_man_vhs():
    box("Case", (0.78, 0.12, 0.46), (0, 0, 0), M("#1e1e22", r=0.4, s=0.5), bevel=0.012)
    lab = label(0.62, 0.2, (244, 239, 228), [("FLORIDA MAN'S", 0.32, (30, 30, 34), 0.12), ("GREATEST HITS", 0.32, (226, 88, 62), 0.55)])
    lab[:int(lab.shape[0] * 0.06)] = C.hexf("#f2b134")
    decal("Label", 0.62, 0.2, lab, (0, -0.0605, 0.1))
    box("Window", (0.36, 0.01, 0.1), (0, -0.06, -0.1), M("#3a3a40", r=0.08, s=0.9), bevel=0.0)
    for x in (-0.1, 0.1):
        cyl("Reel", 0.04, 0.01, (x, -0.066, -0.1), M("#2a2a30", r=0.3), rot=(R(90), 0, 0))
    weed(0.36, -0.05, -0.23, 0.22)
    pose(14, -22)


def message_in_a_bottle():
    glass = C.solid_material("Glass", "#5aa070", rough=0.05, spec=0.9, alpha=0.75)
    prof = [(0.0, -0.4), (0.13, -0.4), (0.15, -0.38), (0.15, 0.08), (0.12, 0.16), (0.06, 0.24), (0.05, 0.36), (0.055, 0.38), (0.0, 0.38)]
    lathe("Bottle", prof, glass)
    cyl("Cork", 0.045, 0.1, (0, 0, 0.42), M("#b08a5a", r=0.8))
    cyl("Note", 0.07, 0.4, (0, 0, -0.12), M("#f1e4c8", r=0.8))
    C.tube("Ribbon", [(0.07, 0, -0.12), (0.0, -0.075, -0.12), (-0.07, 0, -0.12)], 0.01, M("#c8322a"), taper=False)
    root = pose(8, -10)
    root.rotation_euler = (R(8), R(-62), R(-10))


def gold_tooth():
    gold = METAL("#e9b23a", r=0.2)
    ball("Crown", 0.28, (0, 0, 0.1), gold, scale=(1.0, 0.85, 0.75))
    for x in (-0.1, 0.1):
        cone("Root", 0.1, 0.035, 0.26, (x * 0.9, 0, -0.14), gold, rot=(0, R(6 if x > 0 else -6), 0))
    for x, y in ((-0.1, -0.07), (0.1, -0.07), (-0.09, 0.08), (0.09, 0.08)):
        ball("Cusp", 0.11, (x, y, 0.24), gold, scale=(1, 1, 0.5))
    pose(18, -20)


def wedding_ring():
    gold = METAL("#e9b23a", r=0.15)
    tor("Band", 0.3, 0.045, (0, 0, 0), gold, rot=(R(90), 0, 0), scale=(1, 1, 1))
    box("Setting", (0.08, 0.08, 0.06), (0, 0, 0.35), gold, bevel=0.01)
    dia = C.solid_material("Diamond", "#cfeaf6", rough=0.02, spec=1.0, metal=0.2)
    cone("Diamond", 0.08, 0.0, 0.09, (0, 0, 0.42), dia, rot=(R(180), 0, 0), v=8)
    cone("Table", 0.08, 0.05, 0.04, (0, 0, 0.485), dia, v=8)
    pose(10, -30)


def lost_kayak_paddle():
    C.tube("Shaft", [(-0.6, 0, 0), (0.6, 0, 0)], 0.026, M("#3d4a52", r=0.4, s=0.5), taper=False)
    blade = [(x * (1.0 if x > 0 else 0.85), y * (1 + 0.25 * x / 0.26)) for x, y in ring_pts(0.26, 0.12, 40)]
    for sg in (-1, 1):
        b = slab("Blade", blade, 0.016, M("#f2b134", r=0.45, s=0.5), bevel=0.006)
        b.location = (sg * 0.78, 0.008, 0)
        b.rotation_euler = (R(90), 0, R(0 if sg > 0 else 180))
        cyl("Grip", 0.028, 0.1, (sg * 0.45, 0, 0), M("#22313a", r=0.8), rot=(0, R(90), 0))
    pose(10, -18, roll=12)


def animatronic_fish_part():
    gold = METAL("#c8964a", r=0.3)
    steel = METAL("#5a6a74", r=0.35)
    n = 40
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        r = 0.2 * math.sin(math.pi * (0.1 + 0.85 * s)) ** 0.7
        path.append((-0.15 + 0.6 * s, 0)); radii.append((r * 0.6, r))
    head = C.loft("Head", path, radii, gold)
    # cut away: the back half is just ribs and gears
    for i in range(4):
        x = -0.2 - i * 0.1
        tor("Rib", 0.16 - i * 0.025, 0.012, (x, 0, 0), steel, rot=(0, R(90), 0), scale=(1, 0.6, 1))
    C.tube("Spine", [(-0.15, 0, 0), (-0.6, 0, 0.02)], 0.02, steel, taper=False)
    for x, z, r in ((-0.28, 0.02, 0.07), (-0.42, -0.04, 0.05)):
        g = cyl("Gear", r, 0.03, (x, -0.02, z), steel, rot=(R(90), 0, 0), v=16)
        for k in range(10):
            a = 2 * math.pi * k / 10
            box("Cog", (0.018, 0.03, 0.018), (x + (r + 0.008) * math.cos(a), -0.02, z + (r + 0.008) * math.sin(a)), steel, bevel=0.0, rot=(0, -a, 0))
    for col, dz in (("#e2583e", 0.05), ("#2b7ea6", -0.03), ("#f2b134", 0.0)):
        C.tube("Wire", [(-0.12, -0.03, dz), (-0.3, -0.08, dz + 0.1), (-0.5, -0.05, dz - 0.05), (-0.62, -0.02, dz - 0.12)], 0.009, M(col, r=0.5, feat=(1, 0, 0)), taper=False)
    ball("Eye", 0.05, (0.3, -0.07, 0.05), M("#ff3a2a", r=0.1, emit=2.5), scale=(1, 0.6, 1))
    C.tube("Jaw", [(0.44, -0.04, -0.04), (0.3, -0.06, -0.09)], 0.012, steel, taper=False)
    pose(6, -10)


def lost_sunglasses():
    frame = M("#1e2a34", r=0.25, s=0.6)
    lens = C.solid_material("Lens", "#2a3a4a", rough=0.05, spec=1.0, metal=0.3)
    for sg in (-1, 1):
        lpts = [(x * (1.0 if x * sg > 0 else 0.9), y) for x, y in ring_pts(0.17, 0.12, 40)]
        f = slab("Rim", [(x + sg * 0.21, y) for x, y in lpts], 0.03, frame, bevel=0.008)
        l = slab("Lens", [(x * 0.86 + sg * 0.21, y * 0.82) for x, y in lpts], 0.034, lens, z=-0.002, bevel=0.0)
        for o in (f, l):
            o.rotation_euler = (R(90), 0, 0)
        C.tube("Temple", [(sg * 0.38, 0.0, 0.04), (sg * 0.4, 0.3, 0.05), (sg * 0.38, 0.45, -0.02)], 0.014, frame, taper=False)
    C.tube("Bridge", [(-0.05, 0, 0.06), (0, 0, 0.08), (0.05, 0, 0.06)], 0.016, frame, taper=False)
    pose(16, -24)


def hoa_violation_notice():
    lines = [("HERON LAKES HOA", 0.07, (40, 44, 48), 0.06), ("VIOLATION", 0.13, (200, 50, 42), 0.18)]

    def body(d, W, H):
        for i in range(7):
            y = H * (0.42 + i * 0.07)
            d.line([(W * 0.12, y), (W * (0.88 - 0.25 * (i == 6)), y)], fill=(120, 124, 128), width=max(2, H // 90))
        d.ellipse((W * 0.62, H * 0.82, W * 0.86, H * 0.95), outline=(200, 50, 42), width=max(3, H // 70))
    paper = label(0.6, 0.78, (246, 242, 230), lines, extra=body, px=300, noise=0.12)
    nx, nz = 16, 20
    verts, faces = [], []
    for j in range(nz + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / nz
            x, z = (u - 0.5) * 0.6, (v - 0.5) * 0.78
            y = 0.05 * math.sin(u * 3.2 + v * 1.4) + 0.03 * math.sin(v * 7 + u * 2) + 0.06 * (u - 0.5) ** 2
            verts.append((x, y, z))
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    m = C.tex_material("Paper", C.make_image("paper", paper), rough=0.85, spec=0.2)
    ob = C.mesh_object("Notice", verts, faces, m, uvs=lambda vi: ((vi % (nx + 1)) / nx, (vi // (nx + 1)) / nz))
    sol = ob.modifiers.new("t", "SOLIDIFY"); sol.thickness = 0.006
    weed(0.28, -0.04, -0.4, 0.22)
    pose(8, -14, roll=-8)


def luggage_tag_cleveland():
    pts = rrect(0.62, 0.34, 0.05)
    tag = slab("Tag", pts, 0.03, M("#2b2b2b", r=0.6), bevel=0.01)
    tag.rotation_euler = (R(90), 0, 0)
    win = label(0.42, 0.24, (244, 239, 228), [("CLEVELAND", 0.32, (34, 36, 40), 0.12), ("CLE", 0.32, (90, 106, 116), 0.55)])
    decal("Card", 0.42, 0.24, win, (0.06, -0.032, 0.0))
    ring = cyl("Eyelet", 0.035, 0.035, (-0.24, -0.0, 0.0), METAL("#c8ccd0"), rot=(R(90), 0, 0))
    C.tube("Strap", [(-0.26, -0.02, 0.0), (-0.42, -0.04, 0.08), (-0.55, -0.04, 0.12), (-0.66, -0.03, 0.06), (-0.62, -0.02, -0.04), (-0.45, -0.02, -0.02)],
           0.02, M("#e2583e", r=0.5), taper=False)
    pose(10, -18, roll=-6)


def bag_of_airline_peanuts():
    n = 24
    verts, faces = [], []
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n, j / n
            x, z = (u - 0.5) * 0.66, (v - 0.5) * 0.44
            puff = (math.sin(math.pi * u) * math.sin(math.pi * v)) ** 0.6
            verts.append((x, -0.11 * puff, z))
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            faces.append((a, a + 1, a + n + 2, a + n + 1))
    lab = label(0.66, 0.44, (43, 126, 166), [("HONEY", 0.2, (242, 177, 52), 0.2), ("ROASTED", 0.2, (255, 255, 255), 0.5)],
                extra=lambda d, W, H: [d.line([(0, H * (0.03 + k * 0.94)), (W, H * (0.03 + k * 0.94))], fill=(210, 220, 230), width=max(3, H // 25)) for k in (0, 1)])
    m = C.tex_material("Foil", C.make_image("foil", lab), rough=0.2, spec=0.7, metal=0.3)
    front = C.mesh_object("Front", verts, faces, m, uvs=lambda vi: ((vi % (n + 1)) / n, (vi // (n + 1)) / n))
    back = C.mesh_object("Back", [(x, -y, z) for x, y, z in verts], [f[::-1] for f in faces], M("#2b7ea6", r=0.25, s=0.7, metal=0.3))
    ball("Peanut", 0.04, (0.36, -0.02, -0.2), M("#d8b070", r=0.7), scale=(1.6, 1, 1))
    ball("Peanut", 0.04, (0.42, -0.03, -0.16), M("#d8b070", r=0.7), scale=(1.6, 1, 1), rot=(0, R(30), 0))
    pose(12, -18, roll=-10)


def lost_valet_ticket():
    t = rrect(0.34, 0.6, 0.02)
    tick = slab("Ticket", t, 0.008, M("#f6c86d", r=0.85), bevel=0.0)
    tick.rotation_euler = (R(90), 0, 0)
    lab = label(0.3, 0.5, (246, 200, 109), [("VALET", 0.16, (34, 36, 40), 0.15), ("No 247", 0.13, (200, 50, 42), 0.5)],
                extra=lambda d, W, H: d.line([(W * 0.08, H * 0.82), (W * 0.92, H * 0.82)], fill=(120, 100, 60), width=3))
    decal("Print", 0.3, 0.5, lab, (0, -0.0085, -0.02))
    cyl("Hole", 0.025, 0.012, (0, -0.002, 0.25), METAL("#c8ccd0"), rot=(R(90), 0, 0))
    C.tube("String", [(0, -0.01, 0.25), (0.06, -0.02, 0.36), (0.16, -0.02, 0.4), (0.24, -0.01, 0.34)], 0.006, INKY("#c8322a"), taper=False)
    pose(8, -16, roll=-12)


def sunken_scooter():
    mint = M("#5bb5a9", r=0.35, s=0.55)
    blk = M("#22313a", r=0.6)
    for x in (-0.42, 0.42):
        tor("Tire", 0.13, 0.05, (x, 0, -0.18), blk, rot=(R(90), 0, 0))
        cyl("Hub", 0.08, 0.08, (x, 0, -0.18), METAL("#9aa6ad"), rot=(R(90), 0, 0))
    n = 40
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -0.55 + 0.8 * s
        h = 0.16 * math.sin(math.pi * min(1, s * 1.05)) ** 0.5
        path.append((x, -0.04 + h * 0.4)); radii.append((0.15, max(0.03, h)))
    C.loft("Body", path, radii, mint)
    box("Floor", (0.28, 0.24, 0.05), (0.25, 0, -0.12), blk, bevel=0.015)
    C.tube("Column", [(0.42, 0, -0.12), (0.46, 0, 0.18), (0.4, 0, 0.4)], 0.07, mint, taper=False)
    C.tube("Bars", [(0.4, -0.22, 0.42), (0.4, 0.22, 0.42)], 0.02, METAL("#9aa6ad"), taper=False)
    ball("Lamp", 0.06, (0.46, -0.0, 0.36), M("#f6e8a0", r=0.1, s=0.9), scale=(0.6, 1, 1))
    ball("Seat", 0.12, (-0.22, 0, 0.2), M("#5a6a74", r=0.7), scale=(1.8, 1.0, 0.4))
    ball("Fender", 0.15, (0.42, 0, -0.06), mint, scale=(1.0, 0.6, 0.5))
    for i in range(6):
        ball("Barnacle", 0.025, (-0.4 + i * 0.12, -0.14, -0.05 + 0.05 * math.sin(i * 2)), M("#d8d4c4", r=0.8))
    weed(-0.1, -0.15, -0.2, 0.35); weed(0.05, -0.15, -0.2, 0.28)
    pose(8, -24)


def tourists_selfie_stick():
    steel = METAL("#b8c1c6", r=0.2)
    for i, (a, b, r) in enumerate(((-0.75, -0.3, 0.03), (-0.3, 0.1, 0.024), (0.1, 0.45, 0.018))):
        C.tube("Tube", [(a, 0, 0), (b, 0, 0)], r, steel, taper=False)
    cyl("Grip", 0.04, 0.25, (-0.62, 0, 0), M("#22313a", r=0.8), rot=(0, R(90), 0))
    C.tube("Strap", [(-0.75, 0, 0), (-0.82, -0.02, -0.12), (-0.75, -0.02, -0.18)], 0.01, M("#f3a6a0"), taper=False)
    box("Clamp", (0.08, 0.06, 0.22), (0.48, 0, 0), M("#22313a", r=0.5), bevel=0.01)
    box("Phone", (0.05, 0.3, 0.52), (0.53, 0, 0), M("#22313a", r=0.3, s=0.6), bevel=0.03)
    box("Back", (0.005, 0.27, 0.48), (0.558, 0, 0), M("#f3a6a0", r=0.4), bevel=0.0)
    pose(14, -28, roll=18)


def cruise_ship_deck_chair():
    wh = M("#f4efe4", r=0.5)
    blue = M("#2b7ea6", r=0.6)
    frame = METAL("#c8ccd0", r=0.3)
    for y in (-0.22, 0.22):
        C.tube("Rail", [(-0.55, y, -0.15), (0.2, y, -0.15), (0.45, y, 0.25)], 0.022, frame, taper=False)
        C.tube("Leg", [(-0.5, y, -0.15), (-0.5, y, -0.32)], 0.02, frame, taper=False)
        C.tube("Leg", [(0.15, y, -0.15), (0.15, y, -0.32)], 0.02, frame, taper=False)
    for i in range(10):
        f = i / 9
        x = -0.55 + 0.75 * f
        box("Slat", (0.06, 0.42, 0.025), (x, 0, -0.13), blue if i % 2 else wh, bevel=0.006)
    for i in range(5):
        f = (i + 0.5) / 5
        box("Back", (0.06, 0.42, 0.025), (0.2 + 0.25 * f, 0, -0.15 + 0.4 * f), blue if i % 2 else wh, bevel=0.006, rot=(0, R(-58), 0))
    decal("Name", 0.4, 0.07, label(0.4, 0.07, (244, 239, 228), [("SS SUNSHINE", 0.8, (43, 126, 166), 0.08)]), (-0.2, -0.235, -0.19))
    weed(-0.55, -0.2, -0.32, 0.3)
    pose(14, -26)


def coin_face(diam_px, base, dark, text=None, motif="cross"):
    W = 256
    im = Image.new("RGB", (W, W), tuple(int(c * 255) for c in C.hexf(base)))
    d = ImageDraw.Draw(im)
    dc = tuple(int(c * 255) for c in C.hexf(dark))
    d.ellipse((10, 10, W - 10, W - 10), outline=dc, width=10)
    if motif == "cross":
        d.rectangle((W * 0.44, W * 0.2, W * 0.56, W * 0.8), fill=dc)
        d.rectangle((W * 0.2, W * 0.44, W * 0.8, W * 0.56), fill=dc)
        for a in range(0, 360, 30):
            x, y = W / 2 + W * 0.38 * math.cos(R(a)), W / 2 + W * 0.38 * math.sin(R(a))
            d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=dc)
    elif motif == "profile":
        d.ellipse((W * 0.3, W * 0.2, W * 0.66, W * 0.62), fill=dc)
        d.rectangle((W * 0.36, W * 0.55, W * 0.6, W * 0.72), fill=dc)
    elif motif == "y":
        d.ellipse((W * 0.36, W * 0.36, W * 0.64, W * 0.64), fill=(30, 26, 20))
    if text:
        f = ImageFont.truetype(FONT, int(W * 0.12))
        tw = d.textlength(text, font=f)
        d.text(((W - tw) / 2, W * 0.7), text, font=f, fill=dc)
    a = np.asarray(im).astype(float) / 255
    return a


def coin(n, r, th, loc, base, dark, rot=(0, 0, 0), text=None, motif="cross", metal=0.45):
    c = cyl(n, r, th, loc, METAL(base, r=0.25), rot=rot, v=48)
    face = coin_face(256, base, dark, text, motif)
    m = C.tex_material(n + "Face", C.make_image(n + "Face", face), rough=0.25, spec=0.6, metal=metal)
    verts, faces = [], []
    seg = 48
    verts.append((0, 0, th / 2 + 0.0005))
    for i in range(seg):
        a = 2 * math.pi * i / seg
        verts.append((r * 0.98 * math.cos(a), r * 0.98 * math.sin(a), th / 2 + 0.0005))
    faces = [(0, i + 1, (i + 1) % seg + 1) for i in range(seg)]
    fo = C.mesh_object(n + "F", verts, faces, m, smooth=False, uvs=lambda vi: (0.5 + verts[vi][0] / (2 * r), 0.5 + verts[vi][1] / (2 * r)))
    fo.parent = c
    return c


def pirate_doubloon():
    c = coin("Doubloon", 0.4, 0.06, (0, 0, 0), "#c8901e", "#7a5410", rot=(R(66), 0, 0))
    pose(0, -12)


def weather_balloon():
    ball("Balloon", 0.38, (0, 0, 0.18), M("#f6f6f2", r=0.25, s=0.5), scale=(1.0, 0.9, 0.78))
    cone("Neck", 0.1, 0.03, 0.12, (0, 0, -0.18), M("#f6f6f2", r=0.3), rot=(R(180), 0, 0))
    C.tube("String", [(0, 0, -0.24), (0.04, 0, -0.34), (0.0, 0, -0.42)], 0.005, INKY("#8a9096"), taper=False)
    box("Sonde", (0.16, 0.1, 0.12), (0.0, 0, -0.48), M("#f2b134", r=0.6), bevel=0.01)
    decal("NWS", 0.36, 0.14, label(0.36, 0.14, (246, 246, 242), [("NWS", 0.8, (43, 126, 166), 0.05)]), (0, -0.345, 0.2))
    pose(6, -10)


def lucky_penny():
    coin("Penny", 0.36, 0.05, (0, 0, 0), "#c8743e", "#7a4020", rot=(R(72), 0, 0), text="1 CENT", motif="profile")
    pose(0, -15)


def executives_rolex():
    gold = METAL("#d8c070", r=0.15)
    cyl("Case", 0.2, 0.08, (0, 0, 0), gold, rot=(R(90), 0, 0))
    tor("Bezel", 0.19, 0.022, (0, -0.04, 0), METAL("#e9c860", r=0.12), rot=(R(90), 0, 0))

    def dial(d, W, H):
        for i in range(12):
            a = R(i * 30)
            x0, y0 = W / 2 + W * 0.36 * math.cos(a), H / 2 + H * 0.36 * math.sin(a)
            d.ellipse((x0 - 6, y0 - 6, x0 + 6, y0 + 6), fill=(233, 200, 96))
        d.line([(W / 2, H / 2), (W / 2 + W * 0.2, H / 2 - H * 0.12)], fill=(233, 200, 96), width=8)
        d.line([(W / 2, H / 2), (W / 2 - W * 0.05, H / 2 - H * 0.32)], fill=(233, 200, 96), width=6)
    face = label(1, 1, (31, 58, 90), [], extra=dial, px=200)
    yy, xx = np.mgrid[0:200, 0:200] / 199
    face[np.hypot(xx - 0.5, yy - 0.5) > 0.5] = C.hexf("#d8c070")
    decal("Dial", 0.3, 0.3, face, (0, -0.0415, 0), r=0.1)
    C.sphere("Glass", (0, -0.03, 0), 0.17, C.solid_material("Crystal", "#d8e8f0", rough=0.0, spec=1.0, alpha=0.15), scale=(1, 0.12, 1))
    cyl("Crown", 0.03, 0.04, (0.22, 0, 0), gold, rot=(0, R(90), 0))
    for sg in (-1, 1):
        for i in range(6):
            z = sg * (0.2 + i * 0.075)
            box("Link", (0.2 - 0.008 * i, 0.04, 0.065), (0, 0.02 + 0.012 * i * i * 0.2, z), gold if i % 2 == 0 else METAL("#b8861a", r=0.2), bevel=0.01, rot=(R(sg * i * 6), 0, 0))
    pose(8, -14)


def fintastic_stock_certificate():
    def body(d, W, H):
        d.rectangle((W * 0.04, H * 0.05, W * 0.96, H * 0.95), outline=(79, 138, 90), width=max(4, H // 30))
        d.rectangle((W * 0.08, H * 0.11, W * 0.92, H * 0.89), outline=(79, 138, 90), width=max(2, H // 80))
        d.ellipse((W * 0.72, H * 0.58, W * 0.88, H * 0.86), fill=(200, 50, 42))
        for i in range(2):
            y = H * (0.66 + i * 0.1)
            d.line([(W * 0.14, y), (W * 0.6, y)], fill=(120, 130, 120), width=max(2, H // 90))
    paper = label(0.9, 0.6, (238, 244, 230), [("FINTASTIC! OUTDOORS", 0.1, (47, 106, 58), 0.2), ("100 SHARES", 0.16, (34, 40, 44), 0.38)],
                  extra=body, px=360, noise=0.08)
    nx, nz = 20, 14
    verts, faces = [], []
    for j in range(nz + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / nz
            verts.append(((u - 0.5) * 0.9, 0.04 * math.sin(u * 4 + 1) + 0.03 * math.sin(v * 5), (v - 0.5) * 0.6))
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    m = C.tex_material("Cert", C.make_image("cert", paper), rough=0.85, spec=0.2)
    ob = C.mesh_object("Cert", verts, faces, m, uvs=lambda vi: ((vi % (nx + 1)) / nx, (vi // (nx + 1)) / nz))
    sol = ob.modifiers.new("t", "SOLIDIFY"); sol.thickness = 0.006
    pose(10, -12, roll=-6)


def wishing_coins():
    rng = np.random.default_rng(3)
    for i in range(9):
        base, dark = [("#c8ccd0", "#8a9096"), ("#c8743e", "#7a4020"), ("#d8c070", "#9a7a30")][i % 3]
        x, y = rng.uniform(-0.3, 0.3), rng.uniform(-0.15, 0.15)
        coin("Coin%d" % i, rng.uniform(0.09, 0.13), 0.025, (x, y, 0.025 * i * 0.5), base, dark,
             rot=(R(rng.uniform(-12, 12)), R(rng.uniform(-12, 12)), 0), motif="profile" if i % 2 else "cross")
    pose(52, -10)


def traffic_cone():
    orange = M("#f2742a", r=0.45, s=0.5)
    wh = M("#f4f6f4", r=0.4, s=0.5)
    box("Base", (0.62, 0.62, 0.06), (0, 0, -0.38), M("#3a3a3a", r=0.7), bevel=0.03)
    prof = [(0.0, -0.35), (0.24, -0.35), (0.04, 0.42), (0.0, 0.42)]
    lathe("Cone", prof, orange, seg=48)
    for z0, z1 in ((-0.1, 0.02), (0.13, 0.22)):
        r0 = 0.24 - (z0 + 0.35) / 0.77 * 0.2 + 0.006
        r1 = 0.24 - (z1 + 0.35) / 0.77 * 0.2 + 0.006
        lathe("Band", [(r0, z0), (r1, z1)], wh, seg=48)
    weed(0.25, -0.25, -0.35, 0.2)
    pose(10, -18)


def wooden_bobbin():
    wood = C.tex_material("Wood", C.make_image("wood", C.ramp((np.sin(np.linspace(0, 40, 256))[None, :] * 0.5 + 0.5) * np.ones((64, 1)),
                                                                [(0, "#a8844e"), (1, "#c8a46a")])), rough=0.7, spec=0.25)
    cyl("Core", 0.12, 0.6, (0, 0, 0), wood, rot=(0, R(90), 0))
    for x in (-0.3, 0.3):
        cyl("Flange", 0.27, 0.05, (x, 0, 0), M("#8a5a35", r=0.65), rot=(0, R(90), 0))
    thread = C.tex_material("Thread", C.make_image("thread", C.ramp((np.sin(np.linspace(0, 400, 256))[:, None] * 0.5 + 0.5) * np.ones((1, 64)),
                                                                    [(0, "#5a1e1e"), (1, "#8a3a32")])), rough=0.8)
    cyl("Wound", 0.2, 0.54, (0, 0, 0), thread, rot=(0, R(90), 0))
    C.tube("Loose", [(0.1, -0.2, 0.0), (0.3, -0.3, -0.15), (0.45, -0.25, -0.3)], 0.008, INKY("#7a2a2a"), taper=False)
    pose(16, -20)


def empty_keg():
    steel = METAL("#b8bec4", r=0.22)
    prof = [(0.0, -0.4), (0.26, -0.4), (0.28, -0.36), (0.28, -0.3), (0.3, -0.25), (0.31, 0.0), (0.3, 0.25), (0.28, 0.3), (0.28, 0.36), (0.26, 0.4), (0.0, 0.4)]
    lathe("Keg", prof, steel, seg=48)
    for z in (-0.18, 0.18):
        tor("Rib", 0.31, 0.012, (0, 0, z), METAL("#7a8288", r=0.3))
    cyl("Valve", 0.06, 0.05, (0, 0, 0.42), METAL("#d8dde0"))
    decal("Label", 0.26, 0.1, label(0.26, 0.1, (216, 221, 224), [("CALDER", 0.75, (90, 58, 42), 0.06)]), (0, -0.312, -0.02))
    weed(0.25, -0.2, -0.4, 0.22)
    pose(10, -18)


def home_run_ball():
    W, H = 256, 128
    U, V = np.meshgrid(np.linspace(0, 1, W), np.linspace(0, 1, H))
    col = np.ones((H, W, 3)) * C.hexf("#f4f0e4")
    seam = 0.5 + 0.28 * np.sin(U * 4 * np.pi)
    d = np.abs(V - seam)
    col[d < 0.012] = C.hexf("#c8402a")
    st = (np.abs(d - 0.035) < 0.012) & ((U * 80) % 1 < 0.5)
    col[st] = C.hexf("#c8402a")
    m = C.tex_material("Leather", C.make_image("leather", col), rough=0.55)
    ob = ball("Ball", 0.34, (0, 0, 0), m)
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new()
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            co = ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv.data[li].uv = ((math.atan2(co.y, co.x) / (2 * math.pi)) % 1, 0.5 + co.z / 0.7)
    pose(20, -30, roll=10)


def foam_finger():
    blue = M("#2b7ea6", r=0.85, s=0.2)
    hand = [(-0.24, -0.5), (0.24, -0.5), (0.26, 0.05), (0.2, 0.18), (0.1, 0.2), (0.08, 0.62), (0.0, 0.7), (-0.08, 0.62), (-0.1, 0.2), (-0.22, 0.16), (-0.27, 0.05)]
    h = slab("Hand", C.chaikin(hand + [hand[0]], 2)[:-1], 0.12, blue, bevel=0.04)
    h.rotation_euler = (R(90), 0, 0); h.location = (0, 0.06, 0)
    for i in range(3):
        ball("Knuckle", 0.07, (-0.14 + i * 0.14 if i < 2 else 0.14, -0.05, 0.12), blue, scale=(1, 0.8, 0.9))
    decal("Num", 0.36, 0.26, label(0.36, 0.26, (43, 126, 166), [("#1", 0.62, (242, 192, 64), 0.05), ("HAWKS", 0.24, (255, 255, 255), 0.68)]), (0, -0.062, -0.22))
    pose(6, -16, roll=-8)


def subway_token():
    c = coin("Token", 0.32, 0.05, (0, 0, 0), "#c8a44a", "#5a4a28", rot=(R(74), 0, 0), text="ONE FARE", motif="y")
    pose(0, -14)


def pizza_box():
    card = C.tex_material("Card", C.make_image("card", C.ramp(C.vnoise_at(*np.meshgrid(np.arange(128), np.arange(128)), 4.0, 2), [(0, "#b89a6a"), (1, "#d0b080")])), rough=0.9)
    box("Base", (0.8, 0.8, 0.08), (0, 0, 0), card, bevel=0.01)
    lid = box("Lid", (0.8, 0.8, 0.02), (0, 0.0, 0.05), card, bevel=0.008)

    def logo(d, W, H):
        d.ellipse((W * 0.15, H * 0.15, W * 0.85, H * 0.85), fill=(192, 57, 43))
    decal("Logo", 0.42, 0.42, label(0.42, 0.42, (200, 168, 122), [("SAL'S", 0.24, (255, 255, 255), 0.36)], extra=None, px=200)
          if False else _sals(), (0, 0, 0.0611), rot=(R(-90), 0, 0))
    weed(0.42, -0.3, -0.04, 0.2)
    pose(48, -14)


def _sals():
    W = 200
    im = Image.new("RGB", (W, W), (200, 168, 122))
    d = ImageDraw.Draw(im)
    d.ellipse((W * 0.12, W * 0.12, W * 0.88, W * 0.88), fill=(192, 57, 43))
    f = ImageFont.truetype(FONT, int(W * 0.24))
    tw = d.textlength("SAL'S", font=f)
    d.text(((W - tw) / 2, W * 0.36), "SAL'S", font=f, fill=(255, 255, 255))
    return np.asarray(im).astype(float) / 255


def lost_earbud():
    wh = M("#f4f4f2", r=0.25, s=0.6)
    ball("Bud", 0.17, (0, 0, 0.12), wh, scale=(1.0, 0.85, 0.9))
    C.tube("Stem", [(0.02, 0, 0.0), (0.04, 0, -0.18), (0.05, 0, -0.32)], 0.05, wh, taper=False)
    ball("Tip", 0.08, (-0.12, -0.08, 0.16), M("#8a9096", r=0.6), scale=(0.6, 1.0, 1.0))
    cyl("Mic", 0.035, 0.02, (0.05, 0, -0.35), M("#8a9096", r=0.4))
    pose(10, -30, roll=-15)


def toll_transponder():
    box("Case", (0.62, 0.12, 0.4), (0, 0, 0), M("#f4f4f2", r=0.45), bevel=0.04)
    lab = label(0.48, 0.26, (90, 42, 138), [("TOLL", 0.5, (255, 255, 255), 0.18)])
    decal("Label", 0.48, 0.26, lab, (0, -0.0605, 0.0))
    box("Strip", (0.5, 0.02, 0.04), (0, -0.06, -0.16), M("#3d8a4a", r=0.5), bevel=0.0)
    for x in (-0.22, 0.22):
        cyl("Mount", 0.05, 0.04, (x, 0.07, 0.12), M("#8a9096", r=0.4), rot=(R(90), 0, 0))
    pose(14, -18)


def hubcap():
    chrome = METAL("#d8dde0", r=0.1)
    prof = [(0.0, 0.08), (0.1, 0.075), (0.18, 0.06), (0.36, 0.03), (0.4, 0.0), (0.42, -0.02)]
    hc = lathe("Cap", prof, chrome, seg=64)
    for i in range(6):
        a = 2 * math.pi * i / 6
        box("Spoke", (0.3, 0.06, 0.03), (0.2 * math.cos(a), 0.2 * math.sin(a), 0.06), METAL("#b8bec4", r=0.2), bevel=0.01, rot=(0, 0, a))
    cyl("Center", 0.08, 0.04, (0, 0, 0.09), METAL("#8a9096", r=0.2))
    pose(72, -10)


def fish_crate():
    teal = M("#3d8a8a", r=0.55)
    W_, D_, H_ = 0.8, 0.5, 0.36
    box("Floor", (W_, D_, 0.03), (0, 0, -H_ / 2), teal, bevel=0.008)
    for sg in (-1, 1):
        for k in range(3):
            z = -H_ / 2 + 0.07 + k * 0.12
            box("SideRail", (W_, 0.03, 0.07), (0, sg * D_ / 2, z), teal, bevel=0.008)
            box("EndRail", (0.03, D_, 0.07), (sg * W_ / 2, 0, z), teal, bevel=0.008)
        for x in (-W_ / 2, 0, W_ / 2):
            box("Post", (0.05, 0.05, H_), (x, sg * D_ / 2, 0), M("#2a6a6a", r=0.55), bevel=0.008)
    decal("Name", 0.6, 0.06, label(0.6, 0.06, (61, 138, 138), [("GANNET FISH PIER", 0.85, (232, 240, 240), 0.06)]), (0, -D_ / 2 - 0.016, -0.04))
    weed(-0.3, -0.26, -0.18, 0.3)
    pose(20, -22)


def rubber_glove():
    gl = M("#e3a23c", r=0.35, s=0.55)
    ball("Palm", 0.22, (0, 0, 0), gl, scale=(1.0, 0.35, 1.1))
    for i, (x, ln, a) in enumerate(((-0.15, 0.24, 18), (-0.05, 0.3, 6), (0.05, 0.31, -2), (0.15, 0.26, -10))):
        ang = R(a)
        C.tube("Finger", [(x, 0, 0.18), (x - math.sin(ang) * ln * 0.5, -0.01, 0.18 + math.cos(ang) * ln * 0.5), (x - math.sin(ang) * ln, 0, 0.18 + math.cos(ang) * ln)], 0.05, gl, taper=False)
        ball("Tip", 0.05, (x - math.sin(ang) * ln, 0, 0.18 + math.cos(ang) * ln), gl)
    C.tube("Thumb", [(0.2, 0, 0.0), (0.32, -0.01, 0.1), (0.4, 0, 0.18)], 0.055, gl, taper=False)
    ball("ThumbTip", 0.055, (0.4, 0, 0.18), gl)
    lathe("Cuff", [(0.2, -0.2), (0.21, -0.4), (0.24, -0.55), (0.25, -0.58)], M("#c8862a", r=0.4), seg=40).scale = (1, 0.45, 1)
    pose(8, -12, roll=10)


def container_twistlock():
    steel = METAL("#8a9096", r=0.35)
    box("Body", (0.34, 0.26, 0.2), (0, 0, 0), M("#6c7178", r=0.4, metal=0.6), bevel=0.03)
    cone("Head", 0.16, 0.06, 0.24, (0, 0, 0.22), steel, v=4, rot=(0, 0, R(45)))
    cone("Foot", 0.16, 0.06, 0.24, (0, 0, -0.22), steel, v=4, rot=(R(180), 0, R(45)))
    box("Flange", (0.42, 0.32, 0.04), (0, 0, 0.0), steel, bevel=0.01)
    C.tube("Handle", [(0.17, -0.02, 0.0), (0.38, -0.08, -0.06), (0.48, -0.1, -0.04)], 0.025, M("#e3a23c", r=0.5), taper=False)
    ball("Rust", 0.06, (-0.12, -0.13, 0.04), M("#8a4a2a", r=0.9), scale=(1.4, 0.2, 1))
    pose(14, -26)


def box_of_left_sneakers():
    lidc = M("#e8e0cc", r=0.75)
    box("Box", (0.8, 0.44, 0.24), (0, 0, 0), M("#d8d0bc", r=0.75), bevel=0.01)
    box("Lid", (0.84, 0.48, 0.05), (0, 0.18, 0.24), lidc, bevel=0.01, rot=(R(-35), 0, 0))
    decal("Label", 0.5, 0.12, label(0.5, 0.12, (232, 224, 204), [("40 × LEFT", 0.8, (192, 57, 43), 0.06)]), (0, -0.221, 0.0))
    for i in range(3):
        x = -0.24 + i * 0.24
        ball("Shoe", 0.13, (x, -0.04 + 0.04 * (i % 2), 0.12), M("#2b7ea6" if i != 1 else "#e2583e", r=0.6), scale=(0.75, 1.4, 0.5), rot=(0, 0, R(10 * (i - 1))))
        ball("ShoeSole", 0.13, (x, -0.04 + 0.04 * (i % 2), 0.08), M("#f4efe4", r=0.6), scale=(0.78, 1.45, 0.2), rot=(0, 0, R(10 * (i - 1))))
    pose(30, -20)


def toilet_seat():
    wh = M("#f4f4f2", r=0.25, s=0.6)
    out = ring_pts(0.4, 0.34, 48)
    out = [(x, y * (1.0 if y > 0 else 1.0) * (1 + 0.15 * (x > 0) * x)) for x, y in out]
    inn = [(x * 0.62 - 0.02, y * 0.55) for x, y in reversed(ring_pts(0.4, 0.34, 48))]
    bm_pts = out
    ring = slab("Seat", out, 0.05, wh, bevel=0.02)
    hole = slab("Hole", inn[::-1], 0.06, M("#5a8a9a", r=0.3), z=-0.005, bevel=0.0)
    hole.hide_render = True
    b = ring.modifiers.new("hole", "BOOLEAN"); b.object = hole; b.operation = "DIFFERENCE"
    lid = slab("Lid", [(x * 0.97, y * 0.97) for x, y in out], 0.04, M("#e8e8e4", r=0.3, s=0.6), bevel=0.015)
    lid.location = (-0.42, 0, 0.05); lid.rotation_euler = (0, R(-100), 0)
    for y in (-0.15, 0.15):
        cyl("Hinge", 0.03, 0.08, (-0.42, y, 0.05), M("#c8ccd0", r=0.3, metal=0.7), rot=(R(90), 0, 0))
    pose(48, -14)


def lost_dentures():
    pink = M("#e87a8a", r=0.3, s=0.6)
    tooth = M("#f8f4e8", r=0.25, s=0.6)
    for zz, sg in ((0.06, 1), (-0.06, -1)):
        out = ring_pts(0.34, 0.28, 30, 0, 0, R(195), R(345))
        inn = ring_pts(0.2, 0.15, 30, 0, 0, R(345), R(195))
        g = slab("Gum", out + inn, 0.08, pink, z=zz - 0.04)
        for i in range(12):
            a = R(198 + i * 12.5)
            box("Tooth", (0.045, 0.06, 0.07), (0.3 * math.cos(a), 0.24 * math.sin(a), zz + sg * 0.06), tooth, bevel=0.015, rot=(0, 0, a + R(90)))
    pose(30, 180 - 10)


def commuters_coffee_mug():
    blue = M("#2b7ea6", r=0.3, s=0.55)
    prof = [(0.0, -0.3), (0.22, -0.3), (0.23, -0.28), (0.23, 0.28), (0.21, 0.3), (0.19, 0.28), (0.19, -0.24), (0.0, -0.24)]
    lathe("Mug", prof, blue, seg=48)
    tor("Handle", 0.13, 0.035, (0.26, 0, 0.0), blue, rot=(R(90), 0, 0), scale=(0.8, 1, 1.1))
    lab = label(0.3, 0.3, (43, 126, 166), [("WORLD'S", 0.17, (255, 255, 255), 0.1), ("OKAYEST", 0.17, (255, 255, 255), 0.38), ("COMMUTER", 0.14, (255, 255, 255), 0.68)])
    decal("Text", 0.28, 0.28, lab, (-0.03, -0.232, 0.0))
    ball("Coffee", 0.19, (0, 0, 0.2), M("#4a2a18", r=0.15, s=0.8), scale=(1, 1, 0.05))
    pose(10, -14)


def ferry_life_ring():
    W, H = 256, 64
    U = np.linspace(0, 1, W)[None, :] * np.ones((H, 1))
    col = np.where(((U * 4) % 1 < 0.5)[..., None], C.hexf("#f2742a"), C.hexf("#f4f4f2"))
    m = C.tex_material("Ring", C.make_image("ring", col), rough=0.5)
    ob = tor("Ring", 0.32, 0.1, (0, 0, 0), m, rot=(R(90), 0, 0))
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new()
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            co = ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv.data[li].uv = ((math.atan2(co.y, co.x) / (2 * math.pi)) % 1, 0.5)
    rope = M("#5a8a9a", r=0.8, feat=(1, 0, 0))
    for i in range(4):
        a0 = R(45 + i * 90 - 20); a1 = R(45 + i * 90 + 20)
        pts = [(0.43 * math.cos(a0 + (a1 - a0) * t / 6), -0.0, 0.43 * math.sin(a0 + (a1 - a0) * t / 6) * 1.0) for t in range(7)]
        C.tube("Rope", pts, 0.015, rope, taper=False)
    pose(12, -14)


def lost_keycard():
    card = slab("Card", rrect(0.66, 0.42, 0.04), 0.012, M("#22313a", r=0.3), bevel=0.0)
    card.rotation_euler = (R(90), 0, 0)
    lab = label(0.62, 0.38, (34, 49, 58), [("SKYLINE", 0.2, (255, 255, 255), 0.18), ("COMMONS", 0.2, (255, 255, 255), 0.42), ("TENANT", 0.12, (143, 196, 220), 0.72)])
    decal("Print", 0.62, 0.38, lab, (0.02, -0.013, 0))
    box("Chip", (0.09, 0.004, 0.07), (-0.2, -0.014, 0.03), METAL("#e3b23c", r=0.2), bevel=0.0)
    pose(10, -22, roll=-12)


def champagne_cork():
    cork = M("#c8a46a", r=0.85)
    lathe("Stem", [(0.0, -0.3), (0.13, -0.3), (0.14, 0.05), (0.0, 0.05)], cork)
    lathe("Top", [(0.0, 0.04), (0.2, 0.04), (0.22, 0.1), (0.2, 0.2), (0.12, 0.25), (0.0, 0.26)], M("#d8b47a", r=0.8))
    cyl("Cap", 0.12, 0.02, (0, 0, 0.265), METAL("#b8bec4", r=0.25))
    wm = M("#b8bec4", r=0.3, metal=0.8, feat=(1, 0, 0))
    for a in range(0, 360, 90):
        C.tube("Cage", [(0.12 * math.cos(R(a)), 0.12 * math.sin(R(a)), 0.26), (0.21 * math.cos(R(a)), 0.21 * math.sin(R(a)), 0.12),
                        (0.15 * math.cos(R(a)), 0.15 * math.sin(R(a)), 0.0)], 0.008, wm, taper=False)
    tor("CageRing", 0.145, 0.008, (0, 0, 0.0), wm)
    root = pose(14, -20)
    root.rotation_euler = (R(14), R(-35), R(-20))


def lobster_trap():
    wood = M("#8a6a40", r=0.8)
    mesh_m = M("#3d8a4a", r=0.5, feat=(1, 0, 0))
    W_, D_, H_ = 0.9, 0.5, 0.42
    for x in (-W_ / 2, W_ / 2):
        for y in (-D_ / 2, D_ / 2):
            box("Post", (0.04, 0.04, H_), (x, y, 0), M("#2f6a3a", r=0.6), bevel=0.006)
    for z in (-H_ / 2, H_ / 2):
        for y in (-D_ / 2, D_ / 2):
            box("Rail", (W_, 0.04, 0.04), (0, y, z), M("#2f6a3a", r=0.6), bevel=0.006)
        for x in (-W_ / 2, W_ / 2):
            box("Rail", (0.04, D_, 0.04), (x, 0, z), M("#2f6a3a", r=0.6), bevel=0.006)
    for k in range(1, 9):
        x = -W_ / 2 + W_ * k / 9
        C.tube("Mesh", [(x, -D_ / 2, -H_ / 2), (x, -D_ / 2, H_ / 2)], 0.006, mesh_m, taper=False)
        C.tube("Mesh", [(x, -D_ / 2, H_ / 2), (x, D_ / 2, H_ / 2)], 0.006, mesh_m, taper=False)
    for k in range(1, 5):
        z = -H_ / 2 + H_ * k / 5
        C.tube("Mesh", [(-W_ / 2, -D_ / 2, z), (W_ / 2, -D_ / 2, z)], 0.006, mesh_m, taper=False)
    C.tube("Funnel", [(-0.3, -D_ / 2, -0.05), (-0.15, -0.05, 0.0)], 0.02, M("#c8a46a", r=0.8), taper=False)
    ball("Buoy", 0.11, (0.55, -0.1, 0.28), M("#c84a3a", r=0.4), scale=(1, 1, 1.4))
    box("Bricks", (0.3, 0.2, 0.06), (0.1, 0, -H_ / 2 + 0.05), M("#a83a2a", r=0.8), bevel=0.01)
    C.tube("Line", [(0.5, -0.1, 0.18), (0.4, -0.08, 0.1), (0.35, -0.05, H_ / 2)], 0.008, INKY("#d8c8a0"), taper=False)
    pose(16, -24)


JUNK = {
    "Soggy Flip-Flop": soggy_flip_flop, "Shopping Cart": shopping_cart, "Bicycle": bicycle, "Dozen Golf Balls": dozen_golf_balls,
    "Cracked Phone": cracked_phone, "Tri-County Hard Hat": tri_county_hard_hat, "Rubber Duck": rubber_duck, "Single Sneaker": single_sneaker,
    "Toy Alligator": toy_alligator, "Lost Retainer": lost_retainer, "Somebody's Car Keys": somebodys_car_keys,
    "\"Florida Man's Greatest Hits\" VHS": florida_man_vhs, "Message in a Bottle": message_in_a_bottle, "Gold Tooth": gold_tooth,
    "Wedding Ring": wedding_ring, "Lost Kayak Paddle": lost_kayak_paddle, "Animatronic Fish Part": animatronic_fish_part,
    "Lost Sunglasses": lost_sunglasses, "HOA Violation Notice": hoa_violation_notice, "Luggage Tag (Cleveland)": luggage_tag_cleveland,
    "Bag of Airline Peanuts": bag_of_airline_peanuts, "Lost Valet Ticket": lost_valet_ticket, "Sunken Scooter": sunken_scooter,
    "Tourist's Selfie Stick": tourists_selfie_stick, "Cruise Ship Deck Chair": cruise_ship_deck_chair, "Pirate Doubloon": pirate_doubloon,
    "Weather Balloon": weather_balloon, "Lucky Penny": lucky_penny, "Executive's Rolex": executives_rolex,
    "Fintastic Stock Certificate": fintastic_stock_certificate, "Wishing Coins": wishing_coins,
    "Traffic Cone": traffic_cone, "Wooden Bobbin": wooden_bobbin, "Empty Keg": empty_keg, "Home Run Ball": home_run_ball, "Foam Finger": foam_finger,
    "Subway Token": subway_token, "Pizza Box": pizza_box, "Lost Earbud": lost_earbud, "Toll Transponder": toll_transponder, "Hubcap": hubcap,
    "Fish Crate": fish_crate, "Rubber Glove": rubber_glove, "Container Twistlock": container_twistlock, "Box of Left Sneakers": box_of_left_sneakers,
    "Toilet Seat": toilet_seat, "Lost Dentures": lost_dentures, "Commuter's Coffee Mug": commuters_coffee_mug, "Ferry Life Ring": ferry_life_ring,
    "Lost Keycard": lost_keycard, "Champagne Cork": champagne_cork, "Lobster Trap": lobster_trap,
}


def key_of(name):
    """The sprite file name for a bit of junk: lower case, words joined by underscores."""
    return re.sub(r'_+', '_', re.sub(r'[^a-z0-9]+', '_', name.lower())).strip('_')


def render_one(name, tmp, samples=48, glb_dir=None, box_w=80, box_h=56):
    C.reset()
    _mats.clear()
    JUNK[name]()
    C.setup_render(samples)
    sw, sh, ppu = C.side_frame(target_w=box_w, max_h=box_h)
    rgba, feat = C.render_side(tmp, sw, sh)
    spr = C.pixelate(rgba, feat, ncol=24)
    key = key_of(name)
    C.save_png(spr, os.path.join(OUT, key + ".png"))
    if glb_dir:
        os.makedirs(glb_dir, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(glb_dir, key + ".glb"), export_format='GLB', export_apply=True)
    return key, spr


if __name__ == "__main__":
    only, sheet, glb, samples = None, None, None, 48
    for a in sys.argv[1:]:
        if a.startswith("--only="): only = a[7:].split(",")
        if a.startswith("--sheet="): sheet = a[8:]
        if a.startswith("--glb="): glb = a[6:]
        if a.startswith("--samples="): samples = int(a[10:])
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "junk3d")
    names = [n for n in JUNK if not only or key_of(n) in only]
    done = []
    for n in names:
        key, spr = render_one(n, tmp, samples, glb)
        done.append((key, spr))
        print("junk", key, spr.shape[1], "x", spr.shape[0], flush=True)
    if sheet:
        C.contact_sheet(done, sheet, cols=6, cw=200, ch=130, scale=2)
