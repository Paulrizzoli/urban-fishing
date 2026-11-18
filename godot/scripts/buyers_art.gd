class_name BuyersArt
extends RefCounted
## Pictures for the restaurants and fish markets (see buyers.gd): their buildings in town, the
## price board standing by a market's door, and, on their cards, the inside with the chef or
## fishmonger behind the counter and today's menu or prices in chalk.
## The card pictures are drawn on a 640 x 300 design and scaled to fit, like FintasticArt.

const INK := Color("#22313a")
const PAPER := Color("#fbf3e2")
const SUN := Color("#f2b134")
const CORAL := Color("#e2583e")
const SEA := Color("#2b7ea6")
const CHALK := Color("#eef2ea")
const SLATE := Color("#2f3d36")
const W := 640.0
const H := 300.0

# ---------- in town ----------

## A buyer's building, by style: shack (a beach shack on stilts), fishmkt, supper, hall.
static func building(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var bd := Buyers.by_id(String(b.get("buyer", "")))
	match String(b.kind):
		"shack": _shack(ci, b, bd, t)
		_:
			Art.flat(ci, b)
			_front(ci, b, bd, t)

## Bonita's: a blue clapboard shack on stilts with a tin roof, a serving window with a striped
## awning, a plank sign and a pelican on the ridge.
static func _shack(ci: CanvasItem, b: Dictionary, bd: Dictionary, t: float) -> void:
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var c := Color(b.color)
	var fy := y + h - 1.05
	Art.soft_shadow(ci, Rect2(x, y - 0.2, w, h + 0.2), Vector2(0.34, 0.24))
	# stilts and the deck under the front
	for sx in [x + 0.25, x + w * 0.35, x + w * 0.65, x + w - 0.35]:
		ci.draw_rect(Rect2(sx, y + h - 0.32, 0.14, 0.32), Color("#6b5034"))
	ci.draw_rect(Rect2(x - 0.15, y + h - 0.4, w + 0.3, 0.12), Color("#a8835a"))
	for k in int(w * 3): ci.draw_line(Vector2(x - 0.15 + k / 3.0, y + h - 0.4), Vector2(x - 0.15 + k / 3.0, y + h - 0.28), Color(0, 0, 0, 0.12), 0.02)
	# clapboard front wall
	ci.draw_rect(Rect2(x, fy, w, 0.68), Art.shade(c, -0.12))
	for k in 6: ci.draw_line(Vector2(x, fy + 0.1 + k * 0.11), Vector2(x + w, fy + 0.1 + k * 0.11), Color(0, 0, 0, 0.12), 0.02)
	# serving window with a striped awning, and the screen door
	var dt := Buyers.door_tile(bd) if not bd.is_empty() else Vector2i(int(x + w / 2), int(y + h - 1))
	var win := Rect2(x + 0.5, fy + 0.18, 2.4, 0.36)
	ci.draw_rect(win.grow(0.04), Color("#6b5034"))
	ci.draw_rect(win, Color("#3a2a22"))
	ci.draw_rect(Rect2(win.position.x, win.end.y - 0.08, win.size.x, 0.1), Color("#c9a574"))
	for i in 8:
		ci.draw_rect(Rect2(win.position.x - 0.1 + i * 0.325, fy + 0.02, 0.325, 0.16), PAPER if i % 2 else CORAL)
	ci.draw_rect(Rect2(dt.x + 0.2, fy + 0.12, 0.6, 0.48), Color("#3a4a4a"))
	ci.draw_rect(Rect2(dt.x + 0.2, fy + 0.12, 0.6, 0.48), Color("#6b5034"), false, 0.05)
	var win2 := Rect2(x + w - 2.2, fy + 0.18, 1.5, 0.32)
	Art.window(ci, win2, Color("#f6eedc"))
	# the tin roof: two slopes with ridges, a rusty patch, the eaves hanging over
	var ry := y - 0.1
	var mid := ry + (fy - ry) * 0.5
	Art.poly(ci, [Vector2(x - 0.25, ry), Vector2(x + w + 0.25, ry), Vector2(x + w + 0.25, mid), Vector2(x - 0.25, mid)], Color("#c7d0d3"))
	Art.poly(ci, [Vector2(x - 0.25, mid), Vector2(x + w + 0.25, mid), Vector2(x + w + 0.25, fy + 0.04), Vector2(x - 0.25, fy + 0.04)], Color("#a9b4b8"))
	var k := 0.0
	while k < w + 0.4:
		ci.draw_line(Vector2(x - 0.2 + k, ry), Vector2(x - 0.2 + k, fy + 0.04), Color(0, 0, 0, 0.1), 0.04)
		ci.draw_line(Vector2(x - 0.12 + k, ry), Vector2(x - 0.12 + k, fy + 0.04), Color(1, 1, 1, 0.18), 0.03)
		k += 0.22
	ci.draw_line(Vector2(x - 0.25, mid), Vector2(x + w + 0.25, mid), Color("#8a9498"), 0.08)
	Art.ellipse(ci, Vector2(x + w * 0.72, ry + 0.45), 0.7, 0.25, Color(0.6, 0.32, 0.16, 0.35))
	Art.ellipse(ci, Vector2(x + w * 0.2, mid + 0.4), 0.45, 0.18, Color(0.6, 0.32, 0.16, 0.3))
	# the plank sign on the front edge of the roof
	var sg := Rect2(x + w * 0.5 - 2.0, fy - 0.72, 4.0, 0.64)
	ci.draw_rect(Rect2(sg.position + Vector2(0.08, 0.08), sg.size), Color(0, 0, 0, 0.25))
	ci.draw_rect(sg, Color("#f6e3b4"))
	ci.draw_rect(sg, Color("#8a5a35"), false, 0.06)
	Art.text(ci, Vector2(sg.get_center().x + 0.25, sg.position.y + 0.42), String(bd.get("sign", "BONITA'S")), 0.34, CORAL)
	Art.text(ci, Vector2(sg.get_center().x + 0.25, sg.position.y + 0.62), String(bd.get("subsign", "")), 0.12, INK)
	_sign_fish(ci, Vector2(sg.position.x + 0.45, sg.position.y + 0.35), 0.3, Color("#2b7ea6"))
	# a pelican on the ridge, turning its head now and then
	var pp := Vector2(x + w * 0.82, mid - 0.15)
	Art.ellipse(ci, pp + Vector2(0.05, 0.2), 0.32, 0.08, Color(0, 0, 0, 0.2))
	Art.ellipse(ci, pp, 0.28, 0.17, Color("#e8e4dc"))
	Art.ellipse(ci, pp + Vector2(-0.12, 0.02), 0.18, 0.12, Color("#9a948a"))
	var look := -1.0 if fmod(t, 7.0) < 3.5 else 1.0
	ci.draw_circle(pp + Vector2(0.2 * look, -0.2), 0.09, Color("#f4f1ea"))
	Art.poly(ci, [pp + Vector2(0.24 * look, -0.22), pp + Vector2(0.62 * look, -0.1), pp + Vector2(0.24 * look, -0.14)], Color("#e8a23a"))
	ci.draw_circle(pp + Vector2(0.23 * look, -0.24), 0.025, INK)

## Signs, awnings and doors on the front of a flat-roofed market or supper club.
static func _front(ci: CanvasItem, b: Dictionary, bd: Dictionary, t: float) -> void:
	var x: float = b.x
	var y: float = b.y
	var w: float = b.w
	var h: float = b.h
	var fy := y + h - 0.85
	var dt := Buyers.door_tile(bd) if not bd.is_empty() else Vector2i(int(x + w / 2), int(y + h - 1))
	match String(b.kind):
		"fishmkt":
			# blue and white awning the whole way along, roll-up doors open onto the ice
			for i in int(w * 2): ci.draw_rect(Rect2(x + i * 0.5, fy - 0.14, 0.5, 0.3), PAPER if i % 2 else SEA)
			for i in int(w * 2): ci.draw_circle(Vector2(x + i * 0.5 + 0.25, fy + 0.16), 0.25, PAPER if i % 2 else SEA)
			var bay := Rect2(dt.x - 1.5, fy + 0.3, 4.0, 0.55)
			ci.draw_rect(bay, Color("#26343a"))
			ci.draw_rect(Rect2(bay.position.x + 0.1, bay.end.y - 0.22, bay.size.x - 0.2, 0.2), Color("#cfe8f0"))
			for i in 6:
				var fx := bay.position.x + 0.35 + i * 0.6
				Art.ellipse(ci, Vector2(fx, bay.end.y - 0.14), 0.22, 0.06, [Color("#c9b48a"), Color("#e09a8a"), Color("#a8b8c0")][i % 3])
			# a big painted fish on the roof
			var fc := Vector2(x + w / 2, y + 0.9)
			_sign_fish(ci, fc + Vector2(-3.6, 0.05), 0.55, SEA)
			Art.text(ci, fc + Vector2(0.6, 0.05), "SEASIDE FISH MARKET", 0.36, SEA)
			Art.text(ci, fc + Vector2(0.6, 0.45), String(bd.get("subsign", "")), 0.14, INK)
		"supper":
			# a dark wood door with a porthole, a red awning, and the neon sign with its neon fish
			for i in int(w * 2): ci.draw_rect(Rect2(x + i * 0.5, fy - 0.12, 0.5, 0.26), Color("#c93b2a") if i % 2 else Color("#9a2a20"))
			ci.draw_rect(Rect2(dt.x + 0.15, fy + 0.18, 0.7, fh_of(b) - 0.18), Color("#4a2a1e"))
			ci.draw_circle(Vector2(dt.x + 0.5, fy + 0.38), 0.12, Color("#f2c46a"))
			var sg := Rect2(x + 0.6, y + 0.35, w - 1.2, 1.4)
			ci.draw_rect(Rect2(sg.position + Vector2(0.1, 0.1), sg.size), Color(0, 0, 0, 0.3))
			ci.draw_rect(sg, Color("#1e2a2e"))
			ci.draw_rect(sg, Color("#c9a574"), false, 0.06)
			var flick := 1.0 if fmod(t * 1.7, 9.0) > 0.25 else 0.4
			Art.text(ci, Vector2(sg.get_center().x, sg.position.y + 0.62), "TAILRACE", 0.42, Color(1.0, 0.36, 0.3, flick))
			Art.text(ci, Vector2(sg.get_center().x, sg.position.y + 0.95), "SUPPER CLUB", 0.16, Color(0.98, 0.85, 0.55))
			_neon_fish(ci, Vector2(sg.get_center().x, sg.position.y + 1.18), 0.32, Color(0.4, 0.9, 1.0, flick))
		"hall":
			# a green awning, the market name on the parapet, and Gus's smokehouse chimney
			for i in int(w * 2): ci.draw_rect(Rect2(x + i * 0.5, fy - 0.12, 0.5, 0.28), Color("#e8e0cc") if i % 2 else Color("#3d6e5a"))
			ci.draw_rect(Rect2(dt.x - 0.5, fy + 0.18, 2.0, fh_of(b) - 0.18), Color("#2a2420"))
			ci.draw_rect(Rect2(dt.x - 0.5, fy + 0.18, 2.0, fh_of(b) - 0.18), Color("#c9a574"), false, 0.05)
			Art.text(ci, Vector2(x + w / 2, y + 0.75), "IRONWATER PUBLIC MARKET", 0.34, PAPER, Color(0, 0, 0, 0.35))
			Art.text(ci, Vector2(x + w / 2, y + 1.15), "EST. 1911 · " + String(bd.get("subsign", "")), 0.14, PAPER)
			var cp := Vector2(x + w - 1.6, y + 1.6)
			ci.draw_rect(Rect2(cp + Vector2(0.08, 0.08), Vector2(0.7, 0.7)), Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(cp, Vector2(0.7, 0.7)), Color("#8a4a3a"))
			ci.draw_rect(Rect2(cp + Vector2(0.12, 0.12), Vector2(0.46, 0.46)), Color("#2a2020"))
			for i in 4:
				var k := fmod(t * 0.18 + i / 4.0, 1.0)
				ci.draw_circle(cp + Vector2(0.35 + k * 1.2 + sin(k * 6 + i) * 0.15, 0.3 - k * 2.6), 0.22 + k * 0.6, Color(0.92, 0.9, 0.86, 0.45 * (1 - k)))

static func fh_of(_b: Dictionary) -> float: return 0.85

## A cartoon fish for signs: body, tail, eye.
static func _sign_fish(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	Art.ellipse(ci, c, s, s * 0.45, col)
	Art.poly(ci, [c + Vector2(s * 0.8, 0), c + Vector2(s * 1.35, -s * 0.45), c + Vector2(s * 1.35, s * 0.45)], col)
	ci.draw_circle(c + Vector2(-s * 0.55, -s * 0.08), s * 0.1, PAPER)
	ci.draw_circle(c + Vector2(-s * 0.57, -s * 0.08), s * 0.05, INK)

static func _neon_fish(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := i * TAU / 16
		pts.append(c + Vector2(cos(a) * s, sin(a) * s * 0.45))
	ci.draw_polyline(pts, col, 0.05)
	ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.9, 0), c + Vector2(s * 1.4, -s * 0.4), c + Vector2(s * 1.4, s * 0.4), c + Vector2(s * 0.9, 0)]), col, 0.05)
	ci.draw_circle(c + Vector2(-s * 0.55, -s * 0.05), 0.04, col)

## The props that stand in front: picnic tables with umbrellas by the shack. [[draw(ci), sort y, bounds]]
static func props(bd: Dictionary) -> Array:
	var out := []
	if String(bd.get("style", "")) == "shack":
		var r: Array = bd.bld
		for p in [Vector2(float(r[0]) + float(r[2]) + 1.6, float(r[1]) + 1.0), Vector2(float(r[0]) + float(r[2]) + 4.2, float(r[1]) + 2.1)]:
			var pp: Vector2 = p
			out.append([func(ci): _table(ci, pp), pp.y + 0.4, Rect2(pp - Vector2(1.5, 1.5), Vector2(3, 3))])
	if bd.has("board"):
		var bp := Buyers.board_at(bd)
		out.append([func(ci): board_sign(ci, bp), bp.y + 0.2, Rect2(bp - Vector2(1, 1.5), Vector2(2, 2))])
	return out

## A picnic table on the sand under a striped umbrella.
static func _table(ci: CanvasItem, p: Vector2) -> void:
	Art.ellipse(ci, p + Vector2(0.25, 0.35), 1.0, 0.35, Color(0, 0, 0, 0.18))
	ci.draw_rect(Rect2(p.x - 0.8, p.y - 0.15, 1.6, 0.12), Color("#a8835a"))
	ci.draw_rect(Rect2(p.x - 0.8, p.y + 0.25, 1.6, 0.12), Color("#a8835a"))
	ci.draw_rect(Rect2(p.x - 0.7, p.y - 0.02, 1.4, 0.24), Color("#c9a574"))
	ci.draw_line(p + Vector2(0, 0.1), p + Vector2(0, -1.05), Color("#8a8a8a"), 0.05)
	for i in 8:
		var a0 := i * TAU / 8
		var a1 := (i + 1) * TAU / 8
		var c := p + Vector2(0, -1.1)
		Art.poly(ci, [c, c + Vector2(cos(a0) * 0.95, sin(a0) * 0.45), c + Vector2(cos(a1) * 0.95, sin(a1) * 0.45)], CORAL if i % 2 else PAPER)
	ci.draw_circle(p + Vector2(0, -1.1), 0.06, INK)

## The A-frame chalkboard by a market's door, with today's hot fish on it in chalk.
static func board_sign(ci: CanvasItem, p: Vector2) -> void:
	Art.ellipse(ci, p + Vector2(0.12, 0.18), 0.55, 0.16, Color(0, 0, 0, 0.22))
	ci.draw_line(p + Vector2(-0.4, 0.15), p + Vector2(-0.3, -1.0), Color("#6b5034"), 0.07)
	ci.draw_line(p + Vector2(0.4, 0.15), p + Vector2(0.3, -1.0), Color("#6b5034"), 0.07)
	var r := Rect2(p.x - 0.42, p.y - 1.05, 0.84, 0.95)
	ci.draw_rect(r.grow(0.05), Color("#8a5a35"))
	ci.draw_rect(r, SLATE)
	Art.text(ci, Vector2(p.x, r.position.y + 0.2), "TODAY", 0.11, CHALK)
	for i in 4:
		var yy := r.position.y + 0.36 + i * 0.15
		ci.draw_line(Vector2(r.position.x + 0.1, yy), Vector2(r.position.x + 0.5 + Town.hash2(i, int(p.x)) * 0.15, yy), Color(CHALK, 0.7), 0.035)
		ci.draw_circle(Vector2(r.end.x - 0.14, yy), 0.045, CORAL if i < 2 else Color("#8cc0de"))

# ---------- on the card ----------

static var _o := Vector2.ZERO
static var _s := 1.0

static func _fit(ci: Control, h := H) -> void:
	_s = minf(ci.size.x / W, ci.size.y / h)
	_o = Vector2((ci.size.x - W * _s) / 2.0, (ci.size.y - h * _s) / 2.0)
	ci.draw_set_transform(_o, 0, Vector2(_s, _s))

static func _txt(ci: Control, p: Vector2, s: String, size: int, col: Color, font: Font = null, left := false) -> void:
	var f: Font = font if font else Game.font_bold
	var w := 0.0 if left else f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	ci.draw_string(f, p - Vector2(w, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _box(ci: Control, r: Rect2, fill: Color, lw := 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, INK, false, lw)

static func _shape(ci: Control, pts: PackedVector2Array, fill: Color, lw := 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, lw, true)

## The inside, with the chef or fishmonger behind the counter.
static func inside(ci: Control, bd: Dictionary) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pc: Dictionary = bd.pic
	var shut := not Buyers.open_now(bd)
	_fit(ci)
	var wall := Color(pc.wall)
	ci.draw_rect(Rect2(0, 0, W, H), wall)
	ci.draw_rect(Rect2(0, 150, W, 70), Color(pc.wall2))
	ci.draw_rect(Rect2(0, 146, W, 6), Color(pc.trim))
	if bd.style == "shack":
		for i in 24: ci.draw_line(Vector2(0, 12 + i * 6), Vector2(W, 12 + i * 6), Color(0, 0, 0, 0.08), 1)
	elif bd.style == "hall":
		for i in 16:
			for j in 7: ci.draw_rect(Rect2(i * 40 + (j % 2) * 20, j * 20, 38, 18), Color(0, 0, 0, 0.05))
	ci.draw_rect(Rect2(0, 220, W, 80), Color(pc.floor))
	for i in 9: ci.draw_line(Vector2(0, 228 + i * 9), Vector2(W, 228 + i * 9), Color(0, 0, 0, 0.08), 1)
	_window(ci, Rect2(34, 30, 170, 104), String(pc.window), t)
	# the name across the top
	_box(ci, Rect2(226, 12, 188, 40), PAPER)
	_txt(ci, Vector2(320, 38), String(bd.name).to_upper(), 13, Color(pc.sign_col))
	if bd.kind == "restaurant": _menu_board(ci, bd, Rect2(436, 22, 182, 186))
	else: _mini_board(ci, bd, Rect2(436, 22, 182, 186))
	# the chef or fishmonger
	if not shut:
		ci.draw_set_transform(_o + Vector2(320, 150) * _s, 0, Vector2(_s, _s) * 1.5)
		person(ci, Vector2.ZERO, bd.look, t)
		ci.draw_set_transform(_o, 0, Vector2(_s, _s))
	# the counter: a pass with tickets at a restaurant, a bed of ice with fish at a market
	if bd.kind == "restaurant":
		_box(ci, Rect2(210, 206, 220, 70), Color(pc.trim).darkened(0.25))
		ci.draw_rect(Rect2(210, 206, 220, 10), Color(pc.trim)); ci.draw_rect(Rect2(210, 206, 220, 10), INK, false, 2)
		for i in 4:
			var tx := 236 + i * 46
			_box(ci, Rect2(tx, 186 + (i % 2) * 3, 26, 22), PAPER, 1.2)
			for j in 3: ci.draw_line(Vector2(tx + 4, 193 + j * 5 + (i % 2) * 3), Vector2(tx + 22, 193 + j * 5 + (i % 2) * 3), Color(INK, 0.5), 1)
		# a basket of something fried
		ci.draw_colored_polygon(PackedVector2Array([Vector2(384, 202), Vector2(420, 202), Vector2(414, 214), Vector2(390, 214)]), CORAL)
		for i in 5: ci.draw_circle(Vector2(392 + i * 6, 200 - (i % 2) * 3), 5, Color("#d8a24a"))
	else:
		_box(ci, Rect2(150, 206, 340, 70), Color("#c9d0d4"))
		ci.draw_rect(Rect2(160, 210, 320, 24), Color("#e4f2f6"))
		for i in 20: ci.draw_circle(Vector2(166 + i * 16, 222 + (i % 3) * 3), 5, Color(1, 1, 1, 0.8))
		var bdd := Buyers.board(bd)
		for i in mini(5, bdd.size()):
			FishArt.draw(ci, String(bdd[i][0]), Rect2(166 + i * 62, 206, 58, 24), 0.0)
		# the old floor scale, its needle never quite still
		var sc := Vector2(566, 246)
		ci.draw_rect(Rect2(sc.x - 4, sc.y + 18, 8, 20), Color("#5d6b74"))
		_box(ci, Rect2(sc.x - 34, sc.y + 36, 68, 10), Color("#9aa6ad"))
		ci.draw_circle(sc, 22, INK)
		ci.draw_circle(sc, 19, PAPER)
		for i in 9: ci.draw_line(sc + Vector2.from_angle(PI + i * PI / 8) * 16, sc + Vector2.from_angle(PI + i * PI / 8) * 19, INK, 1)
		var ang := PI * 1.5 + sin(t * 0.7) * 0.3
		ci.draw_line(sc, sc + Vector2.from_angle(ang) * 15, CORAL, 2)
	if shut:
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.06, 0.12, 0.55))
		_box(ci, Rect2(222, 120, 196, 56), PAPER, 2.4)
		_txt(ci, Vector2(320, 148), "CLOSED", 24, CORAL, Game.font_display)
		_txt(ci, Vector2(320, 166), "OPEN " + Buyers.hours_text(bd).to_upper(), 11, INK)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_rect(Rect2(_o, Vector2(W, H) * _s), INK, false, 2)

## What you see out the window: the beach, the street, the river or the market hall.
static func _window(ci: Control, r: Rect2, kind: String, t: float) -> void:
	var h := Game.hour()
	var night := h < 6.0 or h >= 19.5
	var sky := Color("#1e2a4a") if night else Color("#9fd3f0")
	ci.draw_rect(r, sky)
	match kind:
		"sea":
			ci.draw_rect(Rect2(r.position.x, r.position.y + 54, r.size.x, 50), Color("#1f4e79") if night else Color("#3aa6c8"))
			for i in 4: ci.draw_line(Vector2(r.position.x + 10 + i * 40 + sin(t + i) * 4, r.position.y + 66 + i * 8), Vector2(r.position.x + 30 + i * 40 + sin(t + i) * 4, r.position.y + 66 + i * 8), Color(1, 1, 1, 0.5), 2)
			ci.draw_rect(Rect2(r.position.x, r.position.y + 88, r.size.x, 16), Color("#e8d4a0"))
			if not night: ci.draw_circle(r.position + Vector2(130, 28), 12, Color("#ffe08a"))
			else: ci.draw_circle(r.position + Vector2(130, 24), 8, Color("#f4f1ea"))
		"street":
			for i in 4: ci.draw_rect(Rect2(r.position.x + 6 + i * 42, r.position.y + 20 - i % 2 * 10, 34, 70), Color("#8cc0de").darkened(0.1 * i + (0.5 if night else 0.0)))
			ci.draw_rect(Rect2(r.position.x, r.position.y + 86, r.size.x, 18), Color("#3a4248"))
		"river":
			ci.draw_rect(Rect2(r.position.x, r.position.y + 60, r.size.x, 44), Color("#1e3a4a") if night else Color("#4a7a8a"))
			ci.draw_rect(Rect2(r.position.x, r.position.y + 26, r.size.x, 10), Color("#6a6460"))
			for i in 4: ci.draw_rect(Rect2(r.position.x + 18 + i * 44, r.position.y + 36, 8, 26), Color("#6a6460"))
			if night:
				for i in 5: ci.draw_circle(Vector2(r.position.x + 12 + i * 36, r.position.y + 30), 2.5, Color("#ffd28a"))
		"hall":
			ci.draw_rect(r, Color("#6a4a3a"))
			for i in 3: ci.draw_arc(Vector2(r.position.x + 28 + i * 57, r.position.y + 60), 24, PI, TAU, 16, Color("#f2d6a0") if not night else Color("#3a2a2a"), 6)
	for i in [1, 2]: ci.draw_line(Vector2(r.position.x + r.size.x * i / 3.0, r.position.y), Vector2(r.position.x + r.size.x * i / 3.0, r.end.y), PAPER, 3)
	ci.draw_rect(r, PAPER, false, 6)
	ci.draw_rect(r.grow(3), INK, false, 2)

## The chalkboard menu: today's dishes, with the catch of the day boxed.
static func _menu_board(ci: Control, bd: Dictionary, r: Rect2) -> void:
	_box(ci, r.grow(5), Color("#8a5a35"))
	ci.draw_rect(r, SLATE)
	var fry := Buyers.fry_day(bd)
	_txt(ci, Vector2(r.get_center().x, r.position.y + 22), "FISH FRY FRIDAY!" if fry else "TODAY'S MENU", 15 if fry else 14, SUN if fry else CHALK, Game.font_display)
	var m := Buyers.menu(bd)
	var sp := Buyers.special(bd)
	var y := r.position.y + 44
	var step := minf(26.0, (r.size.y - 52) / maxf(1, m.size()))
	var two := step >= 23.0   # room for the fish's name under each dish
	for n in m:
		var dish: String = bd.menu[n]
		var is_sp: bool = n == sp
		if is_sp:
			var hr := Rect2(r.position.x + 6, y - 13, r.size.x - 12, step - 2) if two else Rect2(r.position.x + 6, y - 13, r.size.x - 12, 16)
			ci.draw_rect(hr, Color(1, 1, 1, 0.08))
			ci.draw_rect(hr, Color(SUN, 0.8), false, 1.4)
		_txt(ci, Vector2(r.position.x + 12, y if two else y - 1), dish + ("" if two or not is_sp else " ★"), 11, SUN if is_sp else CHALK, null, true)
		if two: _txt(ci, Vector2(r.position.x + 12, y + 10), ("CATCH OF THE DAY · " if is_sp else "") + n.to_lower(), 8, Color(CHALK, 0.7), null, true)
		y += step

## A few lines of today's prices, on the wall inside a market.
static func _mini_board(ci: Control, bd: Dictionary, r: Rect2) -> void:
	_box(ci, r.grow(5), Color("#8a5a35"))
	ci.draw_rect(r, SLATE)
	_txt(ci, Vector2(r.get_center().x, r.position.y + 22), "TODAY · $/LB", 14, CHALK, Game.font_display)
	var bdd := Buyers.board(bd)
	var rows := bdd.slice(0, 4) + bdd.slice(bdd.size() - 3)
	var y := r.position.y + 46
	for row in rows:
		var tag: String = row[2]
		var col := CORAL.lightened(0.2) if tag == "hot" else Color("#8cc0de") if tag == "cheap" else CHALK
		_txt(ci, Vector2(r.position.x + 12, y), String(row[0]), 11, col, null, true)
		_txt(ci, Vector2(r.end.x - 34, y), "$%.2f" % float(row[3]), 11, col)
		y += 20

## The whole price board, as it hangs outside: every fish, today's price a pound, hot and cheap marked.
static func board_height(bd: Dictionary) -> float: return 92.0 + ceili(bd.get("board_fish", []).size() / 2.0) * 24.0

static func board_pic(ci: Control, bd: Dictionary) -> void:
	var bh := board_height(bd)
	_fit(ci, bh)
	_box(ci, Rect2(0, 0, W, bh), Color("#8a5a35"), 2.4)
	ci.draw_rect(Rect2(10, 10, W - 20, bh - 20), SLATE)
	for i in 30: ci.draw_line(Vector2(10 + Town.hash2(i, 3) * (W - 20), 10 + Town.hash2(3, i) * (bh - 20)), Vector2(30 + Town.hash2(i, 3) * (W - 60), 14 + Town.hash2(3, i) * (bh - 30)), Color(1, 1, 1, 0.04), 3)
	_txt(ci, Vector2(W / 2, 40), "%s · DAY %d" % [String(bd.name).to_upper(), int(Game.S.day)], 18, CHALK, Game.font_display)
	_txt(ci, Vector2(W / 2, 58), "PRICES A POUND · NEW EVERY MORNING · %s PAYS THE SAME EVERY DAY" % Buyers.baseline().to_upper(), 9, Color(CHALK, 0.7))
	var bdd := Buyers.board(bd)
	var half := ceili(bdd.size() / 2.0)
	for i in bdd.size():
		var row: Array = bdd[i]
		var cx := 34.0 if i < half else W / 2 + 14
		var y := 88.0 + (i % half) * 24
		var tag: String = row[2]
		var col := Color("#ff8a6a") if tag == "hot" else Color("#8cc0de") if tag == "cheap" else CHALK
		_txt(ci, Vector2(cx, y), String(row[0]), 14, col, null, true)
		_txt(ci, Vector2(cx + 196, y), "$%.2f" % float(row[3]), 14, col)
		if tag == "hot": _txt(ci, Vector2(cx + 252, y), "▲ HOT", 11, col)
		elif tag == "cheap": _txt(ci, Vector2(cx + 252, y), "▼ CHEAP", 11, col)
		ci.draw_line(Vector2(cx, y + 6), Vector2(cx + 278, y + 6), Color(1, 1, 1, 0.06), 1)
	ci.draw_set_transform(Vector2.ZERO)

## The chef or fishmonger from the waist up, drawn around c in a 640 x 300 card: coat, apron,
## a hat (bandana, cap, hairnet or beanie) and one extra (shades, mustache, glasses, beard). Blinks.
static func person(ci: Control, c: Vector2, look: Dictionary, t: float) -> void:
	c += Vector2(sin(t * 0.8) * 1.0, 0)
	var skin := Color(look.skin)
	var hair := Color(look.hair)
	var coat := Color(look.coat)
	_shape(ci, PackedVector2Array([c + Vector2(-30, 20), c + Vector2(-18, 12), c + Vector2(18, 12), c + Vector2(30, 20), c + Vector2(34, 44), c + Vector2(-34, 44)]), coat)
	_shape(ci, PackedVector2Array([c + Vector2(-16, 22), c + Vector2(16, 22), c + Vector2(18, 44), c + Vector2(-18, 44)]), Color(look.apron), 1.4)
	ci.draw_line(c + Vector2(-16, 22), c + Vector2(-8, 12), Color(look.apron).darkened(0.2), 2)
	ci.draw_line(c + Vector2(16, 22), c + Vector2(8, 12), Color(look.apron).darkened(0.2), 2)
	ci.draw_rect(Rect2(c + Vector2(-4, 4), Vector2(8, 9)), skin.darkened(0.12))
	ci.draw_circle(c + Vector2(-13, -6), 3.4, skin.darkened(0.08))
	ci.draw_circle(c + Vector2(13, -6), 3.4, skin.darkened(0.08))
	ci.draw_circle(c + Vector2(0, -6), 13, skin)
	ci.draw_arc(c + Vector2(0, -6), 13, 0, TAU, 24, INK, 1.4)
	var hc := Color(look.hat_col)
	match String(look.hat):
		"bandana":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -9), c + Vector2(-11, -17), c + Vector2(0, -20), c + Vector2(11, -17), c + Vector2(13, -9)]), hc)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(12, -12), c + Vector2(20, -8), c + Vector2(17, -4)]), hc)
			for i in 3: ci.draw_circle(c + Vector2(-6 + i * 6, -15), 1.1, PAPER)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -9), c + Vector2(-15, 6), c + Vector2(-11, 2)]), hair)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(13, -9), c + Vector2(15, 6), c + Vector2(11, 2)]), hair)
		"cap":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -10), c + Vector2(-10, -19), c + Vector2(10, -19), c + Vector2(13, -10)]), hc)
			_shape(ci, PackedVector2Array([c + Vector2(-14, -11), c + Vector2(14, -11), c + Vector2(22, -7), c + Vector2(-6, -8)]), hc, 1.2)
		"hairnet":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -6), c + Vector2(-12, -17), c + Vector2(0, -21), c + Vector2(12, -17), c + Vector2(14, -6), c + Vector2(8, -12), c + Vector2(-8, -12)]), hair)
			for i in 6: ci.draw_line(c + Vector2(-12 + i * 5, -19), c + Vector2(-14 + i * 5, -10), Color(1, 1, 1, 0.4), 0.8)
			ci.draw_arc(c + Vector2(0, -12), 13, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.5), 1)
		"beanie":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -9), c + Vector2(-11, -20), c + Vector2(0, -24), c + Vector2(11, -20), c + Vector2(14, -9)]), hc)
			ci.draw_rect(Rect2(c + Vector2(-14, -12), Vector2(28, 5)), hc.darkened(0.2))
			ci.draw_circle(c + Vector2(0, -25), 3.5, PAPER)
	var blink := fmod(t + c.x, 3.9) < 0.14
	for sx in [-5, 5]:
		var e := c + Vector2(sx, -5)
		if blink: ci.draw_line(e + Vector2(-2.5, 0), e + Vector2(2.5, 0), INK, 1.4)
		else: ci.draw_circle(e + Vector2(0, 0.6), 1.6, INK)
	ci.draw_arc(c + Vector2(0, 1), 4, 0.3, PI - 0.3, 8, INK, 1.3)
	match String(look.get("extra", "")):
		"shades":
			ci.draw_rect(Rect2(c + Vector2(-11, -21), Vector2(9, 4)), INK)
			ci.draw_rect(Rect2(c + Vector2(2, -21), Vector2(9, 4)), INK)
		"mustache":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -1), c + Vector2(0, -2.5), c + Vector2(7, -1), c + Vector2(5, 1.5), c + Vector2(0, 0), c + Vector2(-5, 1.5)]), hair)
		"glasses":
			ci.draw_arc(c + Vector2(-5, -5), 4, 0, TAU, 12, INK, 1.2)
			ci.draw_arc(c + Vector2(5, -5), 4, 0, TAU, 12, INK, 1.2)
			ci.draw_line(c + Vector2(-1, -5), c + Vector2(1, -5), INK, 1.2)
		"beard":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -3), c + Vector2(-8, 7), c + Vector2(0, 10), c + Vector2(8, 7), c + Vector2(12, -3), c + Vector2(6, 2), c + Vector2(-6, 2)]), hair)
	# hands on the counter
	ci.draw_circle(c + Vector2(-26, 46), 5, skin)
	ci.draw_circle(c + Vector2(26, 46), 5, skin)
