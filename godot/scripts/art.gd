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
## A soft drop shadow: a few stacked, slightly grown rectangles so the edge fades out.
static func soft_shadow(ci: CanvasItem, r: Rect2, off: Vector2, alpha := 0.24) -> void:
	for k in 4:
		var g := 0.16 - k * 0.05
		ci.draw_rect(Rect2(r.position + off - Vector2(g, g) * 0.5, r.size + Vector2(g, g)), Color(0.05, 0.1, 0.08, alpha * (0.3 + k * 0.2)))

static func window(ci: CanvasItem, r: Rect2, frame: Color, shutter := Color(0, 0, 0, 0)) -> void:
	if shutter.a > 0:
		ci.draw_rect(Rect2(r.position.x - 0.1, r.position.y, 0.08, r.size.y), shutter)
		ci.draw_rect(Rect2(r.end.x + 0.02, r.position.y, 0.08, r.size.y), shutter)
	ci.draw_rect(r.grow(0.035), frame)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color("#a8d2e4"), Color("#8cbcd4"), Color("#4f7f99"), Color("#6a9ab4")]))
	ci.draw_line(Vector2(r.position.x + r.size.x * 0.25, r.end.y), Vector2(r.position.x + r.size.x * 0.65, r.position.y), Color(1, 1, 1, 0.35), 0.04)
	ci.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), frame, 0.025)

static func house(ci: CanvasItem, b: Dictionary) -> void:
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var c := Color(b.color)
	var hs := Town.hash2(int(x) * 5, int(y) * 3)
	var wall_h := 0.62
	var wy := y + h - wall_h
	soft_shadow(ci, Rect2(x - 0.1, y - 0.2, w + 0.2, h + 0.2), Vector2(0.32, 0.24))
	# walls: stucco with lap siding, a darker east end and a little skirt at the bottom
	var wall := Color("#f6eedc") if hs < 0.6 else Color("#efe6d2") if hs < 0.85 else Color("#e9f0ea")
	ci.draw_rect(Rect2(x, wy, w, wall_h), wall)
	for k in range(1, 5): ci.draw_line(Vector2(x, wy + k * 0.12), Vector2(x + w, wy + k * 0.12), Color(0, 0, 0, 0.035), 0.02)
	ci.draw_rect(Rect2(x + w * 0.8, wy, w * 0.2, wall_h), Color(0, 0, 0, 0.07))
	ci.draw_rect(Rect2(x, y + h - 0.07, w, 0.07), shade(wall, -0.25))
	var trim := shade(c, -0.3)
	for u in [0.48, 0.72]: window(ci, Rect2(x + w * u, wy + 0.17, 0.4, 0.27), Color("#fbf8f0"), trim)
	# front door with a step and a porch light
	var door: Color = Color("#13807b") if b.get("home", false) else [Color("#8a5a35"), Color("#3d5a73"), Color("#7a3b3b"), Color("#4d6b4a")][int(hs * 4)]
	ci.draw_rect(Rect2(x + 0.48, wy + 0.1, 0.48, wall_h - 0.1), Color("#fbf8f0"))
	ci.draw_rect(Rect2(x + 0.52, wy + 0.14, 0.4, wall_h - 0.14), door)
	ci.draw_rect(Rect2(x + 0.56, wy + 0.2, 0.32, 0.12), shade(door, 0.15))
	ci.draw_circle(Vector2(x + 0.84, wy + 0.4), 0.025, Color("#e8c84a"))
	ci.draw_rect(Rect2(x + 0.42, y + h - 0.03, 0.6, 0.1), Color("#d8d1c1"))
	ci.draw_circle(Vector2(x + 1.06, wy + 0.2), 0.04, Color("#fff2c8"))
	# hip roof: four facets with shingle courses, lit from the top left
	var rx0 := x - 0.14
	var rx1 := x + w + 0.14
	var ry0 := y - 0.3
	var ry1 := wy + 0.06
	var rh := ry1 - ry0
	var ins := minf(rh / 2, (rx1 - rx0) / 2)
	var cy := (ry0 + ry1) / 2
	var top := shade(c, 0.16)
	var south := shade(c, -0.08)
	ci.draw_polygon(PackedVector2Array([Vector2(rx0, ry0), Vector2(rx1, ry0), Vector2(rx1 - ins, cy), Vector2(rx0 + ins, cy)]), PackedColorArray([shade(top, 0.06), top, top, shade(top, -0.04)]))
	ci.draw_polygon(PackedVector2Array([Vector2(rx0 + ins, cy), Vector2(rx1 - ins, cy), Vector2(rx1, ry1), Vector2(rx0, ry1)]), PackedColorArray([south, south, shade(south, -0.1), shade(south, -0.1)]))
	poly(ci, [Vector2(rx0, ry0), Vector2(rx0 + ins, cy), Vector2(rx0, ry1)], shade(c, 0.06))
	poly(ci, [Vector2(rx1, ry0), Vector2(rx1 - ins, cy), Vector2(rx1, ry1)], shade(c, -0.26))
	var line := Color(0, 0, 0, 0.09)
	var rows := 5
	for k in range(1, rows + 1):
		var f := float(k) / (rows + 1)
		var inn := ins * (1 - f)
		var ys := cy + (ry1 - cy) * f
		var yn := cy - (cy - ry0) * f
		ci.draw_line(Vector2(rx0 + inn + 0.04, ys), Vector2(rx1 - inn - 0.04, ys), line, 0.025)
		ci.draw_line(Vector2(rx0 + inn + 0.04, yn), Vector2(rx1 - inn - 0.04, yn), line, 0.025)
		# staggered shingle tabs on the south facet
		var sx := rx0 + inn + 0.1 + (0.12 if k % 2 else 0.0)
		while sx < rx1 - inn - 0.08:
			ci.draw_line(Vector2(sx, ys - (ry1 - cy) / (rows + 1)), Vector2(sx, ys), Color(0, 0, 0, 0.05), 0.02)
			sx += 0.24
	# hips and ridge
	ci.draw_line(Vector2(rx0, ry0), Vector2(rx0 + ins, cy), shade(c, 0.3), 0.04)
	ci.draw_line(Vector2(rx1, ry0), Vector2(rx1 - ins, cy), shade(c, -0.4), 0.04)
	ci.draw_line(Vector2(rx0, ry1), Vector2(rx0 + ins, cy), shade(c, 0.1), 0.04)
	ci.draw_line(Vector2(rx1, ry1), Vector2(rx1 - ins, cy), shade(c, -0.35), 0.04)
	ci.draw_line(Vector2(rx0 + ins, cy), Vector2(rx1 - ins, cy), shade(c, 0.45), 0.06)
	ci.draw_rect(Rect2(rx0, ry0, rx1 - rx0, rh), Color(0, 0, 0, 0.22), false, 0.03)
	# gutter and the shadow of the eave on the wall
	ci.draw_rect(Rect2(rx0, ry1 - 0.03, rx1 - rx0, 0.05), shade(c, -0.35))
	ci.draw_rect(Rect2(x, ry1 + 0.02, w, 0.1), Color(0, 0, 0, 0.14))
	# rooftop extras: solar panels, a chimney or a vent stack
	if hs > 0.72 and w >= 4:
		var px := rx0 + ins + 0.15
		var pw := (rx1 - ins - 0.15) - px
		var py := cy + 0.1
		var ph := (ry1 - cy) * 0.62
		ci.draw_rect(Rect2(px + 0.05, py + 0.06, pw, ph), Color(0, 0, 0, 0.2))
		ci.draw_rect(Rect2(px, py, pw, ph), Color("#2a3d5c"))
		var cols := int(pw / 0.36)
		for i in range(1, cols): ci.draw_line(Vector2(px + i * pw / cols, py), Vector2(px + i * pw / cols, py + ph), Color("#8aa2c4"), 0.02)
		ci.draw_line(Vector2(px, py + ph / 2), Vector2(px + pw, py + ph / 2), Color("#8aa2c4"), 0.02)
		ci.draw_line(Vector2(px, py), Vector2(px + pw, py), Color(1, 1, 1, 0.3), 0.025)
	elif hs < 0.3:
		var chx := rx1 - ins - 0.15 - hs * 1.2
		var chy := cy - 0.38
		ci.draw_rect(Rect2(chx + 0.06, chy + 0.1, 0.3, 0.34), Color(0, 0, 0, 0.22))
		ci.draw_rect(Rect2(chx, chy, 0.3, 0.34), Color("#b0624a"))
		ci.draw_rect(Rect2(chx, chy, 0.3, 0.07), Color("#c97e64"))
		ci.draw_rect(Rect2(chx + 0.06, chy + 0.02, 0.18, 0.04), Color("#3a2a22"))
	else:
		ci.draw_circle(Vector2(rx0 + ins + 0.3, cy - 0.18), 0.06, Color("#6b7378"))
		ci.draw_circle(Vector2(rx0 + ins + 0.3, cy - 0.19), 0.035, Color("#3a3f42"))
	# an AC unit on a pad by the east wall
	if Town.hash2(int(x), int(y)) > 0.45:
		var ax := x + w + 0.06
		var ay := wy + 0.2
		ci.draw_rect(Rect2(ax + 0.05, ay + 0.06, 0.34, 0.34), Color(0, 0, 0, 0.2))
		ci.draw_rect(Rect2(ax, ay, 0.34, 0.34), Color("#c9ced2"))
		ci.draw_circle(Vector2(ax + 0.17, ay + 0.17), 0.12, Color("#6f7a80"))
		ci.draw_line(Vector2(ax + 0.07, ay + 0.17), Vector2(ax + 0.27, ay + 0.17), Color("#c9ced2"), 0.02)
		ci.draw_line(Vector2(ax + 0.17, ay + 0.07), Vector2(ax + 0.17, ay + 0.27), Color("#c9ced2"), 0.02)
	# a strip of flowers along the front
	var fl: Color = [Color("#f48fb1"), Color("#f7d64a"), Color("#e2583e"), Color("#c9b6e4")][int(Town.hash2(int(y), int(x)) * 4)]
	var fx := x + 1.15
	while fx < x + w - 0.1:
		ci.draw_circle(Vector2(fx, y + h + 0.02), 0.1, Color("#3a8a42"))
		if Town.hash2(int(fx * 10), int(y)) > 0.4: ci.draw_circle(Vector2(fx - 0.03, y + h - 0.02), 0.04, fl)
		fx += 0.22

static func hvac(ci: CanvasItem, ux: float, uy: float, sz := 0.7) -> void:
	ci.draw_rect(Rect2(ux + 0.1, uy + 0.12, sz, sz * 0.72), Color(0, 0, 0, 0.22))
	ci.draw_rect(Rect2(ux, uy, sz, sz * 0.72), Color("#c9ced2"))
	ci.draw_rect(Rect2(ux, uy, sz, 0.05), Color("#e4e8ea"))
	ci.draw_rect(Rect2(ux, uy + sz * 0.72 - 0.05, sz, 0.05), Color("#9aa3a8"))
	var fc := Vector2(ux + sz * 0.5, uy + sz * 0.36)
	ci.draw_circle(fc, sz * 0.25, Color("#59646a"))
	for k in 3: ci.draw_line(fc, fc + Vector2.from_angle(k * TAU / 3 + ux) * sz * 0.22, Color("#9aa6ad"), 0.035)
	ci.draw_arc(fc, sz * 0.25, 0, TAU, 16, Color("#8b9196"), 0.025)

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
	soft_shadow(ci, Rect2(x, y - 0.3, w, h + 0.3), Vector2(0.38, 0.24))
	# the front wall, with a band of windows and their frames
	var wallc := shade(c, -0.24)
	ci.draw_polygon(PackedVector2Array([Vector2(x, fy), Vector2(x + w, fy), Vector2(x + w, y + h), Vector2(x, y + h)]),
		PackedColorArray([shade(wallc, 0.05), shade(wallc, 0.05), shade(wallc, -0.1), shade(wallc, -0.1)]))
	if not small:
		var wx := x + 0.3
		while wx < x + w - 0.5:
			var r := Rect2(wx, fy + 0.2, 0.55, 0.38)
			ci.draw_rect(r.grow(0.03), shade(wallc, -0.3))
			ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
				PackedColorArray([Color(0.72, 0.87, 0.94), Color(0.62, 0.8, 0.9), Color(0.36, 0.55, 0.66), Color(0.45, 0.64, 0.75)]))
			ci.draw_line(Vector2(wx + 0.1, fy + 0.58), Vector2(wx + 0.35, fy + 0.2), Color(1, 1, 1, 0.3), 0.04)
			ci.draw_rect(Rect2(wx - 0.03, fy + 0.58, 0.61, 0.04), shade(wallc, 0.25))
			wx += 0.9
	ci.draw_rect(Rect2(x, y + h - 0.06, w, 0.06), shade(wallc, -0.3))
	# the roof: membrane with seams, a raised parapet lit from the top left
	ci.draw_rect(Rect2(x, y - 0.3, w, h - fh + 0.3), c)
	var inner := Rect2(x + 0.16, y - 0.14, w - 0.32, h - fh - 0.02)
	var mem := shade(c, -0.07)
	ci.draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([shade(mem, 0.03), mem, shade(mem, -0.03), mem]))
	var sx := inner.position.x + 1.0
	while sx < inner.end.x - 0.2:
		ci.draw_line(Vector2(sx, inner.position.y), Vector2(sx, inner.end.y), Color(0, 0, 0, 0.04), 0.025)
		sx += 1.0
	for k in int(w * h * 0.8):
		var gx := inner.position.x + Town.hash2(k * 3, int(x * 7 + y)) * inner.size.x
		var gy := inner.position.y + Town.hash2(int(y * 5 + x), k * 7) * inner.size.y
		ci.draw_rect(Rect2(gx, gy, 0.05, 0.05), Color(0, 0, 0, 0.06) if k % 2 else Color(1, 1, 1, 0.07))
	# inner shadow under the parapet's north and west edges
	ci.draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 0.08), Color(0, 0, 0, 0.1))
	ci.draw_rect(Rect2(inner.position.x, inner.position.y, 0.08, inner.size.y), Color(0, 0, 0, 0.08))
	ci.draw_rect(Rect2(x, y - 0.3, w, 0.06), shade(c, 0.32))
	ci.draw_rect(Rect2(x, y - 0.3, 0.06, h - fh + 0.3), shade(c, 0.22))
	ci.draw_rect(Rect2(x + w - 0.06, y - 0.3, 0.06, h - fh + 0.3), shade(c, -0.15))
	ci.draw_rect(Rect2(x, fy - 0.06, w, 0.06), shade(c, -0.2))
	ci.draw_rect(Rect2(x, fy, w, 0.07), Color(0, 0, 0, 0.18))
	if w * h >= 20 and kind != "shop" and kind != "mega":
		for k in int(w * h / 18):
			var ux := x + 0.5 + Town.hash2(k, int(x) * 3 + int(y)) * (w - 1.6)
			var uy := y + 0.1 + Town.hash2(int(y) + k, int(x)) * maxf(0.2, h - fh - 1.1)
			hvac(ci, ux, uy)
		# skylights and vent pipes
		for k in int(w * h / 24):
			var kx := x + 0.6 + Town.hash2(k + 50, int(x)) * (w - 1.8)
			var ky := y + 0.2 + Town.hash2(int(x) + 9, k + 50) * maxf(0.2, h - fh - 1.0)
			ci.draw_rect(Rect2(kx + 0.06, ky + 0.06, 0.6, 0.36), Color(0, 0, 0, 0.18))
			ci.draw_rect(Rect2(kx, ky, 0.6, 0.36), Color("#dfe4e7"))
			ci.draw_rect(Rect2(kx + 0.06, ky + 0.06, 0.48, 0.24), Color("#8fc4dc"))
			ci.draw_line(Vector2(kx + 0.1, ky + 0.26), Vector2(kx + 0.3, ky + 0.08), Color(1, 1, 1, 0.5), 0.03)
		for k in 2:
			var vp := Vector2(x + 0.5 + Town.hash2(k + 80, int(y)) * (w - 1.0), y + 0.05 + Town.hash2(int(y), k + 80) * maxf(0.1, h - fh - 0.6))
			ci.draw_circle(vp + Vector2(0.05, 0.05), 0.08, Color(0, 0, 0, 0.2))
			ci.draw_circle(vp, 0.08, Color("#8b9196"))
			ci.draw_circle(vp, 0.045, Color("#3a3f42"))
	elif not small and kind != "shop" and kind != "mega":
		hvac(ci, x + w * 0.62, y + 0.05, 0.55)
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

## Where the camera is looking, in tiles. Towers lean away from it, like looking down from above,
## so you see the side of a tower that faces you.
static var view_x := 56.0

## Skyscraper in a 3/4 view: the roof is lifted by its height (x) and shifted sideways (y),
## away from the middle of the screen.
static func sky_geom(b: Dictionary) -> Vector2:
	var H: float = b.ht * 0.42
	var lean := clampf((b.x + b.w / 2.0 - view_x) * 0.035, -0.3, 0.3)
	return Vector2(H, H * lean)

## Everything a tower covers on screen, base and roof.
static func sky_bounds(b: Dictionary) -> Rect2:
	var g := sky_geom(b)
	return Rect2(minf(b.x, b.x + g.y), b.y - g.x, b.w + absf(g.y), b.h + g.x)

static func sky_shadow(ci: CanvasItem, b: Dictionary) -> void:
	var g := sky_geom(b)
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	# a long shadow, softer and lighter the further it falls from the tower
	for k in 4:
		var L := g.x * (0.3 + k * 0.1)
		var gr := k * 0.12
		poly(ci, [Vector2(x + w, y - gr), Vector2(x + w + L + gr, y + L * 0.35 - gr), Vector2(x + w + L + gr, y + h + L * 0.35 + gr), Vector2(x + L, y + h + L * 0.35 + gr), Vector2(x, y + h), Vector2(x + w, y + h)], Color(0.06, 0.1, 0.18, 0.075))
	# contact shadow right at the foot
	ci.draw_rect(Rect2(x - 0.1, y + h - 0.05, w + 0.3, 0.2), Color(0.05, 0.08, 0.12, 0.18))

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
	var glass_b: bool = b.get("glass", false)
	# the side wall that faces the camera: the west one (in the light) when the tower leans east,
	# the east one (in shade) when it leans west
	var west := dx > 0.0
	var ex := x if west else x + w
	var side := shade(c, -0.14) if west else shade(c, -0.45)
	ci.draw_polygon(PackedVector2Array([Vector2(ex, y), Vector2(ex, y + h), Vector2(ex + dx, y + h - H), Vector2(ex + dx, y - H)]),
		PackedColorArray([side, shade(side, -0.15), shade(side, 0.08), shade(side, 0.12)]))
	var fl := 0.46
	var z := fl
	while z < H - 0.2:
		var sxp := ex + dx * (z / H)
		ci.draw_line(Vector2(sxp, y + h - z), Vector2(sxp, y - z), Color(0, 0, 0, 0.12), 0.03)
		z += fl
	if absf(dx) > 0.3:
		# windows down the side, one column per floor
		var ww := clampf(absf(dx) * fl / H * 0.55, 0.04, 0.3)
		var sg := Color(0.8, 0.93, 0.98, 0.5) if glass_b else Color(0.1, 0.17, 0.23, 0.5)
		z = 0.35 + fl * 0.5
		while z < H - 0.2:
			var px := ex + dx * (z / H)
			var d := 0.45
			while d < h - 0.3:
				ci.draw_rect(Rect2(px - ww / 2, y + h - d - z - 0.24, ww, 0.24), sg)
				d += 0.55
			z += fl
	# south face: shaded from the street up, floor bands, windows
	var face := PackedVector2Array([Vector2(x, y + h), Vector2(x + w, y + h), Vector2(x + w + dx, y + h - H), Vector2(x + dx, y + h - H)])
	var bot := shade(c, -0.34)
	var top := shade(c, -0.04)
	ci.draw_polygon(face, PackedColorArray([bot, shade(bot, -0.06), shade(top, -0.04), top]))
	z = 0.35 + fl - 0.06
	while z < H - 0.1:
		var k0 := z / H
		ci.draw_line(Vector2(x + dx * k0, y + h - z), Vector2(x + w + dx * k0, y + h - z), Color(1, 1, 1, 0.07) if glass_b else Color(0, 0, 0, 0.08), 0.04)
		z += fl
	var glass := Color(0.8, 0.93, 0.98, 0.72) if glass_b else Color(0.12, 0.2, 0.27, 0.5)
	b.wins = sky_windows(b)
	for r in b.wins:
		ci.draw_rect(r, glass)
		if not glass_b:
			ci.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 0.03), Color(1, 1, 1, 0.14))
			ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 0.05), Color(0.6, 0.75, 0.85, 0.25))
	if glass_b:
		# curtain wall: mullions and two diagonal sky reflections
		var cols: int = maxi(1, int((w - 0.3) / 0.5))
		for i in range(cols + 1):
			var u := float(i) / cols
			ci.draw_line(Vector2(x + u * w, y + h - 0.3), Vector2(x + u * w + dx, y + h - H), Color(0.2, 0.32, 0.4, 0.25), 0.025)
		for band in [[0.12, 0.9, 0.14], [0.55, 0.35, 0.08]]:
			var sx0: float = x + w * band[0]
			var bw: float = band[1]
			poly(ci, [Vector2(sx0, y + h - 0.3), Vector2(sx0 + bw, y + h - 0.3), Vector2(sx0 + bw + dx + 1.2, y + h - H), Vector2(sx0 + dx + 1.2, y + h - H)], Color(1, 1, 1, band[2]))
	# lobby: dark glass, a canopy and a warm light inside
	ci.draw_rect(Rect2(x, y + h - 0.32, w, 0.32), shade(c, -0.55))
	ci.draw_rect(Rect2(x + 0.15, y + h - 0.28, w - 0.3, 0.24), Color(0.1, 0.16, 0.2, 0.85))
	ci.draw_rect(Rect2(x + w / 2 - 0.45, y + h - 0.27, 0.9, 0.22), Color(1, 0.94, 0.78, 0.6))
	ci.draw_rect(Rect2(x + w / 2 - 0.6, y + h - 0.36, 1.2, 0.08), shade(c, 0.2))
	var outl := Color(0, 0, 0, 0.25)
	ci.draw_line(Vector2(x, y + h), Vector2(x + dx, y + h - H), outl, 0.04)
	ci.draw_line(Vector2(x + w, y + h), Vector2(x + w + dx, y + h - H), outl, 0.04)
	ci.draw_polyline(PackedVector2Array([Vector2(ex, y + h), Vector2(ex, y), Vector2(ex + dx, y - H)]), outl, 0.04)
	# a highlight down the lit corner
	var lit_x := x if west else x + w
	ci.draw_line(Vector2(lit_x, y + h), Vector2(lit_x + dx, y + h - H), Color(1, 1, 1, 0.14), 0.03)
	if b.get("logo", false):
		var lp := Vector2(x + w / 2 + dx * 0.9, y + h - H + 0.7)
		var cut: float = b.get("see", 0.0) * (1.0 - smoothstep(1.4, 2.8, lp.distance_to(b.get("hole", Vector2(-99, -99)))))
		text(ci, lp, "MARLOWE", 0.45, Color(1, 1, 1, 0.92 * (1.0 - cut)))
	var rx := x + dx
	var ry := y - H
	ci.draw_rect(Rect2(rx, ry, w, h), shade(c, 0.14))
	var rin := Rect2(rx + 0.18, ry + 0.18, w - 0.36, h - 0.36)
	ci.draw_polygon(PackedVector2Array([rin.position, Vector2(rin.end.x, rin.position.y), rin.end, Vector2(rin.position.x, rin.end.y)]),
		PackedColorArray([shade(c, -0.02), shade(c, -0.06), shade(c, -0.1), shade(c, -0.06)]))
	for k in int(w * h * 0.6):
		ci.draw_rect(Rect2(rin.position.x + Town.hash2(k, int(x) + 3) * rin.size.x, rin.position.y + Town.hash2(int(y) + 3, k) * rin.size.y, 0.05, 0.05), Color(0, 0, 0, 0.06))
	ci.draw_rect(Rect2(rin.position.x, rin.position.y, rin.size.x, 0.1), Color(0, 0, 0, 0.12))
	ci.draw_rect(Rect2(rin.position.x, rin.position.y, 0.1, rin.size.y), Color(0, 0, 0, 0.08))
	ci.draw_rect(Rect2(rx, ry, w, 0.06), shade(c, 0.4)); ci.draw_rect(Rect2(rx, ry, 0.06, h), shade(c, 0.4))
	ci.draw_rect(Rect2(rx, ry + h - 0.06, w, 0.06), shade(c, -0.2)); ci.draw_rect(Rect2(rx + w - 0.06, ry, 0.06, h), shade(c, -0.3))
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
			hvac(ci, ux, uy, 0.65)
		# a stair and elevator housing, and on some a water tank
		var hx := rx + w * 0.18
		var hy := ry + h * 0.55
		ci.draw_rect(Rect2(hx + 0.12, hy + 0.12, 1.1, 0.8), Color(0, 0, 0, 0.22))
		ci.draw_rect(Rect2(hx, hy, 1.1, 0.8), shade(c, 0.05))
		ci.draw_rect(Rect2(hx, hy, 1.1, 0.07), shade(c, 0.35))
		ci.draw_rect(Rect2(hx + 0.3, hy + 0.55, 0.3, 0.25), shade(c, -0.4))
		if Town.hash2(int(x), int(y) * 7) > 0.5 and w >= 6:
			var tc := Vector2(rx + w * 0.72, ry + h * 0.68)
			ci.draw_circle(tc + Vector2(0.12, 0.1), 0.42, Color(0, 0, 0, 0.22))
			ci.draw_circle(tc, 0.42, Color("#9b7a55"))
			ci.draw_circle(tc, 0.32, Color("#b8956a"))
			ci.draw_arc(tc, 0.37, 0, TAU, 20, Color("#5c4632"), 0.03)
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
const SKINS := ["#e0b48c", "#c68a5e", "#8d5a3b", "#f1c9a5", "#a86f4a"]
const HAIRS := ["#3a2a1e", "#1e1a18", "#8a5a35", "#c9a574", "#6b6f72"]

## Someone standing in town: Lou's regulars, guards, staff. rod makes them fish toward dir.
static func person(ci: CanvasItem, p: Vector2, dir: float, shirt: Color, hat: Color = Color(0, 0, 0, 0), rod := false, phase := 0.0, moving := false) -> void:
	var hs := Town.hash2(int(p.x * 3), int(p.y * 3))
	var look := { "shirt": shirt, "pants": Color("#22313a") if shirt.v < 0.45 else [Color("#4a5a6a"), Color("#c9b48a"), Color("#3d5a73"), Color("#6b5a48")][int(hs * 4)],
		"skin": Color(SKINS[int(hs * 5)]), "hair": Color(HAIRS[int(Town.hash2(int(p.y), int(p.x)) * 5)]), "hat": hat,
		"hat_kind": "wide" if rod else "cap" }
	if rod:
		var tip := p + Vector2(cos(dir) * 1.3, sin(dir) * 1.3 - 0.6)
		character(ci, p, dir, look, phase, false, 2, tip)
		# their line drops to a bobber out on the water
		var bp := p + Vector2.from_angle(dir) * 2.3 + Vector2(0, 0.1)
		if Town.is_water_t(Town.t_at(floori(bp.x), floori(bp.y))):
			var t := Time.get_ticks_msec() / 1000.0 + p.x
			var bb := bp + Vector2(0, sin(t * 2.5) * 0.03)
			ci.draw_polyline(PackedVector2Array([tip, (tip + bb) / 2 + Vector2(0, 0.35), bb]), Color(1, 1, 1, 0.5), 0.02)
			ellipse(ci, bb + Vector2(0, 0.06), 0.16, 0.05, Color(1, 1, 1, 0.3))
			ci.draw_circle(bb, 0.06, Color("#e2583e"))
			ci.draw_circle(bb + Vector2(0, -0.02), 0.03, Color.WHITE)
	else:
		character(ci, p, dir, look, phase, moving)

## A person in the 3/4 view. p is the middle of the body: the feet are 0.27 below it and the head 0.3 above.
## look: shirt, pants, skin, hair, hat (alpha 0 for none), hat_kind ("wide" or "cap"), and extras:
## dots (a loud fishing shirt), tie, lanyard, seated (in a boat: no legs).
## rod: 0 none, 1 carried on the shoulder, 2 fishing, with its tip at tip. bend bows it toward the line.
static func character(ci: CanvasItem, p: Vector2, face: float, look: Dictionary, phase := 0.0, moving := false, rod := 0, tip := Vector2.ZERO, bend := 0.0) -> void:
	var fx := cos(face)
	var fy := sin(face)
	var fwd := Vector2(fx, fy * 0.5)
	var stride := sin(phase) * 0.11 if moving else 0.0
	var pb := p + Vector2(0, -absf(sin(phase)) * 0.035 if moving else 0.0)
	var shirt: Color = look.shirt
	var skin: Color = look.get("skin", Color("#e0b48c"))
	var pants: Color = look.get("pants", Color("#4a5a6a"))
	var seated: bool = look.get("seated", false)
	if not seated:
		ellipse(ci, p + Vector2(0.03, 0.29), 0.3, 0.12, Color(0, 0, 0, 0.28))
		# legs, the far one first
		var lat := Vector2(0.085 * maxf(0.35, absf(fy)), 0)
		var legs := []
		for i in [-1, 1]:
			var foot: Vector2 = Vector2(p.x, p.y + 0.26) + lat * i + fwd * stride * i
			legs.append([foot, Vector2(pb.x, pb.y + 0.06) + lat * i * 0.9])
		legs.sort_custom(func(a, b): return a[0].y < b[0].y)
		for lg in legs:
			ci.draw_line(lg[1], lg[0], pants, 0.1)
			ci.draw_line(lg[1] + Vector2(-0.03, 0), lg[0] + Vector2(-0.03, 0), shade(pants, 0.15), 0.025)
			ellipse(ci, lg[0] + Vector2(fx * 0.03, 0.015), 0.065, 0.04, Color("#2a2420"))
	# the far arm goes behind the body
	var grip := pb + fwd * 0.22 + Vector2(0, -0.04)
	var arms := []
	for i in [-1, 1]:
		var sh: Vector2 = pb + Vector2(i * 0.165, -0.1)
		var hand: Vector2
		if rod == 2: hand = grip + Vector2(-fy, fx) * 0.035 * i
		elif rod == 1 and i == 1: hand = sh + Vector2(0.02, -0.04)
		else: hand = sh + Vector2(i * 0.02, 0.17) - fwd * stride * i * 0.9
		arms.append([sh, hand, i])
	var far_i := 1 if fx < 0 else -1
	for ar in arms:
		if ar[2] == far_i and rod != 2: _arm(ci, ar[0], ar[1], shirt, skin)
	# body: a rounded trunk, lit from the top left
	var tor := PackedVector2Array([pb + Vector2(-0.17, -0.14), pb + Vector2(0.17, -0.14), pb + Vector2(0.14, 0.09), pb + Vector2(-0.14, 0.09)])
	ci.draw_polygon(tor, PackedColorArray([shade(shirt, 0.12), shirt, shade(shirt, -0.2), shade(shirt, -0.08)]))
	ci.draw_circle(pb + Vector2(-0.15, -0.11), 0.045, shade(shirt, 0.1))
	ci.draw_circle(pb + Vector2(0.15, -0.11), 0.045, shade(shirt, -0.05))
	if seated: ci.draw_rect(Rect2(pb.x - 0.14, pb.y + 0.06, 0.28, 0.06), pants)
	else: ci.draw_rect(Rect2(pb.x - 0.14, pb.y + 0.05, 0.28, 0.05), shade(pants, -0.2))
	if look.get("dots", false):
		for d in [Vector2(-0.08, -0.07), Vector2(0.07, 0.0), Vector2(0.02, -0.1), Vector2(-0.06, 0.04), Vector2(0.1, -0.09)]:
			ci.draw_circle(pb + d, 0.025, Color("#f2b134"))
			ci.draw_circle(pb + d + Vector2(0.015, 0.012), 0.012, Color("#fbf3e2"))
	if look.get("tie", false):
		poly(ci, [pb + Vector2(-0.06, -0.14), pb + Vector2(0.06, -0.14), pb + Vector2(0, -0.04)], Color.WHITE)
		ci.draw_line(pb + Vector2(0, -0.12), pb + Vector2(0, 0.04), Color("#e2583e"), 0.04)
	if look.get("lanyard", false):
		ci.draw_polyline(PackedVector2Array([pb + Vector2(-0.07, -0.14), pb + Vector2(0, -0.02), pb + Vector2(0.07, -0.14)]), Color("#2b7ea6"), 0.025)
		ci.draw_rect(Rect2(pb.x - 0.05, pb.y - 0.03, 0.1, 0.07), Color.WHITE)
	for ar in arms:
		if ar[2] != far_i or rod == 2: _arm(ci, ar[0], ar[1], shirt, skin)
	if rod == 2 and fy < -0.2: _rod(ci, grip, tip, bend)
	# head: neck, hair at the back, face toward where they look
	var hc := pb + Vector2(0, -0.3)
	ci.draw_rect(Rect2(hc.x - 0.04, hc.y + 0.08, 0.08, 0.08), shade(skin, -0.15))
	var hair: Color = look.get("hair", Color("#3a2a1e"))
	ci.draw_circle(hc, 0.145, skin)
	ci.draw_circle(hc - fwd * 0.05 + Vector2(0, -0.035), 0.13, hair)
	if fy > -0.55:
		ci.draw_circle(hc + fwd * 0.04 + Vector2(0, 0.02), 0.11, skin)
		if fy > -0.25:
			var side := 1.0 - absf(fx) * 0.55
			for i in [-1, 1]:
				ci.draw_circle(hc + Vector2(fx * 0.07 + i * 0.045 * side, 0.025 + fy * 0.02), 0.017, Color("#22201e"))
	ci.draw_circle(hc + Vector2(-0.05, -0.05), 0.04, Color(1, 1, 1, 0.12))
	var hat: Color = look.get("hat", Color(0, 0, 0, 0))
	if hat.a > 0:
		if look.get("hat_kind", "wide") == "cap":
			ci.draw_circle(hc + Vector2(0, -0.04), 0.135, hat)
			ellipse(ci, hc + fwd * 0.14 + Vector2(0, -0.03), 0.1, 0.055, shade(hat, -0.15), face)
			ci.draw_circle(hc + Vector2(-0.04, -0.09), 0.05, shade(hat, 0.2))
		else:
			ellipse(ci, hc + Vector2(0.01, -0.035), 0.26, 0.14, Color(0, 0, 0, 0.12))
			ellipse(ci, hc + Vector2(0, -0.05), 0.25, 0.135, hat)
			ellipse(ci, hc + Vector2(0, -0.09), 0.14, 0.09, shade(hat, 0.12))
			ci.draw_arc(hc + Vector2(0, -0.075), 0.14, 0.15, PI - 0.15, 10, shade(hat, -0.35), 0.025)
	if rod == 2 and fy >= -0.2: _rod(ci, grip, tip, bend)
	elif rod == 1:
		# over the shoulder, tip up and back
		ci.draw_line(pb + Vector2(0.12, 0.02), pb + Vector2(0.32 - fx * 0.22, -0.95 - fy * 0.08), Color("#3d2b1a"), 0.04)
		ci.draw_circle(pb + Vector2(0.15, -0.06), 0.035, Color("#9aa6ad"))

static func _arm(ci: CanvasItem, sh: Vector2, hand: Vector2, shirt: Color, skin: Color) -> void:
	var mid := sh.lerp(hand, 0.45)
	ci.draw_line(sh, mid, shade(shirt, -0.08), 0.08)
	ci.draw_line(mid, hand, skin, 0.06)
	ci.draw_circle(hand, 0.038, skin)

static func _rod(ci: CanvasItem, grip: Vector2, tip: Vector2, bend: float) -> void:
	var mid := (grip + tip) / 2 + Vector2(0, -0.12 + bend * 0.35)
	var pts := PackedVector2Array()
	for i in 9: pts.append(_quad(grip, mid, tip, i / 8.0))
	ci.draw_line(grip - (pts[1] - grip) * 0.6, grip, Color("#2a2420"), 0.07)
	ci.draw_polyline(pts.slice(0, 5), Color("#3d2b1a"), 0.05)
	ci.draw_polyline(pts.slice(4), Color("#4d3a26"), 0.032)
	ci.draw_circle(grip + (pts[1] - grip) * 0.4 + Vector2(0, 0.03), 0.04, Color("#9aa6ad"))

static func rrect(c: Vector2, hw: float, hh: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in 4:
		var cc := c + Vector2(hw - r if q == 0 or q == 3 else -hw + r, hh - r if q < 2 else -hh + r)
		for i in 4:
			var a := q * PI / 2 + i * PI / 6
			pts.append(cc + Vector2(cos(a), sin(a)) * r)
	return pts

static func car(ci: CanvasItem, p: Vector2, rot: float, col: Color, L := 1.75, W := 0.85) -> void:
	ci.draw_set_transform(p, rot, Vector2.ONE)
	var sh := Vector2(0.12, 0.1).rotated(-rot)
	for k in 3: ci.draw_colored_polygon(rrect(sh, L / 2 + 0.04 * k, W / 2 + 0.04 * k, 0.2), Color(0, 0, 0, 0.1))
	# wheels peeking out, body, then a lighter hood and roof
	for wx in [-L * 0.3, L * 0.3]:
		for wy in [-W / 2, W / 2]: ci.draw_rect(Rect2(wx - 0.13, wy - 0.06, 0.26, 0.12), Color("#1d1f21"))
	ci.draw_colored_polygon(rrect(Vector2.ZERO, L / 2, W / 2, 0.18), shade(col, -0.18))
	ci.draw_colored_polygon(rrect(Vector2(0, -0.02), L / 2 - 0.04, W / 2 - 0.06, 0.16), col)
	ci.draw_colored_polygon(rrect(Vector2(L * 0.32, 0), L * 0.14, W * 0.38, 0.1), shade(col, 0.1))
	# windshield, roof, rear window
	ci.draw_colored_polygon(PackedVector2Array([Vector2(L * 0.2, -W * 0.38), Vector2(L * 0.08, -W * 0.36), Vector2(L * 0.08, W * 0.36), Vector2(L * 0.2, W * 0.38)]), Color(0.1, 0.16, 0.22, 0.85))
	ci.draw_colored_polygon(rrect(Vector2(-L * 0.08, 0), L * 0.16, W * 0.35, 0.08), shade(col, 0.14))
	ci.draw_line(Vector2(-L * 0.2, -W * 0.25), Vector2(L * 0.05, -W * 0.25), Color(1, 1, 1, 0.25), 0.04)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.24, -W * 0.36), Vector2(-L * 0.34, -W * 0.33), Vector2(-L * 0.34, W * 0.33), Vector2(-L * 0.24, W * 0.36)]), Color(0.1, 0.16, 0.22, 0.85))
	ci.draw_line(Vector2(L * 0.19, -W * 0.3), Vector2(L * 0.1, W * 0.1), Color(1, 1, 1, 0.3), 0.03)
	# lights and mirrors
	for sy in [-1, 1]:
		ci.draw_rect(Rect2(L / 2 - 0.08, sy * W * 0.3 - 0.07, 0.07, 0.14), Color("#fff4cf"))
		ci.draw_rect(Rect2(-L / 2 + 0.01, sy * W * 0.3 - 0.07, 0.06, 0.14), Color("#c8322a"))
		ci.draw_rect(Rect2(L * 0.1, sy * (W / 2 + 0.02) - 0.03, 0.1, 0.06), shade(col, -0.25))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const CAR_COLORS := ["#e2583e", "#f1f1ee", "#2b7ea6", "#3d4a52", "#f2b134", "#9aa6ad", "#5bb5a9", "#7a3b3b", "#f4efe4", "#22313a"]

## A street lamp in the 3/4 view: its foot is at p, its light hangs over the street.
static func lamp_post(ci: CanvasItem, p: Vector2) -> void:
	var top := p + Vector2(0, -1.15)
	ci.draw_line(p + Vector2(0.04, 0.02), p + Vector2(0.75, 0.42), Color(0, 0, 0, 0.18), 0.07)
	ci.draw_circle(p + Vector2(0.78, 0.45), 0.12, Color(0, 0, 0, 0.12))
	ellipse(ci, p + Vector2(0, 0.02), 0.11, 0.06, Color("#3d4a52"))
	ci.draw_line(p, top, Color("#4d585f"), 0.07)
	ci.draw_line(p + Vector2(-0.015, 0), top + Vector2(-0.015, 0), Color(1, 1, 1, 0.18), 0.02)
	ci.draw_line(top, top + Vector2(0.28, -0.05), Color("#4d585f"), 0.05)
	ellipse(ci, top + Vector2(0.34, -0.02), 0.16, 0.07, Color("#3d4a52"))
	ellipse(ci, top + Vector2(0.34, 0.01), 0.11, 0.04, Color("#fff2c8"))

## A boat tied up in a slip, bow to the north. t bobs it on the water.
static func moored_boat(ci: CanvasItem, p: Vector2, t: float, col: Color, sail := false) -> void:
	var bob := sin(t * 1.3 + p.x) * 0.04
	var rot := sin(t * 0.9 + p.x * 2.0) * 0.03
	var L := 3.0
	var W := 1.15
	ci.draw_set_transform(p + Vector2(0.18, 0.22), rot, Vector2.ONE)
	ci.draw_colored_polygon(_hull(L, W * 1.05), Color(0.02, 0.1, 0.16, 0.25))
	ci.draw_set_transform(p + Vector2(0, bob), rot, Vector2.ONE)
	# water stirring around the hull
	ci.draw_arc(Vector2(0, L * 0.1), W * 0.75, 0, TAU, 20, Color(1, 1, 1, 0.12 + 0.06 * sin(t * 2.0 + p.x)), 0.05)
	ci.draw_colored_polygon(_hull(L, W), Color("#f4f4f0"))
	ci.draw_colored_polygon(_hull(L * 0.92, W * 0.84), Color("#e4e6e3"))
	ci.draw_polyline(_hull(L, W), col, 0.06, true)
	if sail:
		ci.draw_rect(Rect2(-0.32, L * 0.08, 0.64, 0.75), Color("#d8cdb4"))
		ci.draw_rect(Rect2(-0.26, L * 0.12, 0.52, 0.3), Color(0.12, 0.2, 0.27, 0.7))
		ci.draw_line(Vector2(0, -L * 0.18), Vector2(0, L * 0.38), Color("#b3a68a"), 0.09)
		ci.draw_line(Vector2(0, -L * 0.18), Vector2(0, L * 0.38), col, 0.05)
		ci.draw_circle(Vector2(0, -L * 0.18), 0.09, Color("#8b9196"))
		ci.draw_line(Vector2(0, -L * 0.18), Vector2(0, -L * 0.48), Color(0.3, 0.3, 0.3, 0.6), 0.015)
	else:
		# center console with its windshield, a cooler seat and the outboard
		ci.draw_rect(Rect2(-0.28, -L * 0.02, 0.56, 0.5), Color("#cfd3d1"))
		ci.draw_rect(Rect2(-0.26, -L * 0.04, 0.52, 0.12), Color(0.12, 0.2, 0.27, 0.75))
		ci.draw_rect(Rect2(-0.2, L * 0.16, 0.4, 0.3), col)
		ci.draw_rect(Rect2(-0.3, -L * 0.05, 0.6, 0.06), Color("#9aa3a8"))
	ci.draw_rect(Rect2(-0.18, L * 0.47, 0.36, 0.3), Color("#2a2e31"))
	ci.draw_rect(Rect2(-0.12, L * 0.49, 0.24, 0.08), Color("#5a6166"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _hull(L: float, W: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + i * PI / 8
		pts.append(Vector2(cos(a) * W / 2, -L * 0.2 + sin(a) * L * 0.3))
	pts.append(Vector2(W / 2, L * 0.48)); pts.append(Vector2(-W / 2, L * 0.48))
	return pts

## A gull seen from above: flap goes from -1 (wings down) to 1 (up).
static func gull(ci: CanvasItem, p: Vector2, dir: float, flap: float, s := 1.0) -> void:
	ci.draw_set_transform(p, dir, Vector2(s, s))
	var span := 0.55 * (0.7 + 0.3 * absf(flap))
	var bend := flap * 0.12
	for sd in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(0.06, 0), Vector2(0.02 - bend, sd * span * 0.5), Vector2(-0.16 - bend, sd * span), Vector2(-0.12, sd * span * 0.45), Vector2(-0.1, 0)])
		ci.draw_colored_polygon(wing, Color("#f4f6f6"))
		ci.draw_line(Vector2(-0.16 - bend, sd * span), Vector2(-0.12 - bend * 0.5, sd * span * 0.75), Color("#3d4a52"), 0.05)
	ellipse(ci, Vector2.ZERO, 0.2, 0.06, Color("#ffffff"))
	ci.draw_circle(Vector2(0.16, 0), 0.05, Color("#f4f6f6"))
	ci.draw_line(Vector2(0.2, 0), Vector2(0.27, 0), Color("#f2b134"), 0.03)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func lamp_head(p: Vector2) -> Vector2: return p + Vector2(0.34, -1.14)

static func fish_shadow(ci: CanvasItem, p: Vector2, dir: float, L: float, alpha: float, glow := false, wob := 0.0) -> void:
	var col := Color(0.47, 1.0, 0.67, alpha) if glow else Color(0.03, 0.11, 0.17, alpha)
	ci.draw_set_transform(p, dir, Vector2.ONE)
	ellipse(ci, Vector2.ZERO, L * 0.5, L * 0.17, col)
	var wag := sin(wob) * L * 0.08
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.4, 0), Vector2(-L * 0.72, -L * 0.17 + wag), Vector2(-L * 0.72, L * 0.17 + wag)]), col)
	ellipse(ci, Vector2(L * 0.02, -L * 0.16), L * 0.12, L * 0.05, col, -0.4)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
