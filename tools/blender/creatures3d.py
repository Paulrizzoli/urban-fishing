"""The catches that aren't fish, modelled in Blender and rendered to sprites in godot/art/fish/:
blue crab, stingray, Burmese python, baby gator, sewer rat and the glow-in-the-dark shrimp.

usage:  python3 tools/blender/creatures3d.py [--only=blue_crab] [--sheet=contact.png] [--glb=DIR]
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'art', 'fish')


def grid(W, H):
    return np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)


def tex(name, arr, **kw):
    return C.tex_material(name, C.make_image(name + "_img", arr), **kw)


def flank_t(V):
    """0 on the back .. 1 on the belly, from the loft's v (0 top, 0.5 bottom)."""
    return (1 - np.cos(V * 2 * np.pi)) / 2


# ---------------------------------------------------------------- blue crab (seen from above)
def blue_crab():
    U, V = grid(256, 256)
    n = C.fbm(U * 60, V * 60, 4.0, 3)
    shell = C.ramp(np.hypot(U - 0.5, V - 0.5) * 2 + (n - 0.5) * 0.3, [(0, "#5a86a8"), (0.6, "#3e6890"), (1, "#2c4c6c")])
    shell *= (0.9 + 0.2 * C.fbm(U * 90, V * 90, 2.0, 4))[..., None]
    sm = tex("Shell", shell, rough=0.35, spec=0.5)
    blue = C.solid_material("Leg", "#3c78c8", rough=0.35, spec=0.5)
    red = C.solid_material("Claw", "#d84a2a", rough=0.3, spec=0.6)
    white = C.solid_material("Belly", "#e8eef0", rough=0.5)
    # carapace: a wide oval with a spine at each side
    body = C.sphere("Carapace", (0, 0, 0), 0.5, sm, scale=(1.05, 0.55, 0.24), seg=48, rings=24)
    uv = body.data.uv_layers.active or body.data.uv_layers.new()
    for poly in body.data.polygons:
        for li in poly.loop_indices:
            co = body.data.vertices[body.data.loops[li].vertex_index].co
            uv.data[li].uv = (0.5 + co.x, 0.5 + co.y)
    C.sphere("Under", (0, 0, -0.04), 0.46, white, scale=(0.95, 0.44, 0.16), seg=32, rings=16)
    for s in (-1, 1):
        C.tube("Spine", [(s * 0.45, 0.0, 0), (s * 0.62, 0.02, 0.0), (s * 0.72, 0.03, 0.0)], 0.035, sm)
        # front teeth on the shell edge
        for i in range(4):
            a = 0.25 + i * 0.12
            C.tube("Tooth", [(s * 0.45 * math.cos(a), 0.22 * math.sin(a) + 0.02, 0), (s * 0.5 * math.cos(a), 0.27 * math.sin(a) + 0.04, 0)], 0.018, sm)
        # claws, held up in front
        C.tube("Arm", [(s * 0.3, 0.18, 0.02), (s * 0.5, 0.36, 0.06), (s * 0.44, 0.56, 0.08)], 0.075, blue, taper=False)
        C.sphere("Hand", (s * 0.38, 0.68, 0.09), 0.14, blue, scale=(0.8, 1.0, 0.6))
        C.tube("Pincer", [(s * 0.32, 0.8, 0.09), (s * 0.24, 0.95, 0.1), (s * 0.15, 0.98, 0.1)], 0.045, red)
        C.tube("Pincer", [(s * 0.42, 0.82, 0.09), (s * 0.36, 0.96, 0.1), (s * 0.27, 1.02, 0.1)], 0.04, red)
        # walking legs, and the paddle legs at the back
        for i in range(3):
            y = 0.1 - i * 0.12
            C.tube("Leg", [(s * 0.4, y, 0), (s * 0.68, y + 0.05, 0.05), (s * 0.88, y - 0.06, -0.02), (s * 0.98, y - 0.16, -0.06)], 0.05, blue)
        C.tube("Leg", [(s * 0.32, -0.22, 0), (s * 0.56, -0.3, 0.03), (s * 0.7, -0.42, 0)], 0.05, blue, taper=False)
        C.sphere("Paddle", (s * 0.76, -0.5, 0.0), 0.1, blue, scale=(0.7, 1.0, 0.25))
        # eyes on short stalks
        C.tube("Stalk", [(s * 0.08, 0.22, 0.05), (s * 0.1, 0.27, 0.1)], 0.02, sm, taper=False)
        C.sphere("Eye", (s * 0.1, 0.28, 0.12), 0.03, C.solid_material("CrabEye", "#101010", rough=0.1, feat=(0, 0, 1)))
    root = C.parent_all()
    root.rotation_euler = (math.radians(68), 0, 0)
    return dict(W=60)


# ---------------------------------------------------------------- stingray (seen from above)
def stingray():
    U, V = grid(256, 256)
    n = C.fbm(U * 50, V * 50, 4.0, 7)
    col = C.ramp(n, [(0, "#5a4a36"), (0.5, "#7a6648"), (1, "#9a845e")])
    col *= (0.92 + 0.14 * C.vnoise_at(U * 200, V * 200, 1.0, 8))[..., None]
    m = tex("RaySkin", col, rough=0.55, spec=0.3)
    # the disc: a diamond with rounded wings, thick in the middle
    nr, nt = 40, 64
    verts, faces = [], []
    for i in range(nr + 1):
        r = i / nr
        for j in range(nt):
            a = 2 * math.pi * j / nt
            ca, sa = math.cos(a), math.sin(a)
            p = 1.25
            rad = 0.5 / (abs(ca) ** p + abs(sa) ** p) ** (1 / p) * (1.1 if ca > 0 else 0.85)
            x, y = rad * r * ca, rad * r * sa * 1.35
            z = 0.09 * (1 - r ** 2) ** 0.8 + 0.02 * (1 - r)
            verts.append((x, y, z))
    for i in range(nr):
        for j in range(nt):
            a, b = i * nt + j, i * nt + (j + 1) % nt
            faces.append((a, b, b + nt, a + nt))
    top = C.mesh_object("Disc", verts, faces, m, uvs=lambda vi: (0.5 + verts[vi][0], 0.5 + verts[vi][1]))
    bot = C.mesh_object("DiscUnder", [(x, y, -z * 0.4) for x, y, z in verts], [f[::-1] for f in faces], C.solid_material("RayBelly", "#e8e2d0"))
    C.tube("Tail", [(-0.4, 0, 0.02), (-0.6, 0.0, 0.02), (-0.8, 0.02, 0.02), (-0.95, 0.06, 0.02)], 0.03, C.solid_material("RayTail", "#4a3c2c"))
    C.tube("Barb", [(-0.62, 0.01, 0.04), (-0.74, 0.03, 0.05)], 0.012, C.solid_material("RayBarb", "#d8d0b8"))
    eye = C.solid_material("RayEye", "#1a1814", rough=0.1, feat=(0, 0, 1))
    for s in (-1, 1):
        C.sphere("EyeBump", (0.18, s * 0.07, 0.09), 0.035, m, scale=(1, 1, 0.6))
        C.sphere("Eye", (0.19, s * 0.07, 0.11), 0.018, eye)
        C.sphere("Spiracle", (0.12, s * 0.08, 0.095), 0.014, C.solid_material("Spir", "#2a2218"))
    root = C.parent_all()
    root.rotation_euler = (math.radians(70), 0, 0)
    return dict(W=53, max_h=58)


# ---------------------------------------------------------------- Burmese python (side)
def burmese_python():
    n = 120
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -1.6 + 3.2 * s
        z = 0.16 * math.sin(s * 2 * math.pi * 1.5 + 0.6) * (0.4 + 0.6 * math.sin(s * math.pi))
        r = 0.1 * (min(1, s / 0.35) ** 0.6) * (1 - 0.25 * max(0, (s - 0.88) / 0.12))
        if s > 0.93:   # head: wider, flatter, then the snout
            k = (s - 0.93) / 0.07
            r = 0.095 * (1.1 - 0.55 * k ** 1.8)
        r = max(r, 0.006)
        path.append((x, z)); radii.append((r * 0.95, r))
    W, H = 2048, 256
    U, V = grid(W, H)
    t = flank_t(V)
    col = C.ramp(t, [(0, "#6a5430"), (0.35, "#a08048"), (0.7, "#c8b07a"), (1, "#e2d6b0")])
    # big dark saddles outlined in black, the python's pattern
    nn = C.fbm(U * 400, V * 40, 6.0, 11)
    blot = (np.sin(U * 2 * np.pi * 26 + nn * 4) > 0.15) & (t < 0.72)
    col[blot] = C.hexf("#4a3418") * (0.9 + 0.2 * nn[blot, None])
    edge = (np.abs(np.sin(U * 2 * np.pi * 26 + nn * 4) - 0.15) < 0.12) & (t < 0.72)
    col[edge] = C.hexf("#1e160c")
    head = U > 0.93
    col[head] = C.ramp(t[head], [(0, "#5a4424"), (0.5, "#8a6c3c"), (1, "#d8ccaa")])
    arrow = head & (np.abs(t - 0.1) < 0.12) & (U > 0.95)
    col[arrow] = C.hexf("#3a2a14")
    col *= (0.92 + 0.12 * C.vnoise_at(U * 1500, V * 120, 1.0, 12))[..., None]
    sm = tex("PySkin", col, rough=0.3, spec=0.55)
    C.loft("Body", path, radii, sm, nt=20)
    x1, z1 = path[-1]
    hx = x1 - 0.12
    eye = C.add_eye(hx + 0.05, -0.075, path[-8][1] + 0.045, 0.024, "#c89a30", name="PyEye")
    C.tube("Tongue", [(x1, 0, z1 - 0.01), (x1 + 0.06, 0, z1 - 0.012), (x1 + 0.09, 0, z1 + 0.0)], 0.006, C.solid_material("Tongue", "#d8303a", feat=(1, 0, 0)), taper=False)
    C.parent_all()
    return dict(W=166)


# ---------------------------------------------------------------- baby gator (side, from a little above)
def baby_gator():
    n = 100
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -1.3 + 2.6 * s
        z = 0.0
        if s < 0.5:     # tail: tall and thin, tapering to a point
            k = s / 0.5
            ry, rz = 0.02 + 0.08 * k ** 1.2, 0.03 + 0.08 * k ** 1.0
        elif s < 0.78:  # body
            k = (s - 0.5) / 0.28
            ry, rz = 0.1 + 0.05 * math.sin(k * math.pi), 0.11 + 0.01 * math.sin(k * math.pi)
        elif s < 0.84:  # neck and head
            ry, rz = 0.1, 0.085
        else:           # long flat snout
            k = (s - 0.84) / 0.16
            ry, rz = 0.1 * (1 - 0.55 * k), 0.07 * (1 - 0.6 * k ** 1.5)
            z = -0.02 * k
        path.append((x, z)); radii.append((ry, rz))
    W, H = 1024, 256
    U, V = grid(W, H)
    t = flank_t(V)
    col = C.ramp(t, [(0, "#2a3418"), (0.3, "#3e4a22"), (0.55, "#5e6a34"), (0.75, "#c8c08a"), (1, "#e2dcb0")])
    band = (np.sin(U * 2 * np.pi * 14) > 0.55) & (t < 0.62) & (U < 0.8)
    col[band] = C.mix(col[band], C.hexf("#d8c860"), 0.55)      # a baby's yellow crossbands
    scute = ((U * 160) % 1 < 0.5) & ((V * 40) % 1 < 0.5) & (t < 0.6)
    col[scute] *= 0.86
    mouth = (U > 0.85) & (np.abs(t - 0.62) < 0.03)
    col[mouth] = C.hexf("#1a1c10")
    teeth = (U > 0.86) & (t > 0.6) & (t < 0.66) & ((U * 300) % 1 < 0.4)
    col[teeth] = C.hexf("#f0ecd8")
    gm = tex("GatorSkin", col, rough=0.5, spec=0.35)
    gm["feat"] = C.make_image("gator_ink", np.dstack([mouth.astype(float)] * 3), data=True).name
    C.loft("Body", path, radii, gm, nt=24)
    sm = C.solid_material("Scutes", "#2a3418", rough=0.6)
    for i in range(30):
        s = 0.12 + i * 0.022
        x = -1.3 + 2.6 * s
        idx = int(s * (n - 1))
        for yy in ((-0.03, 0.03) if s > 0.5 else (0,)):
            C.sphere("Scute", (x, yy, path[idx][1] + radii[idx][1] * 0.95), 0.018, sm, scale=(1.2, 0.8, 1.4), seg=8, rings=4)
    leg = C.solid_material("Leg", "#3a4620", rough=0.5)
    for lx, front in ((0.0, False), (0.36, True)):
        for s in (-1, 1):
            C.tube("Leg", [(lx, s * 0.1, -0.03), (lx + 0.03, s * 0.16, -0.1), (lx + 0.06, s * 0.15, -0.16)], 0.035, leg, taper=False)
            C.sphere("Foot", (lx + 0.09, s * 0.15, -0.165), 0.04, leg, scale=(1.5, 1.0, 0.4))
    hx = -1.3 + 2.6 * 0.82
    for s in (-1, 1):
        C.sphere("EyeBump", (hx, s * 0.05, 0.08), 0.035, gm, scale=(1.2, 1, 0.8))
        C.add_eye(hx + 0.01, s * 0.065, 0.1, 0.02, "#c8b040", side=s, name="GEye%d" % s)
    root = C.parent_all()
    root.rotation_euler = (math.radians(14), 0, 0)
    return dict(W=139)


# ---------------------------------------------------------------- sewer rat (side)
def sewer_rat():
    n = 60
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        x = -0.45 + 0.9 * s
        if s < 0.75:
            k = s / 0.75
            r = 0.2 * math.sin(math.pi * (0.12 + 0.88 * k)) ** 0.6
            z = 0.02 * math.sin(k * math.pi)
        else:
            k = (s - 0.75) / 0.25
            r = 0.13 * (1 - 0.85 * k ** 1.3)
            z = -0.02 - 0.04 * k
        r = max(r, 0.012)
        path.append((x, z)); radii.append((r * 0.85, r))
    W, H = 512, 256
    U, V = grid(W, H)
    t = flank_t(V)
    fur = C.ramp(t, [(0, "#3e3a36"), (0.4, "#5a5450"), (0.7, "#7a726a"), (1, "#a49c90")])
    streak = C.vnoise_at(U * 900, V * 60, 1.0, 21)
    fur *= (0.8 + 0.35 * streak)[..., None]
    fm = tex("Fur", fur, rough=0.85, spec=0.15)
    C.loft("Body", path, radii, fm, nt=24)
    pink = C.solid_material("Pink", "#d8909a", rough=0.5)
    C.sphere("Nose", (0.452, 0, path[-1][1] + 0.0), 0.018, pink)
    tail = [(-0.42, 0, -0.05)]
    for i in range(1, 12):
        k = i / 11
        tail.append((-0.42 - 0.6 * k, 0, -0.08 - 0.04 * math.sin(k * 5) + 0.06 * k))
    C.tube("Tail", tail, 0.022, pink)
    for s in (-1, 1):
        C.sphere("Ear", (0.18, s * 0.07, 0.16), 0.06, pink, scale=(0.6, 0.25, 1.0))
        C.add_eye(0.3, s * 0.075, 0.06, 0.022, "#141010", side=s, name="REye%d" % s)
        for lx in (-0.25, 0.15):
            C.tube("Leg", [(lx, s * 0.08, -0.1), (lx + 0.02, s * 0.09, -0.19), (lx + 0.07, s * 0.09, -0.2)], 0.025, pink, taper=False)
    wm = C.solid_material("Whisker", "#d8d4cc", feat=(1, 0, 0))
    for dz in (-0.01, 0.015):
        C.tube("Whisker", [(0.43, -0.03, path[-1][1] + 0.02), (0.5, -0.06, path[-1][1] + 0.02 + dz * 2), (0.56, -0.07, path[-1][1] + dz * 4)], 0.004, wm, taper=False)
    C.parent_all()
    return dict(W=84)


# ---------------------------------------------------------------- glow-in-the-dark shrimp (side)
def glow_shrimp():
    n = 80
    path, radii = [], []
    for i in range(n):
        s = i / (n - 1)
        a = math.pi * (0.15 + 1.0 * (1 - s))     # a curled body
        rad = 0.38
        x = rad * math.cos(a) * 1.25
        z = rad * math.sin(a) * 0.75
        r = 0.08 * (0.35 + 0.65 * math.sin(math.pi * min(1, 0.15 + s * 0.85)) ** 0.7)
        if s > 0.82:
            r = 0.095 * (1 - 0.7 * ((s - 0.82) / 0.18) ** 1.5)
        path.append((x, z)); radii.append((r * 0.8, r))
    W, H = 512, 128
    U, V = grid(W, H)
    t = flank_t(V)
    col = C.ramp(t, [(0, "#5cc048"), (0.5, "#9ce07a"), (1, "#d8f4c0")])
    seg = (np.abs(np.sin(U * np.pi * 9)) < 0.18) & (U < 0.8)
    col[seg] *= 0.82
    gm = tex("ShrimpShell", col, rough=0.25, spec=0.6, emit=tuple(C.hexf("#8cff60") ** 2.2), emit_strength=0.3)
    C.loft("Body", path, radii, gm, nt=20)
    hx, hz = path[-1]
    fan = C.solid_material("Fan", "#7ad860", emit=0.25)
    x0, z0 = path[0]
    C.poly_fin("TailFan", C.chaikin([(x0 + 0.02, z0 + 0.03), (x0 - 0.06, z0 - 0.06), (x0 - 0.02, z0 - 0.14), (x0 + 0.06, z0 - 0.12), (x0 + 0.05, z0 - 0.02)], 2),
               (x0, z0), fan, thick=0.01)
    leg = C.solid_material("ShrimpLeg", "#6ac850", emit=0.2, feat=(1, 0, 0))
    for i in range(6):
        s = 0.35 + i * 0.08
        px, pz = path[int(s * (n - 1))]
        C.tube("Leg", [(px, -0.02, pz - 0.05), (px + 0.02, -0.03, pz - 0.13), (px + 0.0, -0.03, pz - 0.18)], 0.012, leg)
    ant = C.solid_material("Antenna", "#6ac850", emit=0.2, feat=(1, 0, 0))
    for dz in (0.0, 0.05):
        C.tube("Antenna", [(hx, 0, hz), (hx + 0.12, 0, hz + 0.1 + dz), (hx + 0.2, 0, hz + 0.02 + dz), (hx + 0.26, 0, hz - 0.15 + dz)], 0.006, ant, taper=False)
    C.tube("Rostrum", [(hx - 0.02, 0, hz + 0.03), (hx + 0.1, 0, hz + 0.06)], 0.012, gm)
    C.add_eye(hx - 0.03, -0.05, hz + 0.04, 0.025, "#101010", name="SEye")
    C.parent_all()
    return dict(W=59)


CREATURES = {"blue_crab": blue_crab, "stingray": stingray, "burmese_python": burmese_python,
             "baby_gator": baby_gator, "sewer_rat": sewer_rat, "glow_shrimp": glow_shrimp}


def render_one(key, tmp, samples=48, glb_dir=None):
    C.reset()
    spec = CREATURES[key]()
    C.setup_render(samples)
    sw, sh, ppu = C.side_frame(target_w=spec["W"], max_h=spec.get("max_h"))
    rgba, feat = C.render_side(tmp, sw, sh)
    spr = C.pixelate(rgba, feat)
    C.save_png(spr, os.path.join(OUT, key + ".png"))
    if glb_dir:
        os.makedirs(glb_dir, exist_ok=True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(glb_dir, key + ".glb"), export_format='GLB', export_apply=True)
    return spr


if __name__ == "__main__":
    only, sheet, glb, samples = None, None, None, 48
    for a in sys.argv[1:]:
        if a.startswith("--only="): only = a[7:].split(",")
        if a.startswith("--sheet="): sheet = a[8:]
        if a.startswith("--glb="): glb = a[6:]
        if a.startswith("--samples="): samples = int(a[10:])
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), "creatures3d")
    done = []
    for key in only or list(CREATURES):
        spr = render_one(key, tmp, samples, glb)
        done.append((key, spr))
        print("creature", key, spr.shape[1], "x", spr.shape[0], flush=True)
    if sheet:
        C.contact_sheet(done, sheet, cols=3, cw=420, ch=180, scale=3)
