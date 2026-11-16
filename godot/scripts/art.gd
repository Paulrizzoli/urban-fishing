class_name Art
## Drawing helpers shared by the world's nodes. Everything is drawn in tile units.

static var font: Font = null

static func shade(c: Color, f: float) -> Color:
	return c.lerp(Color.WHITE, f) if f >= 0.0 else c.lerp(Color.BLACK, -f)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, col)

## Text in tile units. size is the cap height in tiles.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, col: Color, outline := Color(0, 0, 0, 0)) -> void:
	if font == null: font = Game.font_display
	var fs := 32
	var k := size / fs * 1.35
	ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if outline.a > 0: ci.draw_string_outline(font, Vector2(-w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, outline)
	ci.draw_string(font, Vector2(-w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- buildings ----------
static func house(ci: CanvasItem, b: Dictionary) -> void:
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var c := Color(b.color)
	var wall_h := 0.55
	var wy := y + h - wall_h
	ci.draw_rect(Rect2(x + 0.3, y + 0.2, w + 0.15, h + 0.15), Color(0.08, 0.14, 0.08, 0.24))
	ci.draw_rect(Rect2(x, wy, w, wall_h), Color("#f6eedc"))
	ci.draw_rect(Rect2(x + w * 0.75, wy, w * 0.25, wall_h), Color(0, 0, 0, 0.07))
	for u in [0.5, 0.74]:
		ci.draw_rect(Rect2(x + w * u, wy + 0.14, 0.42, 0.26), Color("#6f9fb8"))
		ci.draw_rect(Rect2(x + w * u, wy + 0.14, 0.42, 0.06), Color(1, 1, 1, 0.5))
	ci.draw_rect(Rect2(x + 0.52, wy + 0.1, 0.42, wall_h - 0.1), Color("#13807b") if b.get("home", false) else Color("#8a5a35"))
	var rx0 := x - 0.12
	var rx1 := x + w + 0.12
	var ry0 := y - 0.28
	var ry1 := wy + 0.04
	var rh := ry1 - ry0
	var ins := minf(rh / 2, (rx1 - rx0) / 2)
	var cy := (ry0 + ry1) / 2
	poly(ci, [Vector2(rx0, ry0), Vector2(rx1, ry0), Vector2(rx1 - ins, cy), Vector2(rx0 + ins, cy)], shade(c, 0.16))
	poly(ci, [Vector2(rx0, ry1), Vector2(rx1, ry1), Vector2(rx1 - ins, cy), Vector2(rx0 + ins, cy)], shade(c, -0.1))
	poly(ci, [Vector2(rx0, ry0), Vector2(rx0 + ins, cy), Vector2(rx0, ry1)], shade(c, 0.04))
	poly(ci, [Vector2(rx1, ry0), Vector2(rx1 - ins, cy), Vector2(rx1, ry1)], shade(c, -0.24))
	for k in range(1, 4):
		var f := k / 4.0
		var inn := ins * (1 - f)
		ci.draw_line(Vector2(rx0 + inn + 0.05, cy + (ry1 - cy) * f), Vector2(rx1 - inn - 0.05, cy + (ry1 - cy) * f), Color(0, 0, 0, 0.08), 0.03)
		ci.draw_line(Vector2(rx0 + inn + 0.05, cy - (cy - ry0) * f), Vector2(rx1 - inn - 0.05, cy - (cy - ry0) * f), Color(0, 0, 0, 0.08), 0.03)
	ci.draw_line(Vector2(rx0 + ins, cy), Vector2(rx1 - ins, cy), shade(c, 0.42), 0.05)
	ci.draw_rect(Rect2(rx0, ry0, rx1 - rx0, rh), Color(0, 0, 0, 0.2), false, 0.03)
	ci.draw_rect(Rect2(x, ry1, w, 0.08), Color(0, 0, 0, 0.16))
	if Town.hash2(int(x), int(y)) > 0.55:
		ci.draw_rect(Rect2(rx1 - ins - 0.4, cy + 0.08, 0.32, 0.26), Color("#b8c1c6"))

static func flat(ci: CanvasItem, b: Dictionary) -> void:
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var c := Color(b.color)
	var kind: String = b.kind
	var small := kind == "booth" or kind == "bath" or kind == "atc"
	var fh := 0.45 if small else 0.85
	var fy := y + h - fh
	ci.draw_rect(Rect2(x + 0.35, y + 0.2, w + 0.2, h + 0.2), Color(0.08, 0.12, 0.12, 0.24))
	ci.draw_rect(Rect2(x, fy, w, fh), shade(c, -0.24))
	if not small:
		var wx := x + 0.3
		while wx < x + w - 0.5:
			ci.draw_rect(Rect2(wx, fy + 0.2, 0.55, 0.38), Color(0.63, 0.8, 0.88, 0.9))
			ci.draw_rect(Rect2(wx, fy + 0.2, 0.55, 0.08), Color(1, 1, 1, 0.35))
			wx += 0.9
	ci.draw_rect(Rect2(x, y - 0.3, w, h - fh + 0.3), c)
	ci.draw_rect(Rect2(x + 0.16, y - 0.14, w - 0.32, h - fh - 0.02), shade(c, -0.07))
	ci.draw_rect(Rect2(x, y - 0.3, w, 0.06), shade(c, 0.3))
	ci.draw_rect(Rect2(x, fy, w, 0.07), Color(0, 0, 0, 0.18))
	if w * h >= 20 and kind != "shop" and kind != "mega":
		for k in int(w * h / 18):
			var ux := x + 0.5 + Town.hash2(k, int(x) * 3 + int(y)) * (w - 1.6)
			var uy := y + 0.1 + Town.hash2(int(y) + k, int(x)) * maxf(0.2, h - fh - 1.1)
			ci.draw_rect(Rect2(ux + 0.1, uy + 0.1, 0.7, 0.5), Color(0, 0, 0, 0.2))
			ci.draw_rect(Rect2(ux, uy, 0.7, 0.5), Color("#c9ced2"))
			ci.draw_circle(Vector2(ux + 0.35, uy + 0.25), 0.17, Color("#9aa6ad"))
	var ink := Color("#22313a")
	match kind:
		"shop":
			ci.draw_rect(Rect2(x + 0.6, y + 1.45, w - 1.2, 1.6), Color("#fbf3e2"))
			text(ci, Vector2(x + w / 2, y + 2.25), "LOU'S BAIT", 0.5, ink)
			text(ci, Vector2(x + w / 2, y + 2.85), "& TACKLE · LIVE SHRIMP", 0.28, ink)
			for i in 8: ci.draw_rect(Rect2(x + i, fy - 0.12, 1, 0.34), Color("#fbf3e2") if i % 2 else Color("#e2583e"))
			ci.draw_rect(Rect2(48.15, fy + 0.22, 0.7, fh - 0.22), Color("#13807b"))
			# Lou's fiberglass tarpon on the roof
			var tx := 49.0
			var ty := 27.75
			ellipse(ci, Vector2(tx + 0.15, ty + 0.2), 1.5, 0.32, Color(0, 0, 0, 0.25))
			poly(ci, [Vector2(tx - 1.45, ty), Vector2(tx - 0.3, ty - 0.5), Vector2(tx + 1.1, ty - 0.1), Vector2(tx + 1.55, ty - 0.42), Vector2(tx + 1.4, ty), Vector2(tx + 1.55, ty + 0.42), Vector2(tx + 1.1, ty + 0.1), Vector2(tx - 0.3, ty + 0.5)], Color("#d6dee2"))
			ci.draw_circle(Vector2(tx - 1.05, ty - 0.05), 0.06, ink)
		"club":
			for i in int(w): ci.draw_rect(Rect2(x + i, fy - 0.12, 1, 0.3), Color("#fbf3e2") if i % 2 else Color("#2f8a3e"))
		"mega":
			text(ci, Vector2(x + w / 2, y + 2.6), "FINTASTIC!", 0.8, Color("#f2b134"))
			text(ci, Vector2(x + w / 2, y + 3.3), "OUTDOOR MEGASTORE · AS SEEN ON TV", 0.26, Color("#fbf3e2"))
			ci.draw_rect(Rect2(87.9, fy + 0.15, 1.2, fh - 0.15), Color(0.08, 0.16, 0.24, 0.85))
		"marina":
			for i in int(w): ci.draw_rect(Rect2(x + i, fy - 0.12, 1, 0.32), Color("#fbf3e2") if i % 2 else Color("#13807b"))
			text(ci, Vector2(x + w / 2, y + 1.8), "MARINA", 0.5, Color("#13807b"))
			ci.draw_rect(Rect2(88.15, fy + 0.2, 0.7, fh - 0.2), Color(0.08, 0.16, 0.24, 0.85))
		"bath": text(ci, Vector2(x + w / 2, y + 1.2), "RESTROOMS", 0.36, ink)
		"booth": text(ci, Vector2(x + w / 2, y + 0.9), "TICKETS", 0.3, ink)
		"atc":
			ci.draw_circle(Vector2(x + 1.5, y + 1.3), 1.05, Color("#7fc4d8"))
			ci.draw_arc(Vector2(x + 1.5, y + 1.3), 1.05, 0, TAU, 24, Color("#3d4a52"), 0.08)
	if b.label == "THE RIVER ROOM": text(ci, Vector2(x + w / 2, y + 1.6), "RIVER ROOM", 0.45, Color("#fbf3e2"))
	if b.label == "CITY HALL":
		ci.draw_circle(Vector2(x + w / 2, y + 2), 1.2, Color("#d8c9a6"))
		ci.draw_circle(Vector2(x + w / 2 - 0.25, y + 1.75), 0.6, Color("#c9a574"))

static func cooling_tower(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var c := Vector2(b.x + 3.5, b.y + 3.2)
	ellipse(ci, c + Vector2(0.4, 0.3), 3.4, 2.9, Color(0, 0, 0, 0.25))
	ellipse(ci, c, 3.4, 2.8, Color("#c9d0d4"))
	ellipse(ci, c + Vector2(-0.5, -0.5), 2.6, 2.0, Color("#dfe4e7"))
	ellipse(ci, c, 2.2, 1.7, Color("#59656b"))
	for i in 4:
		var k := fmod(t * 0.12 + i / 4.0, 1.0)
		ci.draw_circle(c + Vector2(k * 2.5, -0.4 - k * 3.2), 1 + k * 2, Color(1, 1, 1, 0.5 * (1 - k)))

static func volcano(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var c := Vector2(b.x + 2.5, b.y + 2)
	ellipse(ci, c + Vector2(0.3, 0.3), 2.6, 2.1, Color(0, 0, 0, 0.25))
	ellipse(ci, c, 2.5, 2.0, Color("#5c4632"))
	ellipse(ci, c + Vector2(-0.4, -0.4), 1.8, 1.4, Color("#7a5e44"))
	ellipse(ci, c, 0.8, 0.6, Color("#f07b2f"))
	ellipse(ci, c, 0.4 + sin(t * 3) * 0.08, 0.28, Color("#ffd28a"))
	for i in 3:
		var k := fmod(t * 0.2 + i / 3.0, 1.0)
		ci.draw_circle(c + Vector2(k * 1.2, -k * 2.5), 0.4 + k * 0.8, Color(0.8, 0.8, 0.8, 0.4 * (1 - k)))

## Skyscraper in a 3/4 view: the roof is lifted by its height and leans a little east.
static func sky_geom(b: Dictionary) -> Vector2:
	var H: float = b.ht * 0.42
	return Vector2(H, H * 0.16)

static func sky_shadow(ci: CanvasItem, b: Dictionary) -> void:
	var g := sky_geom(b)
	var L := g.x * 0.55
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	poly(ci, [Vector2(x + w, y), Vector2(x + w + L, y + L * 0.35), Vector2(x + w + L, y + h + L * 0.35), Vector2(x + L, y + h + L * 0.35), Vector2(x, y + h), Vector2(x + w, y + h)], Color(0.06, 0.1, 0.18, 0.2))

static func sky_windows(b: Dictionary) -> Array:
	var g := sky_geom(b)
	var H := g.x
	var dx := g.y
	var out := []
	var rows: int = maxi(1, int((H - 0.3) / 0.46))
	var cols: int = maxi(1, int((b.w - 0.3) / 0.5))
	for r in rows:
		var z := 0.35 + r * 0.46
		for c in cols:
			var u := (c + 0.5) / cols
			out.append(Rect2(b.x + u * b.w - 0.15 + dx * (z / H), b.y + b.h - z - 0.28, 0.3, 0.27))
	return out

static func sky(ci: CanvasItem, b: Dictionary) -> void:
	var g := sky_geom(b)
	var H := g.x
	var dx := g.y
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var c := Color(b.color)
	poly(ci, [Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x + w + dx, y + h - H), Vector2(x + w + dx, y - H)], shade(c, -0.45))
	var face := PackedVector2Array([Vector2(x, y + h), Vector2(x + w, y + h), Vector2(x + w + dx, y + h - H), Vector2(x + dx, y + h - H)])
	var bot := shade(c, -0.34)
	var top := shade(c, -0.06)
	ci.draw_polygon(face, PackedColorArray([bot, bot, top, top]))
	var glass := Color(0.8, 0.93, 0.98, 0.72) if b.get("glass", false) else Color(0.12, 0.2, 0.27, 0.42)
	for r in b.wins: ci.draw_rect(r, glass)
	if b.get("glass", false):
		var sx0 := x + w * 0.2
		poly(ci, [Vector2(sx0, y + h), Vector2(sx0 + 1.0, y + h), Vector2(sx0 + 1.0 + dx, y + h - H), Vector2(sx0 + dx, y + h - H)], Color(1, 1, 1, 0.1))
	ci.draw_rect(Rect2(x, y + h - 0.3, w, 0.3), shade(c, -0.55))
	ci.draw_rect(Rect2(x + w / 2 - 0.4, y + h - 0.26, 0.8, 0.24), Color(1, 0.94, 0.78, 0.55))
	ci.draw_polyline(PackedVector2Array([Vector2(x, y + h), Vector2(x + dx, y + h - H), Vector2(x + w + dx, y + h - H), Vector2(x + w + dx, y - H)]), Color(0, 0, 0, 0.25), 0.04)
	if b.get("logo", false): text(ci, Vector2(x + w / 2 + dx * 0.9, y + h - H + 0.7), "MARLOWE", 0.45, Color(1, 1, 1, 0.92))
	var rx := x + dx
	var ry := y - H
	ci.draw_rect(Rect2(rx, ry, w, h), shade(c, 0.14))
	ci.draw_rect(Rect2(rx + 0.18, ry + 0.18, w - 0.36, h - 0.36), shade(c, -0.06))
	ci.draw_rect(Rect2(rx, ry, w, 0.06), shade(c, 0.4)); ci.draw_rect(Rect2(rx, ry, 0.06, h), shade(c, 0.4))
	if b.get("heli", false):
		var cc := Vector2(rx + w / 2, ry + h / 2)
		var rr := minf(w, h) * 0.34
		ci.draw_circle(cc, rr, Color("#3d4a52"))
		ci.draw_arc(cc, rr * 0.85, 0, TAU, 32, Color("#f2b134"), 0.1)
		text(ci, cc + Vector2(0, rr * 0.4), "H", rr * 0.8, Color.WHITE)
	elif b.get("pool", false):
		ci.draw_rect(Rect2(rx + 0.5, ry + 0.5, w - 1, h - 1), Color("#f4efe4"))
		ci.draw_rect(Rect2(rx + 0.8, ry + 0.8, w * 0.55, h - 1.6), Color("#5fd0e8"))
		for k in 3: ci.draw_rect(Rect2(rx + w * 0.7, ry + 0.9 + k * 0.7, 0.8, 0.3), Color("#f2b134") if k % 2 else Color("#e2583e"))
	else:
		for k in maxi(1, int(w * h / 14)):
			var ux := rx + 0.45 + Town.hash2(k, int(x) * 3 + int(y)) * (w - 1.5)
			var uy := ry + 0.45 + Town.hash2(int(y) + k, int(x)) * (h - 1.4)
			ci.draw_rect(Rect2(ux + 0.1, uy + 0.1, 0.65, 0.5), Color(0, 0, 0, 0.2))
			ci.draw_rect(Rect2(ux, uy, 0.65, 0.5), Color("#c9ced2"))
			ci.draw_circle(Vector2(ux + 0.32, uy + 0.25), 0.16, Color("#9aa6ad"))
	if b.get("ant", false):
		var ax := rx + w * 0.75
		var ay := ry + h * 0.4
		ci.draw_line(Vector2(ax, ay), Vector2(ax, ay - 1.1), Color("#8b9196"), 0.06)
		ci.draw_circle(Vector2(ax, ay - 1.1), 0.08, Color("#e2583e"))

# ---------- plants ----------
static func bush(ci: CanvasItem, x: int, y: int) -> void:
	if Town.zone[Town.idx(x, y)] == 8:
		ci.draw_rect(Rect2(x + 0.12, y + 0.16, 0.9, 0.9), Color(0, 0, 0, 0.2))
		ci.draw_rect(Rect2(x + 0.04, y + 0.06, 0.92, 0.9), Color("#cfc6b4"))
		ci.draw_rect(Rect2(x + 0.14, y + 0.16, 0.72, 0.7), Color("#5c4a36"))
	var h := Town.hash2(x, y)
	ellipse(ci, Vector2(x + 0.62, y + 0.8), 0.55, 0.25, Color(0.08, 0.16, 0.08, 0.22))
	ci.draw_circle(Vector2(x + 0.5, y + 0.6), 0.5, Color("#2a6a30"))
	for p in [[0.33, 0.46, 0.33], [0.68, 0.52, 0.3], [0.5, 0.72, 0.3]]: ci.draw_circle(Vector2(x + p[0], y + p[1]), p[2], Color("#3a8a42"))
	ci.draw_circle(Vector2(x + 0.3, y + 0.38), 0.15, Color("#58a85c")); ci.draw_circle(Vector2(x + 0.62, y + 0.42), 0.12, Color("#58a85c"))
	if h > 0.6:
		for k in 4: ci.draw_circle(Vector2(x + 0.2 + Town.hash2(k, x) * 0.6, y + 0.3 + Town.hash2(y, k) * 0.5), 0.06, Color("#e2583e") if h > 0.8 else Color("#f48fb1"))

static func tree(ci: CanvasItem, x: int, y: int, t: float) -> void:
	var h := Town.hash2(x, y)
	if (y < 33 and h < 0.5) or (Town.zone[Town.idx(x, y)] == 1 and h < 0.35):
		ellipse(ci, Vector2(x + 0.9, y + 0.9), 1.0, 0.55, Color(0.08, 0.16, 0.08, 0.25))
		ci.draw_circle(Vector2(x + 0.5, y + 0.45), 0.78, Color("#2c6a30"))
		for p in [[0.25, 0.25, 0.48], [0.82, 0.32, 0.42], [0.5, 0.72, 0.45]]: ci.draw_circle(Vector2(x + p[0], y + p[1]), p[2], Color("#3b8a3f"))
		ci.draw_circle(Vector2(x + 0.12, y + 0.1), 0.22, Color("#5aa95a")); ci.draw_circle(Vector2(x + 0.6, y + 0.05), 0.18, Color("#5aa95a"))
		return
	var sway := sin(t * 1.1 + x * 0.7 + y) * 0.05
	var c := Vector2(x + 0.55 + sway, y + 0.2)
	ellipse(ci, Vector2(x + 1.1, y + 0.95), 0.95, 0.4, Color(0.08, 0.16, 0.08, 0.22))
	var trunk := PackedVector2Array()
	for i in 7:
		var f := i / 6.0
		trunk.append(Vector2(x + 0.45, y + 0.95).lerp(c, f) + Vector2(-0.08 * sin(f * PI), 0))
	ci.draw_polyline(trunk, Color("#8a6a42"), 0.13)
	for k in range(1, 4): ci.draw_line(Vector2(x + 0.37, y + 0.95 - k * 0.2), Vector2(x + 0.52, y + 0.93 - k * 0.2), Color(0.24, 0.16, 0.08, 0.5), 0.03)
	var a0 := h * TAU
	for i in 7:
		var a := a0 + i * TAU / 7 + sin(t * 1.4 + i + x) * 0.04
		var L := 0.78 + Town.hash2(i, x + y) * 0.15
		var tip := c + Vector2(cos(a) * L, sin(a) * L * 0.62 + 0.1)
		var perp := Vector2(-sin(a), cos(a)) * 0.17
		var mid := (c + tip) / 2 + Vector2(0, -0.12)
		var leaf := PackedVector2Array()
		for j in 7:
			var f := j / 6.0
			leaf.append(_quad(c, mid + perp, tip, f))
		for j in range(5, 0, -1):
			var f := j / 6.0
			leaf.append(_quad(c, mid - perp, tip, f))
		ci.draw_colored_polygon(leaf, Color("#2f8a3e") if i % 2 else Color("#47a64f"))
		ci.draw_line(c, tip, Color(0.86, 0.98, 0.7, 0.3), 0.025)
	for p in [[-0.06, 0.04], [0.07, 0.06], [0.0, 0.12]]: ci.draw_circle(c + Vector2(p[0], p[1]), 0.07, Color("#6b4a2a"))

static func _quad(a: Vector2, b: Vector2, c: Vector2, f: float) -> Vector2:
	return a.lerp(b, f).lerp(b.lerp(c, f), f)

# ---------- people, cars, fish ----------
static func person(ci: CanvasItem, p: Vector2, dir: float, shirt: Color, hat: Color = Color(0, 0, 0, 0), rod := false) -> void:
	ellipse(ci, p + Vector2(0, 0.28), 0.36, 0.15, Color(0, 0, 0, 0.25))
	ellipse(ci, p, 0.32, 0.26, shirt)
	ellipse(ci, p + Vector2(0, -0.04), 0.26, 0.18, shade(shirt, 0.12))
	ci.draw_circle(p + Vector2(0, -0.22), 0.17, Color("#e0b48c"))
	if hat.a > 0: ellipse(ci, p + Vector2(0, -0.27), 0.25, 0.14, hat)
	if rod: ci.draw_line(p + Vector2(0, -0.1), p + Vector2(cos(dir) * 1.3, sin(dir) * 1.3 - 0.6), Color("#3d2b1a"), 0.05)

static func car(ci: CanvasItem, p: Vector2, rot: float, col: Color, L := 1.75, W := 0.85) -> void:
	ci.draw_set_transform(p, rot, Vector2.ONE)
	ci.draw_rect(Rect2(-L / 2 + 0.08, -W / 2 + 0.1, L, W), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(-L / 2, -W / 2, L, W), col)
	ci.draw_rect(Rect2(L * 0.08, -W * 0.38, L * 0.18, W * 0.76), Color(0.08, 0.14, 0.18, 0.75))
	ci.draw_rect(Rect2(-L * 0.36, -W * 0.36, L * 0.12, W * 0.72), Color(0.08, 0.14, 0.18, 0.75))
	ci.draw_rect(Rect2(-L * 0.22, -W * 0.34, L * 0.3, W * 0.68), Color(1, 1, 1, 0.22))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func fish_shadow(ci: CanvasItem, p: Vector2, dir: float, L: float, alpha: float, glow := false, wob := 0.0) -> void:
	var col := Color(0.47, 1.0, 0.67, alpha) if glow else Color(0.03, 0.11, 0.17, alpha)
	ci.draw_set_transform(p, dir, Vector2.ONE)
	ellipse(ci, Vector2.ZERO, L * 0.5, L * 0.17, col)
	var wag := sin(wob) * L * 0.08
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.4, 0), Vector2(-L * 0.72, -L * 0.17 + wag), Vector2(-L * 0.72, L * 0.17 + wag)]), col)
	ellipse(ci, Vector2(L * 0.02, -L * 0.16), L * 0.12, L * 0.05, col, -0.4)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
