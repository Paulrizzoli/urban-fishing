"""Shared pieces for the Blender-made sprites: scene setup, painted textures, fins, lights,
rendering, and the step that turns a 10x render into a pixel-art sprite.

Everything runs headless with Blender as a Python module:  pip install bpy==5.3.0
The model is built in Blender units; the side view looks along +Y (the model's left flank
faces the camera), x runs to the right and z is up.
"""
import math, os
import numpy as np
import bpy, bmesh
from mathutils import Vector
from PIL import Image

PX = 10            # render pixels per sprite pixel


# ---------------------------------------------------------------- colors and noise
def hexf(s):
    s = s.lstrip('#')
    return np.array([int(s[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def ramp(t, stops):
    pos = np.array([p for p, _ in stops])
    cols = np.array([hexf(c) if isinstance(c, str) else np.asarray(c, float) for _, c in stops])
    out = np.empty(np.shape(t) + (3,))
    for k in range(3):
        out[..., k] = np.interp(t, pos, cols[:, k])
    return out


def mix(a, b, f):
    return np.asarray(a) * (1 - f) + np.asarray(b) * f


def lighten(c, f):  # f in -1..1
    c = np.asarray(c, float)
    return c * (1 + f) if f < 0 else c + (1 - c) * f


_GRIDS = {}


def vnoise_at(X, Y, scale, seed):
    """Value noise at arbitrary coordinates."""
    if seed not in _GRIDS:
        _GRIDS[seed] = np.random.default_rng(seed).random((512, 512))
    g = _GRIDS[seed]
    X, Y = np.asarray(X) / scale + 7.3, np.asarray(Y) / scale + 11.1
    x0, y0 = np.floor(X).astype(int), np.floor(Y).astype(int)
    fx, fy = X - x0, Y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    m = 511
    a, b = g[y0 % m, x0 % m], g[y0 % m, (x0 + 1) % m]
    c, d = g[(y0 + 1) % m, x0 % m], g[(y0 + 1) % m, (x0 + 1) % m]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(X, Y, scale, seed, octaves=3):
    tot, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        tot = tot + amp * vnoise_at(X, Y, scale / 2 ** o, seed * 7 + o)
        norm += amp
        amp *= 0.5
    return tot / norm


def chaikin(pts, it=3):
    """Round off an outline whose two ends stay pinned (to the body)."""
    for _ in range(it):
        out = [pts[0]]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            out += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        out.append(pts[-1])
        pts = out
    return pts


# ---------------------------------------------------------------- scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in (bpy.data.images, bpy.data.materials, bpy.data.meshes):
        for b in list(coll):
            coll.remove(b)
    return bpy.context.scene


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def make_image(name, arr, alpha=None, data=False):
    """arr: H x W x 3 in 0..1 (sRGB), row 0 at the top."""
    H, W, _ = arr.shape
    img = bpy.data.images.new(name, W, H, alpha=True)
    rgba = np.ones((H, W, 4), np.float32)
    rgba[..., :3] = np.clip(arr, 0, 1)
    if alpha is not None:
        rgba[..., 3] = alpha
    if data:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.pack()
    return img


def tex_material(name, img, rough=0.5, spec=0.35, metal=0.0, emit=None, emit_strength=0.0, feat=None, alpha_img=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha_img:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    bsdf.inputs["Metallic"].default_value = metal
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    if feat is not None:
        m["feat"] = feat
    return m


def solid_material(name, rgb, rough=0.5, spec=0.4, metal=0.0, emit=0.0, feat=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = hexf(rgb) if isinstance(rgb, str) else rgb
    lin = [c ** 2.2 for c in rgb]
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = spec
    b.inputs["Metallic"].default_value = metal
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = emit
    if feat is not None:
        m["feat"] = feat
    return m


def mesh_object(name, verts, faces, mat=None, smooth=True, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs(me.loops[li].vertex_index)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = link(bpy.data.objects.new(name, me))
    if mat is not None:
        me.materials.append(mat)
    return ob


def fin_texture(stops, rays=12, ray_strength=0.22, seed=7, edge=None):
    """u = 0 at the root -> 1 at the edge, v across the rays."""
    W, H = 256, 128
    U, V = np.meshgrid((np.arange(W) + 0.5) / W, (np.arange(H) + 0.5) / H)
    col = ramp(U, stops)
    r = (0.5 + 0.5 * np.cos(V * 2 * np.pi * rays)) ** 3
    col *= (1 - ray_strength * 0.6 + ray_strength * r[..., None])
    col *= (0.94 + 0.1 * vnoise_at(U * 20, V * 10, 1.0, seed)[..., None])
    if edge is not None:
        col[U > 0.86] = edge
    return np.clip(col, 0, 1)


def poly_fin(name, outline, root, mat, y=0.0, thick=0.012, rot=None, subdiv=2):
    """A flat fin from an (x, z) outline; rays fan out from root (x, z). Pivot at the root."""
    rx, rz = root
    cx = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    a0 = math.atan2(cz - rz, cx - rx)
    wrap = lambda a: (a - a0 + math.pi) % (2 * math.pi) - math.pi
    angs = [wrap(math.atan2(pz - rz, px - rx)) for px, pz in outline]
    a_lo, a_hi = min(angs), max(angs)
    dmax = max(math.hypot(px - rx, pz - rz) for px, pz in outline) or 1
    bm = bmesh.new()
    vs = [bm.verts.new((px, y, pz)) for px, pz in outline]
    try:
        bm.faces.new(vs)
    except ValueError:
        bm.free(); return None
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for _ in range(subdiv):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    uvlay = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for lp in f.loops:
            co = lp.vert.co
            d = math.hypot(co.x - rx, co.z - rz) / dmax
            a = (wrap(math.atan2(co.z - rz, co.x - rx)) - a_lo) / max(1e-6, a_hi - a_lo)
            lp[uvlay].uv = (min(1, d), a)
    pivot = Vector((rx, y, rz))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=-pivot)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    ob.location = pivot
    me.materials.append(mat)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 0
    if rot:
        ob.rotation_euler = rot
    return ob


def strip_fin(name, base, tips, mat, y=0.0, thick=0.012):
    """A fin built as quads from points on the body (base) out to its edge (tips)."""
    bm = bmesh.new()
    uvlay = bm.loops.layers.uv.new("UVMap")
    b = [bm.verts.new((px, y, pz)) for px, pz in base]
    t = [bm.verts.new((px, y, pz)) for px, pz in tips]
    n = len(base)
    for k in range(n - 1):
        f = bm.faces.new((b[k], b[k + 1], t[k + 1], t[k]))
        for lp, uv in zip(f.loops, [(0, k / (n - 1)), (0, (k + 1) / (n - 1)), (1, (k + 1) / (n - 1)), (1, k / (n - 1))]):
            lp[uvlay].uv = uv
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = link(bpy.data.objects.new(name, me))
    me.materials.append(mat)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 0
    return ob


def loft(name, path, radii, mat, nt=24, caps=True, uv_scale=1.0):
    """A tube along a path in the xz plane. path: [(x, z)], radii: [(half-width in y, half-height)].
    UVs: u along the length (0..1), v around (0 = top, 0.5 = bottom, the -y flank at 0.25)."""
    P = np.array(path, float)
    n = len(P)
    T = np.gradient(P, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-9
    N = np.stack([-T[:, 1], T[:, 0]], 1)          # in-plane normal (up when going +x)
    verts = []
    for i in range(n):
        ry, rz = radii[i]
        for j in range(nt + 1):
            a = 2 * math.pi * j / nt
            up, sd = math.cos(a), math.sin(a)
            verts.append((P[i, 0] + N[i, 0] * rz * up, -ry * sd, P[i, 1] + N[i, 1] * rz * up))
    R = nt + 1
    faces = [(i * R + j, i * R + j + 1, (i + 1) * R + j + 1, (i + 1) * R + j) for i in range(n - 1) for j in range(nt)]
    L = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
    L /= L[-1]
    extra = []
    if caps:
        c0 = len(verts); verts.append((P[0, 0], 0, P[0, 1]))
        c1 = len(verts); verts.append((P[-1, 0], 0, P[-1, 1]))
        for j in range(nt):
            faces.append((c0, j + 1, j))
            q = (n - 1) * R
            faces.append((q + j, q + j + 1, c1))
        extra = [c0, c1]

    def uv(vi):
        if extra and vi == extra[0]: return (0.0, 0.5)
        if extra and vi == extra[1]: return (1.0, 0.5)
        i, j = divmod(vi, R)
        return (L[i], j / nt)
    return mesh_object(name, verts, faces, mat, uvs=uv)


def tube(name, pts, radius, mat, taper=True, res=8):
    """A thin tube along a polyline of 3D points (whiskers, rods, wires)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = (1 - 0.8 * i / max(1, len(pts) - 1)) if taper else 1
    ob = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    return ob


def sphere(name, loc, r, mat, scale=(1, 1, 1), seg=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def add_eye(x, y, z, r, iris, side=-1, pupil_r=0.5, walleye=False, name="Eye"):
    """An eye on the flank facing -y (side=-1) or +y: an iris disc in a glossy ball, and a pupil."""
    yy, xx = np.mgrid[0:64, 0:64] / 63.0
    d = np.hypot(xx - 0.5, yy - 0.5) * 2
    ic = hexf(iris)
    img = ramp(d, [(0.0, lighten(ic, 0.25)), (0.6, ic), (0.85, lighten(ic, -0.45)), (1.0, lighten(ic, -0.7))])
    if walleye:
        img = ramp(d, [(0.0, "#f2f0dc"), (0.7, "#d8d4b0"), (1.0, "#6a6650")])
    m = tex_material(name + "Mat", make_image(name + "Img", img), rough=0.06, spec=0.9, feat=(0, 1, 0))
    e = sphere(name, (x, y, z), r, m, scale=(1, 0.75, 1), seg=24, rings=12)
    uv = e.data.uv_layers.active or e.data.uv_layers.new()
    for poly in e.data.polygons:
        for li in poly.loop_indices:
            co = e.data.vertices[e.data.loops[li].vertex_index].co
            uv.data[li].uv = (0.5 + co.x / (2 * r), 0.5 + co.z / (2 * r))
    pm = solid_material(name + "Pupil", (0.02, 0.02, 0.02), rough=0.05, spec=0.9, feat=(0, 0, 1))
    sphere(name + "Pupil", (x, y + side * r * 0.62, z), r * pupil_r, pm, scale=(1, 0.45, 1), seg=16, rings=8)
    return e


def parent_all(root_name="Root"):
    root = link(bpy.data.objects.new(root_name, None))
    for ob in list(bpy.context.scene.collection.objects):
        if ob is not root and ob.parent is None and ob.type in ("MESH", "CURVE", "EMPTY"):
            ob.parent = root
    return root


def bbox():
    """World bounding box (x0, x1, z0, z1, y0, y1) of every visible mesh/curve, with modifiers."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    for ob in bpy.context.scene.objects:
        if ob.type not in ("MESH", "CURVE") or ob.hide_render:
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ob.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo.x, hi.x, lo.z, hi.z, lo.y, hi.y


# ---------------------------------------------------------------- lights, camera, rendering
def setup_render(samples=48):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World"); scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.66, 1)
    bg.inputs["Strength"].default_value = 0.9

    def sun(name, rot, energy, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, "SUN"); d.energy = energy; d.color = color; d.angle = math.radians(8)
        o = bpy.data.objects.new(name, d); o.rotation_euler = rot; scene.collection.objects.link(o)
    sun("Key", (math.radians(35), math.radians(-20), math.radians(-25)), 2.8, (1.0, 0.97, 0.9))
    sun("Fill", (math.radians(110), 0, math.radians(30)), 0.8, (0.85, 0.92, 1.0))
    sun("Rim", (math.radians(-60), 0, math.radians(160)), 1.2)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    cam_d = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_d); scene.collection.objects.link(cam); scene.camera = cam
    return cam


def _render_to(path, w, h):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def side_frame(target_w=None, ppu=None, margin=2, max_h=None):
    """Frame the model for a side view. Give the sprite width in pixels (target_w) or pixels per
    unit (ppu). Returns (sprite_w, sprite_h, ppu)."""
    x0, x1, z0, z1, y0, y1 = bbox()
    if ppu is None:
        ppu = (target_w - 2 * margin) / (x1 - x0)
    if max_h and (z1 - z0) * ppu + 2 * margin > max_h:
        ppu = (max_h - 2 * margin) / (z1 - z0)
    sw = int(math.ceil((x1 - x0) * ppu)) + 2 * margin
    sh = int(math.ceil((z1 - z0) * ppu)) + 2 * margin
    cam = bpy.context.scene.camera
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(sw, sh) / ppu
    cam.location = ((x0 + x1) / 2, y0 - 30, (z0 + z1) / 2)
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.clip_end = 200
    return sw, sh, ppu


def render_side(tmp, sw, sh, features=True):
    """Beauty render plus a flat-colour feature pass; returns (rgba, feat) as float arrays."""
    os.makedirs(tmp, exist_ok=True)
    beauty = os.path.join(tmp, "beauty.png")
    _render_to(beauty, sw * PX, sh * PX)
    rgba = np.asarray(Image.open(beauty).convert("RGBA")).astype(np.float64) / 255
    feat = np.zeros(rgba.shape[:2] + (3,))
    if features:
        fpath = os.path.join(tmp, "feat.png")
        scene = bpy.context.scene
        saved = {}
        flats = {}
        for ob in scene.objects:
            if ob.type not in ("MESH", "CURVE"):
                continue
            for slot in ob.material_slots:
                m = slot.material
                if m is None:
                    continue
                key = m.name
                if key not in flats:
                    flats[key] = _flat_for(m)
                saved.setdefault(ob.name, []).append(m)
                slot.material = flats[key]
        s, d = scene.cycles.samples, scene.cycles.use_denoising
        scene.cycles.samples, scene.cycles.use_denoising = 8, False
        lights = [o for o in scene.objects if o.type == "LIGHT"]
        for o in lights: o.hide_render = True
        wc = scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value
        scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0
        _render_to(fpath, sw * PX, sh * PX)
        scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = wc
        for o in lights: o.hide_render = False
        scene.cycles.samples, scene.cycles.use_denoising = s, d
        for ob in scene.objects:
            if ob.name in saved:
                for slot, m in zip(ob.material_slots, saved[ob.name]):
                    slot.material = m
        feat = np.asarray(Image.open(fpath).convert("RGB")).astype(np.float64) / 255
    return rgba, feat


def _flat_for(m):
    f = bpy.data.materials.new("F_" + m.name)
    f.use_nodes = True
    nt = f.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(e.outputs[0], o.inputs[0])
    feat = m.get("feat")
    if isinstance(feat, str) and feat in bpy.data.images:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images[feat]; t.interpolation = "Closest"
        nt.links.new(t.outputs[0], e.inputs[0])
    elif feat is not None and not isinstance(feat, str):
        e.inputs[0].default_value = (*feat, 1)
    else:
        e.inputs[0].default_value = (0, 0, 0, 1)
    return f


def render_view(path, w, h, loc, rot, lens=50):
    cam = bpy.context.scene.camera
    cam.data.type = "PERSP"; cam.data.lens = lens
    cam.location, cam.rotation_euler = loc, rot
    _render_to(path, w, h)


# ---------------------------------------------------------------- render -> pixel art
def pixelate(rgba, feat, ncol=20, contrast=1.12, sat=1.2, outline=True, ink_rgb=(0.07, 0.08, 0.06)):
    """Area-downsample a PX-times render, keep the small details from the feature pass
    (R = line work, G = eye, B = pupil), reduce the palette and darken the edge into an outline."""
    from scipy import ndimage
    H, W = rgba.shape[0] // PX, rgba.shape[1] // PX
    rgba = rgba[:H * PX, :W * PX]; feat = feat[:H * PX, :W * PX]
    a = rgba[..., 3:4]
    pre = (rgba[..., :3] * a).reshape(H, PX, W, PX, 3).mean((1, 3))
    al = a.reshape(H, PX, W, PX, 1).mean((1, 3))
    rgb = np.where(al > 1e-4, pre / np.maximum(al, 1e-4), 0)
    mask = al[..., 0] > 0.45
    blk = lambda m: m.reshape(H, PX, W, PX).mean((1, 3))
    vis = rgba[..., 3] > 0.5
    ink_c, eye_c, pup_c = (blk(((feat[..., k] > 0.5) & vis).astype(float)) for k in range(3))
    hi = rgba[..., :3]

    def block_mean(sel):
        w = sel[..., None].astype(float)
        s = (hi * w).reshape(H, PX, W, PX, 3).sum((1, 3))
        return s / np.maximum(w.reshape(H, PX, W, PX, 1).sum((1, 3)), 1e-6)
    eye = ((eye_c + pup_c) > 0.14) & mask
    eye_rgb = np.clip(block_mean((feat[..., 1] > 0.5) & vis), 0, 1)
    line = (ink_c > 0.2) & mask & ~eye
    thin = (ink_c > 0.12) & ~mask           # whiskers, rods, lines thinner than a pixel
    ink_col = block_mean((feat[..., 0] > 0.5) & vis)
    rgb[thin] = ink_col[thin] * 0.85
    mask = mask | thin
    rgb[line] = rgb[line] * 0.2 + ink_col[line] * 0.55
    lum = rgb.mean(-1, keepdims=True)
    rgb = np.clip(lum + (rgb - lum) * sat, 0, 1)
    rgb = np.clip((rgb - 0.5) * contrast + 0.5, 0, 1)
    out = np.zeros((H, W, 4), np.uint8)
    if mask.sum() > 0:
        px = (rgb[mask] * 255).astype(np.uint8)
        n = min(ncol, max(2, len(np.unique(px, axis=0))))
        q = Image.fromarray(px.reshape(1, -1, 3)).quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        out[mask, :3] = np.asarray(q.convert("RGB")).reshape(-1, 3)
        out[mask, 3] = 255
    if outline:
        pad = np.pad(mask, 1)
        edge = mask & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        dark = (out[..., :3].astype(float) * 0.42 + np.array([8, 12, 10]) * 0.58).astype(np.uint8)
        out[edge, :3] = dark[edge]
    # eyes go on after the palette step so their few pixels are not merged away
    out[eye, :3] = (np.clip(eye_rgb[eye] * 1.1, 0, 1) * 255).astype(np.uint8)
    lab, n = ndimage.label(eye)
    for i in range(1, n + 1):
        comp = lab == i
        pc = np.where(comp, pup_c, -1)
        py, px_ = np.unravel_index(np.argmax(pc), pc.shape)
        out[py, px_, :3] = (14, 12, 10)
        if comp.sum() >= 4 and py > 0 and px_ > 0 and comp[py - 1, px_ - 1]:
            out[py - 1, px_ - 1, :3] = np.minimum(255, out[py - 1, px_ - 1, :3].astype(int) + 90)
    return crop_alpha(out)


def crop_alpha(img, pad=1):
    ys, xs = np.nonzero(img[..., 3])
    if len(ys) == 0:
        return img
    y0, y1, x0, x1 = max(0, ys.min() - pad), ys.max() + 1 + pad, max(0, xs.min() - pad), xs.max() + 1 + pad
    out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    src = img[y0:y1, x0:x1]
    out[:src.shape[0], :src.shape[1]] = src
    return out


def save_png(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path)


def contact_sheet(items, path, cols=6, scale=2, cw=320, ch=150, bg=(238, 244, 242, 255)):
    from PIL import ImageDraw
    rows = (len(items) + cols - 1) // cols
    S = Image.new("RGBA", (cols * cw, rows * (ch + 18)), bg)
    d = ImageDraw.Draw(S)
    for i, (key, arr) in enumerate(items):
        im = Image.fromarray(arr, "RGBA")
        s = max(1, min(scale, (cw - 8) // im.width, (ch - 6) // im.height))
        im = im.resize((im.width * s, im.height * s), Image.NEAREST)
        x = (i % cols) * cw + (cw - im.width) // 2
        y = (i // cols) * (ch + 18) + (ch - im.height) // 2
        S.alpha_composite(im, (x, y))
        d.text(((i % cols) * cw + 6, (i // cols) * (ch + 18) + ch + 2), key, fill=(34, 49, 58, 255))
    S.save(path)
