class_name ItemIcons
extends RefCounted
## Little pictures of the gear, bait and catches for the shop, the marina and the HUD.
## Every icon is drawn in code on a 64 x 64 design square, with a dark ink outline,
## and scaled to whatever rect it's given.

const INK := Color("#22313a")
const PAPER := Color("#fbf3e2")
const SUN := Color("#f2b134")
const CORAL := Color("#e2583e")
const TEAL := Color("#13807b")
const SEA := Color("#2b7ea6")
const SILVER := Color("#cfd8dc")
const OW := 2.0 # outline width

## The icon for a gear item, bait or catch. Gear ids and bait ids both work ("bait" and
## "shrimp" are the same picture). rod0..rod4 are the five rods.
static func draw(ci: CanvasItem, id: String, r: Rect2, t := 0.0) -> void:
	var s := minf(r.size.x, r.size.y) / 64.0
	ci.draw_set_transform(r.position + (r.size - Vector2(64, 64) * s) / 2.0, 0.0, Vector2(s, s))
	match id:
		"rod0": _rod(ci, Color("#c9a55c"), Color("#8a8f94"), Color("#3a3a3a"), 3.2, "spincast", "tape")
		"rod1", "rod": _rod(ci, Color("#3f7d4e"), SUN, Color("#c79a62"), 3.4, "spin", "")
		"rod2": _rod(ci, Color("#2b2f36"), SEA, Color("#d9cbb0"), 3.0, "spin", "gloss")
		"rod3": _rod(ci, Color("#efe6d2"), SUN, Color("#c79a62"), 3.6, "spin", "legend", t)
		"rod4": _rod(ci, Color("#2a3e5c"), SUN, Color("#3a3a3a"), 5.0, "conv", "big")
		"bait", "shrimp": _shrimp(ci, Color("#f08a6a"))
		"worms": _worms(ci)
		"lure": _lure(ci)
		"hotdog": _hotdog(ci)
		"bread": _bread(ci)
		"squid": _squid(ci)
		"cooler": _cooler(ci)
		"mcooler": _mcooler(ci)
		"camera": _phone(ci)
		"polo": _polo(ci)
		"lanyard": _lanyard(ci)
		"flashlight": _flashlight(ci)
		"waders": _waders(ci)
		"geiger": _geiger(ci)
		"prybar": _prybar(ci)
		"kayak": _kayak(ci)
		"bigtank": _tank(ci)
		"suit": _suit(ci)
		"skiff": _skiff(ci)
		"shades": _shades(ci)
		"junk": _junk(ci)
		"p_spoon": _spoon_part(ci)
		"p_caps": _caps(ci)
		"p_beads": _beads(ci)
		"p_feather": _feather(ci, Vector2(32, 32), 1.0)
		"p_wire": _wire(ci)
		"p_glow": _glowstick(ci, t)
		"spoon": _spoon_lure(ci)
		"p_glass": _blank_part(ci, Color("#c4b85a"))
		"p_graphite": _blank_part(ci, Color("#2b2f36"))
		"p_reel": _reel_part(ci, false)
		"p_bigreel": _reel_part(ci, true)
		"p_cork": _corks(ci)
		"p_foam": _foam(ci)
		"p_tape": _tape(ci)
		"popper": _popper(ci)
		"jig": _jig(ci)
		"glowlure": _glow_lure(ci, t)
		_: _fish(ci, SILVER)
	ci.draw_set_transform(Vector2.ZERO)

## A catch from the cooler: a fish tinted for its kind, gold with a star for a legend,
## or a soggy bit of junk.
static func draw_catch(ci: CanvasItem, c: Dictionary, r: Rect2) -> void:
	if c.get("junk", false):
		if not JunkArt.draw(ci, str(c.get("n", "")), r.grow(-r.size.x * 0.04), Time.get_ticks_msec() / 1000.0): draw(ci, "junk", r)
		return
	var s := minf(r.size.x, r.size.y) / 64.0
	ci.draw_set_transform(r.position + (r.size - Vector2(64, 64) * s) / 2.0, 0.0, Vector2(s, s))
	if c.get("legend", false):
		_fish(ci, Color("#e9b23a"))
		_star(ci, Vector2(52, 14), 8, Color("#ffd75e"))
	else: _fish(ci, fish_color(str(c.get("n", ""))))
	ci.draw_set_transform(Vector2.ZERO)

static func fish_color(n: String) -> Color:
	var keys := [["Perch", "#c8b84a"], ["Walleye", "#b8a050"], ["Sauger", "#a89a68"], ["Trout", "#b8a878"], ["Sturgeon", "#7a7a6a"], ["Ghost", "#d8d8cc"], ["Drum", "#b8b8b0"], ["Carp", "#b0a060"],
		["Muskellunge", "#9aa070"], ["Mayor", "#9aa070"], ["Rivet", "#8a7848"], ["Pumpkinseed", "#c8a050"], ["Crappie", "#aab4a6"], ["Koi", "#f07b3a"], ["Goldfish", "#f29a2e"], ["Ogon", "#e8e4d8"], ["Arowana", "#d7dde0"], ["Peacock", "#b9c23e"],
		["Bass", "#6f9a4c"], ["Bluegill", "#5d86a0"], ["Catfish", "#8a7b6a"], ["Tilapia", "#9aa4a8"], ["Glow", "#9be15d"],
		["Redfish", "#c8643c"], ["Snapper", "#d0705a"], ["Mahi", "#4fb06a"], ["Tuna", "#2f4a7a"], ["Sailfish", "#3a62a8"],
		["Shark", "#8796a0"], ["Grouper", "#7a6a4a"], ["Gar", "#7d8a52"], ["Bowfin", "#6b7a4a"], ["Snakehead", "#6a6a48"],
		["Eel", "#5a5f48"], ["Python", "#8a7a4a"], ["Gator", "#5a7a3a"], ["Crab", "#3f6fa8"], ["Rat", "#7a7470"],
		["Stingray", "#7a6f62"], ["Cichlid", "#b4a04a"], ["Oscar", "#c8742e"], ["Pacu", "#8a8f98"], ["Carp", "#b09a5a"],
		["Sheepshead", "#b8bcb8"], ["Barracuda", "#a8b4bc"], ["Seatrout", "#a7aa9a"], ["Kingfish", "#9aa8b4"], ["Jack", "#b4b48a"]]
	for k in keys:
		if n.contains(k[0]): return Color(k[1])
	return Color("#b8c4ca")

# ---------- helpers ----------

static func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, lw := OW) -> void:
	ci.draw_colored_polygon(pts, fill)
	var c := pts.duplicate(); c.append(pts[0])
	ci.draw_polyline(c, INK, lw, true)

static func _rr(ci: CanvasItem, c: Vector2, hw: float, hh: float, rad: float, fill: Color, lw := OW) -> void:
	_shape(ci, Art.rrect(c, hw, hh, rad), fill, lw)

static func _el(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, rot := 0.0, lw := OW) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	if lw > 0: _shape(ci, pts, fill, lw)
	else: ci.draw_colored_polygon(pts, fill)

## A thick stroke with an ink outline.
static func _stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, INK, w + OW * 2, true)
	ci.draw_polyline(pts, col, w, true)
	ci.draw_circle(pts[0], (w + OW * 2) / 2, INK); ci.draw_circle(pts[0], w / 2, col)
	ci.draw_circle(pts[pts.size() - 1], (w + OW * 2) / 2, INK); ci.draw_circle(pts[pts.size() - 1], w / 2, col)

static func _arc(c: Vector2, rad: float, a0: float, a1: float, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1: pts.append(c + Vector2(cos(lerpf(a0, a1, float(i) / n)), sin(lerpf(a0, a1, float(i) / n))) * rad)
	return pts

static func _star(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (rad if i % 2 == 0 else rad * 0.45))
	_shape(ci, pts, col, 1.5)

static func _sparkle(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4
		pts.append(c + Vector2(cos(a), sin(a)) * (rad if i % 2 == 0 else rad * 0.22))
	ci.draw_colored_polygon(pts, col)

# ---------- rods ----------

## A rod laid corner to corner: handle bottom left, tip top right, reel hanging below.
static func _rod(ci: CanvasItem, blank: Color, wrap: Color, handle: Color, thick: float, reel: String, extra: String, t := 0.0) -> void:
	var B := Vector2(7, 57)
	var T := Vector2(59, 7) if extra != "big" else Vector2(55, 11)
	var d := (T - B).normalized()
	var n := Vector2(-d.y, d.x) # points down-right, "under" the rod
	var L := B.distance_to(T)
	var hl := 15.0 if extra != "big" else 17.0
	var H := B + d * hl
	# fishing line from the tip, with a little hook
	var hook := T + Vector2(2.5, 13)
	ci.draw_line(T, hook, Color(INK, 0.55), 1.0, true)
	ci.draw_polyline(_arc(hook + Vector2(-2, 1), 2.2, 0, PI, 6), INK, 1.4, true)
	# the blank, tapering to the tip
	var w0 := thick * 1.35; var w1 := 1.8
	var ow := 1.4
	var outer := PackedVector2Array([H + n * (w0 / 2 + ow), T + n * (w1 / 2 + ow) + d * ow, T - n * (w1 / 2 + ow) + d * ow, H - n * (w0 / 2 + ow)])
	ci.draw_colored_polygon(outer, INK)
	ci.draw_colored_polygon(PackedVector2Array([H + n * w0 / 2, T + n * w1 / 2, T - n * w1 / 2, H - n * w0 / 2]), blank)
	if extra == "gloss": ci.draw_line(H - n * w0 * 0.2, T - n * 0.2, Color(1, 1, 1, 0.35), 0.8, true)
	if extra == "legend": ci.draw_line(H - n * w0 * 0.15, T, Color(1, 1, 1, 0.6), 0.8, true)
	# guides and their thread wraps
	var gf := [0.46, 0.63, 0.79, 0.93] if extra != "big" else [0.48, 0.68, 0.88]
	for f in gf:
		var p: Vector2 = B + d * L * f
		var w: float = lerpf(w0, w1, (L * f - hl) / (L - hl))
		ci.draw_line(p - n * (w / 2 + 0.5) - d * 1.4, p + n * (w / 2 + 0.5) - d * 1.4, wrap, 1.6)
		ci.draw_line(p - n * (w / 2 + 0.5) + d * 1.4, p + n * (w / 2 + 0.5) + d * 1.4, wrap, 1.6)
		var gr := 1.6 if extra != "big" else 2.3
		var gc: Vector2 = p + n * (w / 2 + gr + 0.6)
		ci.draw_line(p + n * w / 2, gc - n * gr, INK, 1.2)
		ci.draw_circle(gc, gr + 0.9, INK)
		ci.draw_circle(gc, gr, SILVER if extra != "big" else SUN)
		ci.draw_circle(gc, gr * 0.45, INK if extra != "big" else Color("#7a5a1a"))
	# the handle
	var hw := thick * 1.55 + (1.0 if extra == "big" else 0.0)
	ci.draw_line(B - d * 1.5, H + d * 1.0, INK, hw + OW * 2)
	ci.draw_line(B - d * 0.5, H, handle, hw)
	if handle == Color("#c79a62"): # cork speckles
		for i in 6:
			var p := B.lerp(H, (i + 0.5) / 6.0) + n * (0.9 if i % 2 == 0 else -0.9)
			ci.draw_circle(p, 0.6, Color("#9c7444"))
	if extra == "tape":
		for f in [0.5, 0.64]:
			var p: Vector2 = B + d * L * f
			ci.draw_line(p - n * 3.2 - d * 1.8, p + n * 3.2 + d * 1.8, Color("#9aa4aa"), 3.2)
			ci.draw_line(p - n * 3.2 - d * 1.8, p + n * 3.2 + d * 1.8, Color(INK, 0.35), 0.8)
	# reel seat and the butt cap
	ci.draw_line(H - d * 0.5, H + d * 4.5, INK, thick * 1.4 + OW * 2)
	ci.draw_line(H, H + d * 4, SILVER if extra != "big" else SUN, thick * 1.4)
	if extra == "big":
		_el(ci, B - d * 1.0, 4.5, 3.2, SILVER, d.angle())
		ci.draw_line(B - d * 1.0 - n * 3, B - d * 1.0 + n * 3, INK, 1.2)
	else:
		_el(ci, B - d * 0.8, 2.6, 2.2, Color("#3a3a3a"), d.angle())
	var R := H + d * 2.0
	match reel:
		"spin":
			var foot := R + n * 6
			ci.draw_line(R, foot, INK, 3.4); ci.draw_line(R, foot, SILVER, 1.6)
			var rc := foot + n * 5
			# crank handle out the side, then the body and the silver spool facing the tip
			ci.draw_line(rc - d * 1, rc - d * 7 + n * 3, INK, 1.8)
			_el(ci, rc - d * 7.5 + n * 3.5, 1.9, 1.9, Color("#3a3a3a"), 0.0, 1.0)
			_el(ci, rc - d * 1.5, 5.0, 5.6, Color("#7d8a93"), d.angle(), 1.6)
			_el(ci, rc + d * 3.0, 2.6, 5.2, SILVER, d.angle(), 1.4)
			ci.draw_line(rc + d * 3.0 - n * 4, rc + d * 3.0 + n * 4, Color("#8a959c"), 1.0)
		"spincast":
			var c := R - n * 6
			_el(ci, c, 7.2, 5.4, Color("#1f2a30"), d.angle())
			_el(ci, c + d * 3.5, 3.0, 4.2, SILVER, d.angle(), 1.4)
			ci.draw_circle(c - d * 4.5, 2.0, INK); ci.draw_circle(c - d * 4.5, 1.2, Color("#9aa4aa"))
			ci.draw_line(c, c + n * 5, INK, 1.6); ci.draw_circle(c + n * 6, 1.8, INK)
		"conv":
			var c := R - n * 8 + d * 1.0
			_rr(ci, c, 7.5, 6.0, 2.5, SUN)
			ci.draw_line(c - Vector2(6, 0), c + Vector2(6, 0), Color("#b07d1a"), 1.4)
			ci.draw_line(c + Vector2(7, 2), c + Vector2(12, 8), INK, 2.2)
			_el(ci, c + Vector2(12.5, 8.5), 2.4, 1.8, Color("#3a3a3a"))
			ci.draw_line(R - n * 2, R, INK, 2.0)
	if extra == "legend":
		var tw := 0.6 + 0.4 * sin(t * 3.0)
		_sparkle(ci, T + Vector2(-8, 10), 4.5 * tw + 1.5, Color("#ffd75e"))
		_sparkle(ci, B.lerp(T, 0.62) + Vector2(-9, -6), 3.2, Color("#ffd75e"))
		_sparkle(ci, Vector2(14, 14), 3.8 * (1.4 - tw) + 0.6, Color("#ffe9a6"))

# ---------- bait ----------

static func _shrimp(ci: CanvasItem, col: Color) -> void:
	var c := Vector2(30, 40)
	var R := 15.0
	var segs := 7
	var pts := []
	for i in segs:
		var a := lerpf(PI * 1.02, PI * 2.05, float(i) / (segs - 1))
		pts.append(c + Vector2(cos(a), sin(a)) * R)
	# legs and antennae under everything
	for i in [1, 2, 3, 4]:
		var p: Vector2 = pts[i]
		var dn := (p - c).normalized()
		ci.draw_line(p - dn * 4, p - dn * 9 + Vector2(-1, 2), INK, 1.2, true)
	var head: Vector2 = pts[0]
	ci.draw_polyline(_arc(head + Vector2(18, 4), 20, PI * 1.05, PI * 1.45, 10), INK, 1.0, true)
	ci.draw_polyline(_arc(head + Vector2(22, 10), 24, PI * 1.08, PI * 1.38, 10), INK, 1.0, true)
	# tail fan
	var tail: Vector2 = pts[segs - 1]
	_shape(ci, PackedVector2Array([tail + Vector2(-2, 0), tail + Vector2(4, 9), tail + Vector2(9, 5), tail + Vector2(2, -2)]), Art.shade(col, -0.1), 1.5)
	# body segments, tail first so the head sits on top
	for i in range(segs - 1, -1, -1):
		var rr := lerpf(8.0, 4.2, float(i) / (segs - 1))
		var p: Vector2 = pts[i]
		_el(ci, p, rr, rr * 0.92, col if i % 2 == 0 else Art.shade(col, 0.12), 0.0, 1.6)
		ci.draw_arc(p, rr * 0.6, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.45), 1.2, true)
	ci.draw_circle(head + Vector2(-2, -2), 1.8, INK)
	ci.draw_circle(head + Vector2(-2.5, -2.6), 0.6, Color.WHITE)

static func _worms(ci: CanvasItem) -> void:
	# a dirt cup
	_shape(ci, PackedVector2Array([Vector2(14, 34), Vector2(50, 34), Vector2(46, 58), Vector2(18, 58)]), Color("#e9dcc0"))
	ci.draw_line(Vector2(16, 44), Vector2(48, 44), CORAL, 3.0)
	_el(ci, Vector2(32, 34), 18, 4.5, Color("#5a3d27"))
	for p in [Vector2(24, 33), Vector2(38, 35), Vector2(31, 32)]: ci.draw_circle(p, 1.0, Color("#3d2817"))
	var w1 := PackedVector2Array(); var w2 := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		w1.append(Vector2(24 + 4 * sin(f * 7.0), 33 - f * 26))
		w2.append(Vector2(38 + f * 12, 33 - f * 18 + 3 * sin(f * 9.0)))
	_stroke(ci, w1, Color("#e88a95"), 4.2)
	_stroke(ci, w2, Color("#d9737f"), 4.0)
	for p in [w1[3], w1[7], w2[4], w2[8]]: ci.draw_circle(p, 1.0, Color("#b85a66"))

static func _lure(ci: CanvasItem) -> void:
	var top := Vector2(28, 5)
	ci.draw_arc(top, 3.0, 0, TAU, 12, INK, 1.6, true)
	ci.draw_line(top + Vector2(0, 3), Vector2(30, 46), INK, 1.6, true)
	# the spinning blade, flashing
	_el(ci, Vector2(41, 19), 7.0, 12.0, SILVER, 0.45)
	_el(ci, Vector2(40, 17), 3.0, 6.5, Color(1, 1, 1, 0.75), 0.45, 0)
	ci.draw_line(Vector2(29, 12), Vector2(36, 10), INK, 1.4, true)
	# beads and body
	ci.draw_circle(Vector2(29, 24), 3.6, INK); ci.draw_circle(Vector2(29, 24), 2.6, CORAL)
	ci.draw_circle(Vector2(29.3, 29.5), 3.6, INK); ci.draw_circle(Vector2(29.3, 29.5), 2.6, SUN)
	_el(ci, Vector2(29.8, 38), 4.2, 7.0, Color("#d6a43a"), -0.04)
	ci.draw_line(Vector2(28.2, 33), Vector2(28.8, 42), Color(1, 1, 1, 0.55), 1.2)
	# a red tuft and the treble hook
	for i in 7:
		var a := lerpf(-0.5, 0.5, i / 6.0)
		ci.draw_line(Vector2(30, 45), Vector2(30, 45) + Vector2(sin(a), cos(a)) * 11, Color("#d23c3c"), 1.6, true)
	for sx in [-1, 1]:
		var hc := Vector2(30 + sx * 4, 54)
		var hp := _arc(hc, 4.0, PI if sx > 0 else 0.0, 0.0 if sx > 0 else PI, 6)
		hp.append(hc + Vector2(sx * 4, -4))
		ci.draw_line(Vector2(30, 46), Vector2(30, 54), INK, 1.8)
		ci.draw_polyline(hp, INK, 1.8, true)
	ci.draw_polyline(_arc(Vector2(33, 58), 3.0, PI, PI * 0.5, 4), INK, 1.8, true)

static func _hotdog(ci: CanvasItem) -> void:
	_rr(ci, Vector2(32, 40), 25, 10, 9, Color("#e0a960"))
	_rr(ci, Vector2(32, 33), 28, 5.5, 5.5, Color("#b8473a"))
	ci.draw_line(Vector2(10, 31), Vector2(54, 31), Color(1, 1, 1, 0.35), 1.4)
	var z := PackedVector2Array()
	for i in 13: z.append(Vector2(10 + i * 3.6, 33 + (-2.0 if i % 2 == 0 else 2.0)))
	ci.draw_polyline(z, SUN, 2.4, true)
	_el(ci, Vector2(32, 45), 22, 4, Color("#f0c27e"), 0, 0)
	ci.draw_line(Vector2(12, 48), Vector2(52, 48), Color("#b47c3a"), 1.2)
	# a couple more in the pack behind
	_rr(ci, Vector2(32, 16), 22, 4.5, 4.5, Color("#c45a46"), 1.6)
	_rr(ci, Vector2(32, 22), 24, 4.5, 4.5, Color("#b8473a"), 1.6)

static func _bread(ci: CanvasItem) -> void:
	# the bag, then a slice in front
	_rr(ci, Vector2(26, 34), 20, 22, 8, Color(1, 1, 1, 0.7))
	for p in [Vector2(14, 22), Vector2(22, 46), Vector2(34, 18), Vector2(16, 40), Vector2(36, 50)]:
		ci.draw_circle(p, 2.6, [CORAL, SUN, SEA][int(p.x + p.y) % 3])
	ci.draw_line(Vector2(42, 10), Vector2(50, 6), CORAL, 2.6)
	var outline := PackedVector2Array([Vector2(28, 60), Vector2(60, 60), Vector2(60, 36)])
	outline.append_array(_arc(Vector2(52, 31), 9, 0.3, -PI * 0.75, 8))
	outline.append_array(_arc(Vector2(36, 31), 9, -PI * 0.25, -PI - 0.3, 8))
	outline.append(Vector2(28, 36))
	_shape(ci, outline, Color("#c48a4a"))
	var inner := PackedVector2Array()
	for p in outline: inner.append(Vector2(44, 44) + (p - Vector2(44, 44)) * 0.78)
	ci.draw_colored_polygon(inner, Color("#fbf1dc"))
	for p in [Vector2(38, 44), Vector2(48, 50), Vector2(44, 38), Vector2(52, 42)]: ci.draw_circle(p, 0.7, Color("#d9c49a"))

static func _squid(ci: CanvasItem) -> void:
	var col := Color("#e8b4c4")
	# tentacles
	for i in 6:
		var x0 := 24.0 + i * 3.2
		var pts := PackedVector2Array()
		for j in 8:
			var f := j / 7.0
			pts.append(Vector2(x0 + (x0 - 32) * f * 0.9 + sin(f * 6 + i) * 2.0, 40 + f * 18))
		_stroke(ci, pts, Art.shade(col, -0.05), 1.8)
	# fins and mantle
	_shape(ci, PackedVector2Array([Vector2(32, 4), Vector2(46, 14), Vector2(38, 18)]), Art.shade(col, -0.08), 1.6)
	_shape(ci, PackedVector2Array([Vector2(32, 4), Vector2(18, 14), Vector2(26, 18)]), Art.shade(col, -0.08), 1.6)
	_shape(ci, PackedVector2Array([Vector2(32, 3), Vector2(40, 16), Vector2(41, 36), Vector2(36, 42), Vector2(28, 42), Vector2(23, 36), Vector2(24, 16)]), col)
	for p in [Vector2(30, 16), Vector2(35, 22), Vector2(29, 28), Vector2(36, 32), Vector2(32, 10)]: ci.draw_circle(p, 1.3, Color("#a35a86"))
	ci.draw_circle(Vector2(27.5, 38), 2.2, INK); ci.draw_circle(Vector2(36.5, 38), 2.2, INK)
	# frost
	for p in [Vector2(14, 28), Vector2(50, 26), Vector2(48, 50), Vector2(12, 50)]:
		for a in 3:
			var v := Vector2.from_angle(a * PI / 3) * 3.2
			ci.draw_line(p - v, p + v, Color("#9fd3e8"), 1.2, true)

# ---------- coolers and gadgets ----------

static func _cooler(ci: CanvasItem) -> void:
	_rr(ci, Vector2(30, 42), 24, 15, 4, Color("#f4f7f8"))
	ci.draw_rect(Rect2(8, 50, 44, 5), SEA)
	_rr(ci, Vector2(30, 27), 26, 5.5, 3, SEA)
	ci.draw_polyline(_arc(Vector2(30, 22), 8, PI, TAU, 8), INK, 4.4, true)
	ci.draw_polyline(_arc(Vector2(30, 22), 8, PI, TAU, 8), Color("#f4f7f8"), 2.0, true)
	ci.draw_rect(Rect2(14, 35, 8, 3), Color(INK, 0.25))
	# a plus badge: five more
	ci.draw_circle(Vector2(53, 13), 9.5, INK); ci.draw_circle(Vector2(53, 13), 7.8, CORAL)
	ci.draw_line(Vector2(48.5, 13), Vector2(57.5, 13), Color.WHITE, 2.6)
	ci.draw_line(Vector2(53, 8.5), Vector2(53, 17.5), Color.WHITE, 2.6)

static func _mcooler(ci: CanvasItem) -> void:
	_rr(ci, Vector2(32, 40), 28, 16, 5, Color("#f4f7f8"))
	_rr(ci, Vector2(32, 23), 30, 5.5, 3, TEAL)
	# rope handles and latches
	for sx in [-1, 1]:
		ci.draw_polyline(_arc(Vector2(32 + sx * 29, 37), 4.5, -PI / 2, PI / 2, 6) if sx > 0 else _arc(Vector2(3, 37), 4.5, PI / 2, PI * 1.5, 6), Color("#c9a55c"), 2.4, true)
		_rr(ci, Vector2(32 + sx * 13, 30), 3.0, 4.0, 1.0, SILVER, 1.4)
	ci.draw_rect(Rect2(6, 48, 52, 4), TEAL)
	ci.draw_circle(Vector2(12, 58), 3.4, INK); ci.draw_circle(Vector2(52, 58), 3.4, INK)
	ci.draw_circle(Vector2(12, 58), 1.4, SILVER); ci.draw_circle(Vector2(52, 58), 1.4, SILVER)

static func _phone(ci: CanvasItem) -> void:
	_rr(ci, Vector2(30, 33), 16, 26, 4, Color("#2c3338"))
	_rr(ci, Vector2(30, 34), 13, 20, 2, Color("#8fd0e8"), 1.2)
	ci.draw_rect(Rect2(17, 46, 26, 8), Color("#4aa3c2"))
	# a fish on screen, brag photo style
	_fish_at(ci, Vector2(30, 36), 0.5, Color("#6f9a4c"))
	ci.draw_circle(Vector2(30, 10), 1.2, Color("#5f6f75"))
	# the camera flash
	_sparkle(ci, Vector2(52, 12), 7.0, SUN)
	_sparkle(ci, Vector2(52, 12), 3.5, Color.WHITE)

static func _flashlight(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(46, 24), Vector2(64, 8), Vector2(64, 56), Vector2(46, 40)]), Color(1, 0.9, 0.4, 0.45))
	_rr(ci, Vector2(22, 32), 16, 6, 2, Color("#3d4a52"))
	for x in [12, 16, 20]: ci.draw_line(Vector2(x, 27), Vector2(x, 37), Color("#2a3238"), 1.4)
	_shape(ci, PackedVector2Array([Vector2(37, 26), Vector2(46, 22), Vector2(46, 42), Vector2(37, 38)]), Color("#59636b"))
	_el(ci, Vector2(46, 32), 2.6, 10, Color("#fff2b0"))
	_rr(ci, Vector2(28, 25), 3, 1.6, 1, CORAL, 1.2)

static func _geiger(ci: CanvasItem) -> void:
	# the wand on its cable
	var cab := PackedVector2Array()
	for i in 11:
		var f := i / 10.0
		cab.append(Vector2(44 + f * 10, 44 - f * 26 + sin(f * PI) * 8))
	ci.draw_polyline(cab, INK, 2.0, true)
	_rr(ci, Vector2(55, 14), 3.5, 9, 2, Color("#59636b"), 1.6)
	ci.draw_polyline(_arc(Vector2(26, 22), 9, PI, TAU, 8), INK, 3.0, true)
	_rr(ci, Vector2(28, 40), 19, 15, 4, SUN)
	ci.draw_circle(Vector2(23, 40), 9.5, INK); ci.draw_circle(Vector2(23, 40), 8, Color("#fbf3e2"))
	for i in 5:
		var a := lerpf(PI * 1.15, PI * 1.85, i / 4.0)
		ci.draw_line(Vector2(23, 40) + Vector2.from_angle(a) * 5.5, Vector2(23, 40) + Vector2.from_angle(a) * 7.2, INK, 1.0)
	ci.draw_arc(Vector2(23, 40), 6.5, PI * 1.65, PI * 1.85, 4, CORAL, 2.0)
	ci.draw_line(Vector2(23, 41), Vector2(23, 40) + Vector2.from_angle(PI * 1.72) * 7, CORAL, 1.4, true)
	ci.draw_circle(Vector2(23, 41), 1.4, INK)
	# a little trefoil
	var tc := Vector2(39.5, 46)
	ci.draw_circle(tc, 5.2, INK)
	for i in 3:
		var a0 := -PI / 2 + i * TAU / 3 - 0.5
		var pts := PackedVector2Array([tc]); pts.append_array(_arc(tc, 4.4, a0, a0 + 1.0, 4))
		ci.draw_colored_polygon(pts, SUN)
	ci.draw_circle(tc, 1.3, SUN); ci.draw_circle(tc, 0.7, INK)

static func _prybar(ci: CanvasItem) -> void:
	var pts := PackedVector2Array([Vector2(10, 58), Vector2(13, 52)])
	pts.append(Vector2(44, 14))
	pts.append_array(_arc(Vector2(49, 15), 6, PI + 0.65, TAU + 0.9, 10))
	_stroke(ci, pts, Color("#c8372d"), 4.6)
	ci.draw_line(Vector2(15, 48), Vector2(40, 17), Color(1, 1, 1, 0.35), 1.2, true)
	# the split claw end
	ci.draw_line(Vector2(9.5, 58.5), Vector2(6, 60), INK, 2.0)
	ci.draw_line(Vector2(9.5, 58.5), Vector2(11, 62), INK, 2.0)
	# and a manhole cover peeking in
	ci.draw_arc(Vector2(48, 60), 16, PI, PI * 1.55, 10, INK, 3.0, true)
	ci.draw_arc(Vector2(48, 60), 16, PI, PI * 1.55, 10, Color("#6b7378"), 1.2, true)

static func _shades(ci: CanvasItem) -> void:
	ci.draw_line(Vector2(6, 28), Vector2(2, 24), INK, 2.4)
	ci.draw_line(Vector2(58, 28), Vector2(62, 24), INK, 2.4)
	for sx in [-1, 1]:
		var c := Vector2(32 + sx * 14, 34)
		var lens := PackedVector2Array([c + Vector2(-11, -8), c + Vector2(11, -8), c + Vector2(10, 4), c + Vector2(4, 9), c + Vector2(-4, 9), c + Vector2(-10, 4)])
		_shape(ci, lens, Color("#1f3a4a"), 2.6)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -6), c + Vector2(9, -6), c + Vector2(8, -1), c + Vector2(-8, 0)]), Color(TEAL, 0.55))
		ci.draw_line(c + Vector2(-6, 4), c + Vector2(1, -5), Color(1, 1, 1, 0.55), 1.6)
		ci.draw_line(c + Vector2(-2, 5), c + Vector2(4, -3), Color(1, 1, 1, 0.3), 1.0)
	ci.draw_polyline(_arc(Vector2(32, 30), 5, PI * 1.15, PI * 1.85, 6), INK, 2.6, true)
	# a sun glint on the water below
	ci.draw_line(Vector2(14, 54), Vector2(50, 54), Color(SEA, 0.6), 2.0)
	_sparkle(ci, Vector2(40, 53), 5, SUN)

# ---------- clothes ----------

static func _shirt(ci: CanvasItem, col: Color) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(22, 8), Vector2(42, 8), Vector2(57, 19), Vector2(51, 29), Vector2(46, 26), Vector2(46, 58), Vector2(18, 58), Vector2(18, 26), Vector2(13, 29), Vector2(7, 19)])
	_shape(ci, pts, col)
	return pts

static func _polo(ci: CanvasItem) -> void:
	var col := Color("#f29bb7")
	_shirt(ci, col)
	ci.draw_line(Vector2(13, 29), Vector2(18, 26), Art.shade(col, -0.2), 2.0)
	ci.draw_line(Vector2(51, 29), Vector2(46, 26), Art.shade(col, -0.2), 2.0)
	_shape(ci, PackedVector2Array([Vector2(22, 8), Vector2(32, 12), Vector2(26, 19)]), Color.WHITE, 1.6)
	_shape(ci, PackedVector2Array([Vector2(42, 8), Vector2(32, 12), Vector2(38, 19)]), Color.WHITE, 1.6)
	ci.draw_line(Vector2(32, 12), Vector2(32, 28), Art.shade(col, -0.3), 1.4)
	for y in [17, 23]: ci.draw_circle(Vector2(32, y), 1.1, Color.WHITE)
	# a tiny golf flag logo
	ci.draw_line(Vector2(40, 26), Vector2(40, 33), INK, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(40, 26), Vector2(44, 27.5), Vector2(40, 29)]), CORAL)
	# the visor
	ci.draw_arc(Vector2(48, 48), 9, PI, TAU, 10, INK, 5.0, true)
	ci.draw_arc(Vector2(48, 48), 9, PI, TAU, 10, Color.WHITE, 2.6, true)
	_el(ci, Vector2(48, 50), 13, 4, TEAL)

static func _suit(ci: CanvasItem) -> void:
	var col := Color("#33415c")
	_shirt(ci, col)
	_shape(ci, PackedVector2Array([Vector2(25, 8), Vector2(39, 8), Vector2(32, 34)]), Color.WHITE, 1.6)
	# lapels
	_shape(ci, PackedVector2Array([Vector2(22, 8), Vector2(25, 8), Vector2(32, 34), Vector2(24, 24)]), Art.shade(col, 0.15), 1.4)
	_shape(ci, PackedVector2Array([Vector2(42, 8), Vector2(39, 8), Vector2(32, 34), Vector2(40, 24)]), Art.shade(col, 0.15), 1.4)
	# the tie
	_shape(ci, PackedVector2Array([Vector2(30, 10), Vector2(34, 10), Vector2(33, 14), Vector2(31, 14)]), CORAL, 1.2)
	_shape(ci, PackedVector2Array([Vector2(31, 14), Vector2(33, 14), Vector2(35, 28), Vector2(32, 32), Vector2(29, 28)]), CORAL, 1.2)
	for y in [40, 48]: ci.draw_circle(Vector2(32, y), 1.4, Color("#c9a55c"))
	ci.draw_line(Vector2(36, 30), Vector2(43, 30), Color.WHITE, 1.6) # pocket square

static func _waders(ci: CanvasItem) -> void:
	var col := Color("#5f6e3c")
	ci.draw_line(Vector2(22, 14), Vector2(18, 2), INK, 3.6); ci.draw_line(Vector2(22, 14), Vector2(18, 2), Color("#3a3a3a"), 1.8)
	ci.draw_line(Vector2(42, 14), Vector2(46, 2), INK, 3.6); ci.draw_line(Vector2(42, 14), Vector2(46, 2), Color("#3a3a3a"), 1.8)
	_shape(ci, PackedVector2Array([Vector2(20, 13), Vector2(44, 13), Vector2(46, 34), Vector2(46, 50), Vector2(34, 50), Vector2(33, 36), Vector2(31, 36), Vector2(30, 50), Vector2(18, 50), Vector2(18, 34)]), col)
	_shape(ci, PackedVector2Array([Vector2(18, 48), Vector2(30, 48), Vector2(31, 58), Vector2(12, 58), Vector2(13, 54)]), Color("#2f3a24"))
	_shape(ci, PackedVector2Array([Vector2(34, 48), Vector2(46, 48), Vector2(51, 54), Vector2(52, 58), Vector2(33, 58)]), Color("#2f3a24"))
	_rr(ci, Vector2(32, 22), 6, 4, 1.5, Art.shade(col, 0.15), 1.4)
	for x in [22, 42]: ci.draw_rect(Rect2(x - 2, 13, 4, 3), SILVER)
	ci.draw_line(Vector2(20, 34), Vector2(44, 34), Art.shade(col, -0.2), 1.2)

static func _lanyard(ci: CanvasItem) -> void:
	ci.draw_polyline(PackedVector2Array([Vector2(14, 2), Vector2(30, 24)]), INK, 5.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(50, 2), Vector2(34, 24)]), INK, 5.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(14, 2), Vector2(30, 24)]), SEA, 3.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(50, 2), Vector2(34, 24)]), SEA, 3.0, true)
	_rr(ci, Vector2(32, 26), 4, 3, 1, SILVER, 1.4)
	_rr(ci, Vector2(32, 45), 14, 16, 2.5, Color.WHITE)
	ci.draw_rect(Rect2(19, 30, 26, 6), SEA)
	ci.draw_rect(Rect2(22, 39, 9, 10), Color("#d9cbb0")); ci.draw_rect(Rect2(22, 39, 9, 10), INK, false, 1.0)
	ci.draw_circle(Vector2(26.5, 43), 2.2, Color("#8a6a4a"))
	for y in [41, 45, 49]: ci.draw_line(Vector2(34, y), Vector2(42, y), Color(INK, 0.5), 1.4)
	ci.draw_line(Vector2(22, 55), Vector2(42, 55), Color(INK, 0.5), 1.4)

# ---------- boats and the tank ----------

static func _kayak(ci: CanvasItem) -> void:
	var col := Color("#f07b2a")
	var rot := -0.72
	var c := Vector2(32, 32)
	var hull := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		var v := Vector2(cos(a) * 28, sin(a) * 7.5 * (1.0 - 0.25 * abs(cos(a))))
		hull.append(c + v.rotated(rot))
	_shape(ci, hull, col)
	ci.draw_line(c + Vector2(-26, 0).rotated(rot), c + Vector2(26, 0).rotated(rot), Art.shade(col, 0.25), 1.2)
	_el(ci, c + Vector2(2, 0).rotated(rot), 8, 4.2, Color("#2a3238"), rot)
	_el(ci, c + Vector2(4, 0).rotated(rot), 3.6, 2.4, Color("#4a5560"), rot, 0)
	# the paddle across
	var pr := rot + PI / 2 - 0.25
	var a1 := c + Vector2(24, 0).rotated(pr); var a2 := c - Vector2(24, 0).rotated(pr)
	ci.draw_line(a1, a2, INK, 4.0, true); ci.draw_line(a1, a2, Color("#3a3a3a"), 2.0, true)
	_el(ci, a1, 6, 3.4, SUN, pr)
	_el(ci, a2, 6, 3.4, SUN, pr)

static func _skiff(ci: CanvasItem) -> void:
	# water
	var wv := PackedVector2Array()
	for i in 17: wv.append(Vector2(i * 4, 52 + sin(i * 1.2) * 1.5))
	wv.append(Vector2(64, 64)); wv.append(Vector2(0, 64))
	ci.draw_colored_polygon(wv, Color(SEA, 0.5))
	# outboard motor at the stern
	_rr(ci, Vector2(10, 28), 5, 7, 2, Color("#3d4a52"))
	ci.draw_line(Vector2(10, 34), Vector2(10, 54), INK, 3.4); ci.draw_line(Vector2(10, 34), Vector2(10, 54), Color("#59636b"), 1.6)
	# hull
	_shape(ci, PackedVector2Array([Vector2(12, 34), Vector2(60, 30), Vector2(52, 50), Vector2(16, 50)]), Color("#f4f7f8"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(13, 40), Vector2(57, 37.5), Vector2(55.5, 41.5), Vector2(14, 44)]), TEAL)
	# the console and a rail
	_rr(ci, Vector2(34, 27), 6, 5, 1.5, Color("#e9dcc0"), 1.6)
	ci.draw_line(Vector2(31, 22), Vector2(37, 20), Color("#8fd0e8"), 2.0)
	ci.draw_line(Vector2(42, 29), Vector2(56, 27), INK, 1.4); ci.draw_line(Vector2(56, 27), Vector2(57, 30.5), INK, 1.4)
	# spray at the bow
	for v in [Vector2(60, 46), Vector2(63, 42), Vector2(58, 50)]: ci.draw_circle(v, 1.4, Color.WHITE)

static func _tank(ci: CanvasItem) -> void:
	_rr(ci, Vector2(32, 34), 28, 20, 2, Color("#bfe6f2"))
	ci.draw_rect(Rect2(5.5, 19, 53, 34), Color("#5fb3d4"))
	# gravel and plants
	var gr := PackedVector2Array([Vector2(5.5, 53)])
	for i in 9: gr.append(Vector2(5.5 + i * 6.6, 47 + (i % 3) * 1.5))
	gr.append(Vector2(58.5, 53))
	ci.draw_colored_polygon(gr, Color("#d9b26a"))
	for x0 in [12.0, 50.0]:
		var pl := PackedVector2Array()
		for j in 8: pl.append(Vector2(x0 + sin(j * 1.1) * 2.2, 50 - j * 3.6))
		ci.draw_polyline(pl, Color("#3f8a4a"), 2.6, true)
	_fish_at(ci, Vector2(28, 30), 0.42, Color("#f07b3a"))
	_fish_at(ci, Vector2(42, 40), -0.34, Color("#f2c84a"))
	for p in [Vector2(22, 24), Vector2(23, 20.5), Vector2(44, 28)]: ci.draw_arc(p, 1.4, 0, TAU, 8, Color.WHITE, 0.8)
	# lid and stand
	_rr(ci, Vector2(32, 15), 30, 3, 1, Color("#2c3338"), 1.4)
	_rr(ci, Vector2(32, 57.5), 30, 3, 1, Color("#2c3338"), 1.4)
	ci.draw_line(Vector2(8, 20), Vector2(8, 50), Color(1, 1, 1, 0.5), 1.4)

# ---------- catches ----------

static func _fish(ci: CanvasItem, col: Color) -> void:
	_fish_at(ci, Vector2(30, 34), 1.0, col)

## A side-on fish facing left; k scales it, and a negative k faces it right.
static func _fish_at(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
	var sx := signf(k); var a := absf(k)
	var lw := OW if a > 0.7 else 1.2
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x * sx, y) * a
	_shape(ci, PackedVector2Array([P.call(16, 0), P.call(30, -12), P.call(27, 0), P.call(30, 12)]), Art.shade(col, -0.15), lw)
	_shape(ci, PackedVector2Array([P.call(-4, -9), P.call(6, -17), P.call(14, -9)]), Art.shade(col, -0.2), lw)
	var body := PackedVector2Array()
	for i in 24:
		var t := i * TAU / 24
		body.append(P.call(cos(t) * 20 - 2, sin(t) * (11 - 2.5 * cos(t))))
	_shape(ci, body, col, lw)
	ci.draw_colored_polygon(PackedVector2Array([P.call(-18, 2), P.call(14, 3), P.call(10, 8), P.call(-12, 7)]), Art.shade(col, 0.35))
	ci.draw_arc(P.call(-11, 0), 6.0 * a, -1.0, 1.0, 6, Art.shade(col, -0.35), 1.2 * maxf(a, 0.5))
	ci.draw_circle(P.call(-15, -3), 2.4 * a + 0.4, INK)
	ci.draw_circle(P.call(-15.6, -3.6), 0.8 * a, Color.WHITE)

static func _junk(ci: CanvasItem) -> void:
	# a dented, rusty can with a bit of weed
	_shape(ci, PackedVector2Array([Vector2(18, 18), Vector2(44, 16), Vector2(46, 52), Vector2(30, 56), Vector2(18, 52)]), Color("#b07a4a"))
	_el(ci, Vector2(31, 17), 13, 4, Color("#cfa070"))
	ci.draw_line(Vector2(20, 30), Vector2(45, 29), Color("#8a5a35"), 2.0)
	ci.draw_line(Vector2(20, 42), Vector2(45, 41), Color("#8a5a35"), 2.0)
	ci.draw_polyline(PackedVector2Array([Vector2(36, 40), Vector2(40, 44), Vector2(36, 48)]), Color("#6a4528"), 1.4)
	var wd := PackedVector2Array()
	for i in 9: wd.append(Vector2(40 + i * 2.2, 14 + sin(i * 1.3) * 3 + i * 3))
	ci.draw_polyline(wd, Color("#3f8a4a"), 2.4, true)
	for p in [Vector2(12, 22), Vector2(52, 10), Vector2(10, 40)]: ci.draw_arc(p, 2.0, 0, TAU, 8, Color(SEA, 0.8), 1.2)

# ---------- parts and home-made lures ----------

static func _spoon_shape(ci: CanvasItem, c: Vector2, rot: float, k: float) -> void:
	_el(ci, c, 9 * k, 13 * k, SILVER, rot)
	_el(ci, c + Vector2(-2.5, -3).rotated(rot) * k, 3.5 * k, 6.5 * k, Color(1, 1, 1, 0.7), rot, 0)
	ci.draw_arc(c, 6.5 * k, rot + 0.3, rot + 1.4, 6, Color("#8a959c"), 1.2, true)

static func _spoon_part(ci: CanvasItem) -> void:
	var rot := 0.6
	var top := Vector2(24, 22)
	var tip := top + Vector2(0, 38).rotated(-rot) * 0.95
	ci.draw_line(top + Vector2(0, 10).rotated(-rot), tip, INK, 6.4, true)
	ci.draw_line(top + Vector2(0, 10).rotated(-rot), tip, SILVER, 3.6, true)
	# a bend in the handle
	ci.draw_line(tip, tip + Vector2(10, -2), INK, 6.4, true); ci.draw_line(tip, tip + Vector2(10, -2), SILVER, 3.6, true)
	_spoon_shape(ci, top, -rot, 1.0)

static func _cap(ci: CanvasItem, c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		pts.append(c + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 9.6))
	_shape(ci, pts, Art.shade(col, -0.1), 1.6)
	ci.draw_circle(c, 7.6, col)
	ci.draw_arc(c, 7.6, 0, TAU, 20, Color(INK, 0.5), 1.0, true)
	ci.draw_arc(c, 4.5, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.6), 1.6, true)

static func _caps(ci: CanvasItem) -> void:
	_cap(ci, Vector2(24, 38), CORAL)
	_cap(ci, Vector2(41, 26), SEA)

static func _beads(ci: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in 13: pts.append(Vector2(8 + i * 4, 36 + sin(i * 0.7) * 12))
	ci.draw_polyline(pts, INK, 1.2, true)
	var cols := [CORAL, SUN, TEAL, Color.WHITE, SEA, Color("#c9b6e4")]
	for i in range(1, 12, 2):
		var p: Vector2 = pts[i]
		ci.draw_circle(p, 5.0, INK); ci.draw_circle(p, 3.8, cols[(i / 2) % cols.size()])
		ci.draw_circle(p + Vector2(-1.4, -1.4), 1.1, Color(1, 1, 1, 0.75))

static func _feather(ci: CanvasItem, c: Vector2, k: float, col := Color("#f2f4f5")) -> void:
	var rot := -0.8
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y).rotated(rot) * k
	var vane := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		vane.append(P.call(lerpf(-22, 20, f), -sin(f * PI) * 8 - (1.5 if i % 3 == 1 else 0.0)))
	for i in 13:
		var f := 1.0 - i / 12.0
		vane.append(P.call(lerpf(-22, 20, f), sin(f * PI) * 7 + (1.5 if i % 3 == 1 else 0.0)))
	_shape(ci, vane, col, 1.6 if k > 0.7 else 1.2)
	for i in 5:
		var x := lerpf(-12, 12, i / 4.0)
		ci.draw_line(P.call(x, 0), P.call(x + 6, -6), Color("#c3ccd2"), 1.0)
	ci.draw_line(P.call(-28, 0), P.call(21, 0), INK, 1.4 * k + 0.4, true)
	ci.draw_line(P.call(14, 0), P.call(20, 0), Color("#8a959c"), 1.0)

static func _wire(ci: CanvasItem) -> void:
	var col := Color("#d0793a")
	var pts := PackedVector2Array()
	for i in 49:
		var a := i * 0.5
		pts.append(Vector2(30, 34) + Vector2(cos(a) * 16, sin(a) * 10) + Vector2(i * 0.12, 0))
	pts.append(Vector2(56, 14))
	ci.draw_polyline(pts, INK, 4.6, true)
	ci.draw_polyline(pts, col, 2.4, true)
	ci.draw_polyline(pts, Color(1, 1, 1, 0.35), 0.8, true)

static func _glowstick(ci: CanvasItem, t: float) -> void:
	var g := 0.75 + 0.25 * sin(t * 2.5)
	var c := Vector2(32, 32)
	var rot := -0.75
	_el(ci, c, 26, 12, Color(0.6, 1.0, 0.35, 0.22 * g), rot, 0)
	_el(ci, c, 20, 8, Color(0.6, 1.0, 0.35, 0.3 * g), rot, 0)
	var body := PackedVector2Array()
	for q in Art.rrect(Vector2.ZERO, 22, 4.6, 4.4): body.append(c + q.rotated(rot))
	_shape(ci, body, Color("#a8f05a"))
	ci.draw_line(c + Vector2(-18, -1.5).rotated(rot), c + Vector2(16, -1.5).rotated(rot), Color(1, 1, 1, 0.65), 1.4)
	ci.draw_circle(c + Vector2(23, 0).rotated(rot), 2.6, INK); ci.draw_circle(c + Vector2(23, 0).rotated(rot), 1.6, Color("#59636b"))

static func _treble(ci: CanvasItem, top: Vector2) -> void:
	ci.draw_line(top, top + Vector2(0, 8), INK, 1.8)
	for sx in [-1, 1]:
		var hc := top + Vector2(sx * 3.6, 8)
		var hp := _arc(hc, 3.6, PI if sx > 0 else 0.0, 0.0 if sx > 0 else PI, 6)
		hp.append(hc + Vector2(sx * 3.6, -3.5))
		ci.draw_polyline(hp, INK, 1.8, true)

static func _spoon_lure(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(32, 6), 2.8, 0, TAU, 10, INK, 1.6, true)
	ci.draw_line(Vector2(32, 9), Vector2(32, 13), INK, 1.6)
	_spoon_shape(ci, Vector2(32, 28), 0.0, 1.15)
	# a red stripe painted on
	ci.draw_line(Vector2(28, 26), Vector2(36, 34), Color(CORAL, 0.85), 2.2, true)
	_treble(ci, Vector2(32, 43))
	ci.draw_circle(Vector2(32, 43), 1.8, INK)

static func _popper(ci: CanvasItem) -> void:
	# two caps face to face on a bead body, chugging across the top
	ci.draw_line(Vector2(6, 46), Vector2(58, 46), Color(SEA, 0.55), 2.0)
	for p in [Vector2(10, 40), Vector2(6, 36), Vector2(13, 34)]: ci.draw_circle(p, 1.5, Color(SEA, 0.7))
	ci.draw_line(Vector2(14, 30), Vector2(52, 30), INK, 1.6)
	_el(ci, Vector2(34, 30), 12, 6.5, SUN)
	ci.draw_line(Vector2(26, 27), Vector2(42, 27), Color(1, 1, 1, 0.5), 1.4)
	ci.draw_circle(Vector2(41, 29), 1.8, INK)
	var cap := PackedVector2Array()
	for i in 13:
		var a := -PI / 2 + i * PI / 12
		cap.append(Vector2(20, 30) + Vector2(-cos(a) * 3.5, sin(a) * 10 * (1.0 if i % 2 == 0 else 0.9)))
	_shape(ci, cap, CORAL, 1.6)
	ci.draw_circle(Vector2(50, 30), 2.6, INK); ci.draw_circle(Vector2(50, 30), 1.7, TEAL)
	_treble(ci, Vector2(34, 36.5))
	ci.draw_arc(Vector2(52, 30), 2.2, 0, TAU, 8, INK, 1.4, true)

static func _jig(ci: CanvasItem) -> void:
	_feather(ci, Vector2(30, 36), 0.75, Color("#f7f2e6"))
	_feather(ci, Vector2(27, 38), 0.6, Color("#e8b54a"))
	ci.draw_circle(Vector2(44, 21), 7.2, INK); ci.draw_circle(Vector2(44, 21), 5.8, CORAL)
	ci.draw_circle(Vector2(42, 19), 1.8, Color(1, 1, 1, 0.7))
	ci.draw_circle(Vector2(46, 20.5), 1.6, Color.WHITE); ci.draw_circle(Vector2(46.4, 20.5), 0.8, INK)
	ci.draw_arc(Vector2(50, 15), 2.6, 0, TAU, 10, INK, 1.6, true)
	var hp := PackedVector2Array([Vector2(42, 26), Vector2(30, 48)])
	hp.append_array(_arc(Vector2(34, 49), 4.2, PI, PI * 0.1, 6))
	ci.draw_polyline(hp, INK, 1.8, true)

static func _glow_lure(ci: CanvasItem, t: float) -> void:
	var g := 0.75 + 0.25 * sin(t * 2.5)
	ci.draw_rect(Rect2(4, 4, 56, 56), Color(0.08, 0.14, 0.24, 0.85))
	_el(ci, Vector2(32, 28), 18, 22, Color(0.6, 1.0, 0.35, 0.16 * g), 0, 0)
	_el(ci, Vector2(32, 28), 12, 16, Color(0.6, 1.0, 0.35, 0.22 * g), 0, 0)
	ci.draw_arc(Vector2(32, 6), 2.8, 0, TAU, 10, SILVER, 1.6, true)
	ci.draw_line(Vector2(32, 9), Vector2(32, 44), SILVER, 1.4)
	for i in 3:
		var p := Vector2(32, 15 + i * 6)
		ci.draw_circle(p, 3.4, INK); ci.draw_circle(p, 2.6, Color("#c8ff7a"))
	_el(ci, Vector2(32, 37), 4.5, 7, Color("#a8f05a"))
	ci.draw_line(Vector2(30.5, 33), Vector2(30.5, 40), Color(1, 1, 1, 0.6), 1.2)
	for sx in [-1, 1]:
		var hc := Vector2(32 + sx * 3.6, 52)
		var hp := _arc(hc, 3.6, PI if sx > 0 else 0.0, 0.0 if sx > 0 else PI, 6)
		hp.append(hc + Vector2(sx * 3.6, -3.5))
		ci.draw_polyline(hp, SILVER, 1.8, true)
	ci.draw_line(Vector2(32, 44), Vector2(32, 52), SILVER, 1.8)

# ---------- rod parts and the home-built rod ----------

## A home-built rod from its stats dictionary (blank, reel and grip ids).
static func draw_homerod(ci: CanvasItem, st: Dictionary, r: Rect2) -> void:
	var s := minf(r.size.x, r.size.y) / 64.0
	ci.draw_set_transform(r.position + (r.size - Vector2(64, 64) * s) / 2.0, 0.0, Vector2(s, s))
	var blank := Color("#2b2f36") if st.get("blank", "") == "p_graphite" else Color("#c4b85a")
	var handle: Color = { "p_cork": Color("#c79a62"), "p_foam": Color("#3a3a3a") }.get(st.get("grip", ""), Color("#9aa4aa"))
	_rod(ci, blank, CORAL, handle, 3.3, "conv" if st.get("reel", "") == "p_bigreel" else "spin", "home")
	if st.get("grip", "") == "":
		for i in 3:
			var p := Vector2(7, 57).lerp(Vector2(17.6, 46.4), (i + 0.5) / 3.0)
			ci.draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), Color(INK, 0.4), 0.8)
	ci.draw_set_transform(Vector2.ZERO)

static func _blank_part(ci: CanvasItem, col: Color) -> void:
	var a := Vector2(8, 56); var b := Vector2(56, 8)
	ci.draw_line(a, b, INK, 6.4, true)
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-1.9, -1.9), b + Vector2(-0.7, -0.7), b + Vector2(0.7, 0.7), a + Vector2(1.9, 1.9)]), col)
	ci.draw_line(a + Vector2(-0.8, -0.8), b, Color(1, 1, 1, 0.35), 0.8, true)
	for f in [0.35, 0.6, 0.82]:
		var p := a.lerp(b, f)
		ci.draw_line(p + Vector2(-2.6, -1.0), p + Vector2(1.0, 2.6), CORAL if col.v > 0.5 else SEA, 1.6)
	# a chipped end and a tag
	ci.draw_circle(a, 3.0, INK); ci.draw_circle(a, 1.8, Art.shade(col, -0.2))
	_rr(ci, Vector2(44, 38), 7, 4.5, 1.5, Color("#f3e6c9"), 1.4)
	ci.draw_line(Vector2(38, 36), Vector2(34, 30), INK, 1.0)

static func _reel_part(ci: CanvasItem, big: bool) -> void:
	if big:
		_rr(ci, Vector2(32, 34), 18, 13, 5, Color("#c98f2a"))
		ci.draw_line(Vector2(16, 34), Vector2(48, 34), Color("#8a5a1a"), 1.6)
		for p in [Vector2(20, 26), Vector2(44, 42), Vector2(26, 44)]: ci.draw_circle(p, 1.8, Color("#8a4a2a"))
		ci.draw_line(Vector2(50, 34), Vector2(58, 26), INK, 2.6)
		_el(ci, Vector2(58.5, 25.5), 3.4, 2.4, Color("#3a3a3a"))
		_rr(ci, Vector2(32, 18), 14, 2.5, 1, SILVER, 1.4)
	else:
		_el(ci, Vector2(28, 36), 14, 15, Color("#7d8a93"))
		_el(ci, Vector2(38, 36), 7, 13, SILVER, 0, 1.6)
		ci.draw_line(Vector2(38, 23), Vector2(38, 49), Color("#8a959c"), 1.0)
		for p in [Vector2(22, 30), Vector2(26, 44), Vector2(18, 38)]: ci.draw_circle(p, 2.0, Color("#a0582e"))
		ci.draw_line(Vector2(28, 21), Vector2(28, 10), INK, 3.4); ci.draw_line(Vector2(28, 21), Vector2(28, 10), SILVER, 1.6)
		_rr(ci, Vector2(28, 9), 8, 2, 1, SILVER, 1.4)
		ci.draw_line(Vector2(16, 36), Vector2(6, 46), INK, 2.0)
		_el(ci, Vector2(5.5, 47), 2.6, 2.6, Color("#3a3a3a"), 0, 1.2)

static func _corks(ci: CanvasItem) -> void:
	for c in [[Vector2(22, 40), 0.3], [Vector2(40, 34), -0.5], [Vector2(32, 22), 0.9]]:
		var p: Vector2 = c[0]; var rot: float = c[1]
		var body := PackedVector2Array()
		for q in Art.rrect(Vector2.ZERO, 12, 6.5, 2.5): body.append(p + q.rotated(rot))
		_shape(ci, body, Color("#c79a62"), 1.6)
		ci.draw_line(p + Vector2(-12, 0).rotated(rot), p + Vector2(-12, 0).rotated(rot) + Vector2(0, 0), INK, 1)
		_el(ci, p + Vector2(11, 0).rotated(rot), 1.8, 6.2, Color("#8a3a4a"), rot, 1.2)
		for k in 4: ci.draw_circle(p + Vector2(-6 + k * 4, (k % 2) * 2 - 1).rotated(rot), 0.7, Color("#9c7444"))

static func _foam(ci: CanvasItem) -> void:
	var body := PackedVector2Array()
	for q in Art.rrect(Vector2.ZERO, 24, 9, 8): body.append(Vector2(32, 34) + q.rotated(-0.5))
	_shape(ci, body, Color("#5cc8c0"))
	for k in 5:
		var p := Vector2(32, 34) + Vector2(-16 + k * 8, 0).rotated(-0.5)
		ci.draw_line(p + Vector2(0, -8).rotated(-0.5), p + Vector2(0, 8).rotated(-0.5), Color(1, 1, 1, 0.3), 1.2)
	var end := Vector2(32, 34) + Vector2(22, 0).rotated(-0.5)
	_el(ci, end, 3.5, 8.5, Color("#7fe0d8"), -0.5, 1.4)
	ci.draw_circle(end, 2.4, Color("#2a8a84"))

static func _tape(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(30, 34), 20, INK); ci.draw_circle(Vector2(30, 34), 18, Color("#a9b2b8"))
	ci.draw_arc(Vector2(30, 34), 14, 0, TAU, 24, Color("#8a959c"), 1.2, true)
	ci.draw_circle(Vector2(30, 34), 9.5, INK); ci.draw_circle(Vector2(30, 34), 8, Color("#e9dcc0"))
	_shape(ci, PackedVector2Array([Vector2(46, 44), Vector2(58, 50), Vector2(56, 56), Vector2(44, 49)]), Color("#a9b2b8"), 1.6)
