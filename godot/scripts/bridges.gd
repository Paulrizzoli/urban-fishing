class_name Bridges
## Bridges over the water you can paddle under. The deck is drawn above the water and anything on it,
## so a kayak, a skiff, fish and the wake slip out of sight underneath. Paddle in under one and the deck
## fades so you can still see yourself, dimmed in the shade. The water under and beside a bridge is
## shaded and darker, fish gather there, and at night snook and tarpon hang around under the bridge lights.

const REACH := 2.2        # how far the shade reaches out past a bridge onto the water, in tiles
const SEE := 0.45         # how much the deck fades while you're under it

## One entry per bridge in Town.bridges: { r: Rect2, h (the road runs left-right, the water up-down),
## wet (over water), lit (road bridges have lights), foot, road, see (0..1, eased by Main) }
static var list: Array = []
static var _under := PackedInt32Array()   # per tile: 1 + the bridge over the water there, or 0
static var _done := false

## Forget the bridges, after the map changes (going to the other town).
static func reset() -> void:
	list = []; _under = PackedInt32Array(); _done = false

static func setup() -> void:
	if _done: return
	_done = true
	_under.resize(Town.MW * Town.MH); _under.fill(0)
	for b in Town.bridges:
		var r := Rect2(b.x0, b.y0, b.x1 - b.x0 + 1, b.y1 - b.y0 + 1)
		var wet := false
		for y in range(b.y0, b.y1 + 1):
			for x in range(b.x0, b.x1 + 1):
				if Town.region[Town.idx(x, y)] > 0: wet = true
		var foot: bool = b.get("foot", false)
		var high: bool = b.get("high", false)
		var e := { "r": r, "h": b.get("h", false), "wet": wet, "foot": foot, "road": b.get("road", false), "lit": wet and not foot, "see": 0.0, "high": high, "susp": b.get("susp", false),
			"gx0": float(b.get("gx0", b.x0)), "gx1": float(b.get("gx1", b.x1 + 1)) }
		list.append(e)
		if high: continue
		if wet:
			for y in range(b.y0, b.y1 + 1):
				for x in range(b.x0, b.x1 + 1):
					if Town.region[Town.idx(x, y)] > 0: _under[Town.idx(x, y)] = list.size()
		if e.lit: _add_lamps(e)

## A street lamp on each side of a road bridge, unless one already stands there.
static func _add_lamps(e: Dictionary) -> void:
	var r: Rect2 = e.r
	var spots: Array
	if e.h: spots = [Vector2(r.position.x + 0.15, r.position.y + 0.45), Vector2(r.position.x + 0.15, r.end.y - 0.4)]
	else: spots = [Vector2(r.position.x + 0.3, r.get_center().y), Vector2(r.end.x - 0.7, r.get_center().y)]
	if e.road: spots = [Vector2(r.position.x + 0.15, r.position.y + 0.15)]
	for p in spots:
		var taken := false
		for lp in Town.lamps:
			if lp.distance_to(p) < 2.5: taken = true
		if not taken: Town.lamps.append(p)

## The high bridge (Ironwater's viaduct, Gannet Harbor's suspension bridge) over p, on land or water, or -1.
static func high_at(p: Vector2) -> int:
	for i in list.size():
		var e: Dictionary = list[i]
		if e.high and e.r.has_point(p): return i
	return -1

## The bridge over the water at p, or -1.
static func covered(p: Vector2) -> int:
	var x := floori(p.x)
	var y := floori(p.y)
	if not Town.inb(x, y) or _under.is_empty(): return -1
	var u := _under[Town.idx(x, y)] - 1
	if u < 0 and Town.is_water_t(Town.tile[Town.idx(x, y)]): return high_at(p)
	return u

## Water under a bridge (the tile is road on top, but fish swim and boats paddle under it).
static func wet_tile(x: int, y: int) -> bool: return Town.inb(x, y) and covered(Vector2(x + 0.5, y + 0.5)) >= 0

## Is any part of a boat at p, pointing along a, under a deck?
static func hull_under(p: Vector2, a: float, half: float) -> bool:
	var f := Vector2.from_angle(a) * half
	for q in [p, p + f, p - f, p + f * 0.5, p - f * 0.5]:
		if covered(q + Vector2(0, 0.1)) >= 0: return true
	return false

## How shaded the water is at p by a bridge: 1 under it, fading to 0 a couple of tiles out.
static func shade_at(p: Vector2) -> float:
	var best := 0.0
	for e in list:
		if not e.wet: continue
		var r: Rect2 = e.r
		var d: float
		if e.h:
			if p.x < r.position.x or p.x > r.end.x: continue
			d = maxf(r.position.y - p.y, p.y - r.end.y)
		else:
			if p.y < r.position.y or p.y > r.end.y: continue
			d = maxf(r.position.x - p.x, p.x - r.end.x)
		best = maxf(best, clampf(1.0 - d / REACH, 0.0, 1.0) if d > 0 else 1.0)
	return best

## Under the lights of a road bridge, after dark.
static func lit_at(p: Vector2) -> bool:
	if Game.darkness() < 0.3: return false
	for e in list:
		if e.lit and e.r.grow(REACH).has_point(p): return shade_at(p) > 0.1
	return false

## Fish that like the shade under a bridge, and how much more often they turn up there.
## At night, snook and tarpon wait under the bridge lights for bait swept past in the light.
static func boosts(night: bool) -> Dictionary:
	if Town.level == 2:
		# under the Gannet Narrows Bridge: big stripers and blues in the lights at night, tautog and sea bass on the tower rocks by day
		if night: return { "Striped Bass": 3.2, "Bluefish": 2.2, "Conger Eel": 1.6, "The Toll Taker": 1.5 }
		return { "Tautog": 2.2, "Black Sea Bass": 2.0, "Scup": 1.5, "Striped Bass": 1.3 }
	if Town.level == 1:
		# under the Ironwater bridges: walleye and sauger in the lights at night, smallmouth and drum in the shade by day
		if night: return { "Walleye": 3.0, "Sauger": 2.5, "Flathead Catfish": 1.8, "The Viaduct Ghost": 1.5 }
		return { "Smallmouth Bass": 2.0, "Freshwater Drum": 1.8, "Channel Catfish": 1.4 }
	if night: return { "Snook": 3.5, "Tarpon": 2.5, "Mangrove Snapper": 1.6, "The Bridge Troll": 1.5 }
	return { "Mangrove Snapper": 2.2, "Sheepshead": 2.0, "Snook": 1.6, "Redfish": 1.3 }

# ---------- drawing ----------

## Under the bridges (drawn below the fish): dark water where the deck shades it, and the shade
## spreading out onto the open water on both sides.
static func draw_under(ci: CanvasItem, view: Rect2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for e in list:
		if not e.wet: continue
		var r: Rect2 = e.r
		if not view.intersects(r.grow(REACH + 1)): continue
		if e.high: _high_under(ci, e, view, now)
		for y in range(int(r.position.y), int(r.end.y)):
			for x in range(int(r.position.x), int(r.end.x)):
				if e.high and (x < view.position.x - 1 or x > view.end.x + 1): continue
				if Town.region[Town.idx(x, y)] == 0: continue
				var deep := Art.shade(Color(Ground.water_pal(x, y)[1]), -0.45)
				ci.draw_rect(Rect2(x, y, 1, 1), deep)
				# slow glints of the light coming in from the ends
				var gl := 0.05 + 0.04 * sin(now * 1.3 + x * 1.7 + y * 2.3)
				if e.h: ci.draw_rect(Rect2(x + 0.15 + sin(now + y) * 0.1, y + 0.45, 0.6, 0.05), Color(1, 1, 1, gl))
				else: ci.draw_rect(Rect2(x + 0.45, y + 0.15 + sin(now + x) * 0.1, 0.05, 0.6), Color(1, 1, 1, gl))
		# the shade out on the open water, darkest right at the bridge
		_shade_side(ci, e, -1)
		_shade_side(ci, e, 1)

static func _shade_side(ci: CanvasItem, e: Dictionary, sgn: int) -> void:
	var r: Rect2 = e.r
	var col := Color(0.02, 0.08, 0.12)
	var a0 := 0.5 if sgn > 0 else 0.4     # the sun is up and to the left, so the far side gets more
	var n := ceili(REACH)
	for k in n:
		var t0 := float(k) / REACH
		var t1 := minf(1.0, float(k + 1) / REACH)
		var c0 := Color(col, a0 * pow(1.0 - t0, 1.5))
		var c1 := Color(col, a0 * pow(1.0 - t1, 1.5))
		if e.h:
			for x in range(int(r.position.x), int(r.end.x)):
				var y: int = int(r.end.y) + k if sgn > 0 else int(r.position.y) - 1 - k
				if not Town.is_water_t(Town.t_at(x, y)): continue
				var ya := float(y) if sgn > 0 else float(y + 1)
				var yb := float(y + 1) if sgn > 0 else float(y)
				ci.draw_polygon(PackedVector2Array([Vector2(x, ya), Vector2(x + 1, ya), Vector2(x + 1, yb), Vector2(x, yb)]), PackedColorArray([c0, c0, c1, c1]))
		else:
			for y in range(int(r.position.y), int(r.end.y)):
				var x: int = int(r.end.x) + k if sgn > 0 else int(r.position.x) - 1 - k
				if not Town.is_water_t(Town.t_at(x, y)): continue
				var xa := float(x) if sgn > 0 else float(x + 1)
				var xb := float(x + 1) if sgn > 0 else float(x)
				ci.draw_polygon(PackedVector2Array([Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + 1), Vector2(xa, y + 1)]), PackedColorArray([c0, c1, c1, c0]))

## The decks, drawn over boats, fish and the wake. Each fades while you're under it.
static func draw_decks(ci: CanvasItem, view: Rect2) -> void:
	for e in list:
		if not e.high and view.intersects(e.r.grow(1)): _deck(ci, e)

## The high deck, drawn over everything under it (people, cars, trees). It fades while you're under it.
static func draw_high(ci: CanvasItem, view: Rect2) -> void:
	for e in list:
		if e.high and view.intersects(e.r.grow(3)): _high_deck(ci, e, view)

## Under the viaduct on land: a soft shadow across the ground, darkest in the middle.
static func _high_under(ci: CanvasItem, e: Dictionary, view: Rect2, _now: float) -> void:
	var r: Rect2 = e.r
	var x0 := maxf(r.position.x, view.position.x - 1)
	var x1 := minf(r.end.x, view.end.x + 1)
	var sh := Color(0.02, 0.05, 0.1, 0.34)
	ci.draw_rect(Rect2(x0, r.position.y, x1 - x0, r.size.y), sh)
	# the shadow spills out a little on the south side, where the sun can't reach
	ci.draw_polygon(PackedVector2Array([Vector2(x0, r.end.y), Vector2(x1, r.end.y), Vector2(x1, r.end.y + 1.6), Vector2(x0, r.end.y + 1.6)]),
		PackedColorArray([sh, sh, Color(sh, 0.0), Color(sh, 0.0)]))

static func _high_deck(ci: CanvasItem, e: Dictionary, view: Rect2) -> void:
	if e.susp: _susp_deck(ci, e, view); return
	var r: Rect2 = e.r
	var A: float = 1.0 - 0.6 * e.see
	var x0 := maxf(r.position.x, view.position.x - 2)
	var x1 := minf(r.end.x, view.end.x + 2)
	var w := x1 - x0
	var y0 := r.position.y
	var y1 := r.end.y
	var now := Time.get_ticks_msec() / 1000.0
	var steel := Color("#3e6f7c", A)
	var steel_dk := Color("#2b4f5a", A)
	var asphalt := Color("#474c54", A)
	# the girders seen from the south side, painted steel with a truss pattern
	ci.draw_rect(Rect2(x0, y1 - 0.15, w, 0.7), steel_dk)
	ci.draw_rect(Rect2(x0, y1 - 0.15, w, 0.12), steel)
	var k := floorf(x0)
	while k < x1:
		ci.draw_line(Vector2(k, y1 - 0.05), Vector2(k + 0.5, y1 + 0.5), steel, 0.07)
		ci.draw_line(Vector2(k + 0.5, y1 + 0.5), Vector2(k + 1.0, y1 - 0.05), steel, 0.07)
		k += 1.0
	ci.draw_rect(Rect2(x0, y1 + 0.5, w, 0.08), steel)
	# the piers under the girders
	for px in [6, 26, 34, 52, 59, 78, 88, 106]:
		if px + 2 < x0 or px > x1: continue
		ci.draw_rect(Rect2(px + 0.1, y1 + 0.58, 1.8, 1.0), Color("#a9a59c", A))
		ci.draw_rect(Rect2(px + 1.4, y1 + 0.58, 0.5, 1.0), Color("#86827a", A))
		ci.draw_rect(Rect2(px + 0.1, y1 + 1.5, 1.8, 0.12), Color(0, 0, 0, 0.25 * A))
	# the deck: shoulders, two lanes each way, a concrete barrier in the middle
	ci.draw_rect(Rect2(x0, y0 - 0.3, w, r.size.y + 0.3), asphalt)
	ci.draw_rect(Rect2(x0, y0 - 0.3, w, 0.3), Color("#9a9ea4", A))
	ci.draw_rect(Rect2(x0, y1 - 0.45, w, 0.3), Color("#9a9ea4", A))
	var mid := (y0 + y1 - 0.45) / 2.0
	ci.draw_rect(Rect2(x0, mid - 0.12, w, 0.24), Color("#c9ccd0", A))
	for ly in [y0 + 0.9, mid + 1.0]:
		var dx := floorf(x0)
		while dx < x1:
			ci.draw_rect(Rect2(dx + 0.2, ly, 0.6, 0.07), Color(1, 1, 1, 0.55 * A)); dx += 1.6
	ci.draw_rect(Rect2(x0, y0 + 0.05, w, 0.05), Color("#e3b23c", 0.8 * A)); ci.draw_rect(Rect2(x0, y1 - 0.6, w, 0.05), Color("#e3b23c", 0.8 * A))
	# traffic up on the interstate, both ways, never stopping
	var lanes := [[y0 + 0.5, 1.0, 6.0], [y0 + 1.4, 1.0, 7.5], [mid + 0.6, -1.0, 6.5], [mid + 1.45, -1.0, 8.0]]
	for li in lanes.size():
		var L: Array = lanes[li]
		for j in 6:
			var span := float(Town.MW) + 24.0
			var cx := fposmod(now * L[2] * L[1] + j * span / 6.0 + li * 7.3, span) - 12.0
			if cx < x0 - 3 or cx > x1 + 3: continue
			var big := (j + li) % 5 == 0
			Art.car(ci, Vector2(cx, L[0]), 0.0 if L[1] > 0 else PI, Color(Art.CAR_COLORS[(j * 3 + li) % Art.CAR_COLORS.size()], A), 2.6 if big else 1.7, 0.8 if big else 0.72)
	# light posts along the barrier
	var p := ceilf(x0 / 9.0) * 9.0
	while p < x1:
		ci.draw_rect(Rect2(p, mid - 0.05, 0.1, 0.1), Color("#6c7178", A)); p += 9.0

static func _deck(ci: CanvasItem, e: Dictionary) -> void:
	var r: Rect2 = e.r
	var A: float = 1.0 - SEE * e.see
	var asphalt := Color("#4b5058", A)
	var walk := Color("#d8d2c4", A)
	var RA := minf(1.0, A + 0.3)     # the railings stay easy to see
	var rail := Color("#9a9ea4", RA)
	var rail_top := Color("#c9ccd0", RA)
	var post := Color("#6c7178", RA)
	var dash := Color("#e3b23c", 0.85 * A)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var hh := r.size.y
	if e.h:
		if e.foot: ci.draw_rect(r, Color("#d8d1c1", A))
		elif e.road: ci.draw_rect(r, asphalt)
		else:
			ci.draw_rect(Rect2(x0, y0, w, 1), walk); ci.draw_rect(Rect2(x0, r.end.y - 1, w, 1), walk)
			ci.draw_rect(Rect2(x0, y0 + 1, w, hh - 2), asphalt)
			_dashes(ci, Vector2(x0, y0 + hh / 2.0), Vector2(1, 0), w, dash)
			ci.draw_rect(Rect2(x0, y0 + 0.97, w, 0.06), Color(0, 0, 0, 0.18 * A)); ci.draw_rect(Rect2(x0, r.end.y - 1.03, w, 0.06), Color(0, 0, 0, 0.18 * A))
		if e.wet:
			# parapets along the edges over the water, with posts
			for yy in [y0, r.end.y - 0.18]:
				ci.draw_rect(Rect2(x0, yy, w, 0.18), rail)
				ci.draw_rect(Rect2(x0, yy, w, 0.05), rail_top)
				var k := 0.25
				while k < w:
					ci.draw_rect(Rect2(x0 + k - 0.03, yy + 0.03, 0.06, 0.12), post); k += 0.5
			# the deck's edge seen from the side, and its shadow
			ci.draw_rect(Rect2(x0, r.end.y, w, 0.14), Color("#7b7f85", A))
			ci.draw_rect(Rect2(x0, r.end.y + 0.14, w, 0.22), Color(0, 0, 0, 0.28 * A))
		else:
			ci.draw_rect(Rect2(x0, y0, w, 0.12), Color("#8b8f96", A)); ci.draw_rect(Rect2(x0, r.end.y - 0.12, w, 0.12), Color("#8b8f96", A))
			ci.draw_rect(Rect2(x0, r.end.y, w, 0.3), Color(0, 0, 0, 0.25 * A))
		return
	if e.foot:   # a footbridge running up and down: a plank deck between the rails
		ci.draw_rect(r, Color("#d8d1c1", A))
		var py := y0 + 0.5
		while py < r.end.y:
			ci.draw_rect(Rect2(x0 + 0.2, py, w - 0.4, 0.04), Color(0, 0, 0, 0.08 * A)); py += 0.5
	else:
		ci.draw_rect(Rect2(x0 + 1, y0, w - 2, hh), asphalt)
		ci.draw_rect(Rect2(x0, y0, 1, hh), walk); ci.draw_rect(Rect2(r.end.x - 1, y0, 1, hh), walk)
		_dashes(ci, Vector2(x0 + w / 2.0, y0), Vector2(0, 1), hh, dash)
		ci.draw_rect(Rect2(x0 + 0.97, y0, 0.06, hh), Color(0, 0, 0, 0.18 * A)); ci.draw_rect(Rect2(r.end.x - 1.03, y0, 0.06, hh), Color(0, 0, 0, 0.18 * A))
	for xx in [x0, r.end.x - 0.18]:
		ci.draw_rect(Rect2(xx, y0, 0.18, hh), rail)
		ci.draw_rect(Rect2(xx, y0, 0.05, hh), rail_top)
		var k := 0.25
		while k < hh:
			ci.draw_rect(Rect2(xx + 0.03, y0 + k - 0.03, 0.12, 0.06), post); k += 0.5
	ci.draw_rect(Rect2(r.end.x, y0, 0.12, hh), Color("#7b7f85", A))
	ci.draw_rect(Rect2(r.end.x + 0.12, y0, 0.3, hh), Color(0, 0, 0, 0.26 * A))
	ci.draw_rect(Rect2(x0 - 0.1, y0, 0.1, hh), Color(0, 0, 0, 0.14 * A))

static func _dashes(ci: CanvasItem, from: Vector2, along: Vector2, length: float, col: Color) -> void:
	var side := Vector2(along.y, along.x)
	var k := 0.25
	while k + 0.5 <= length:
		var a: Vector2 = from + along * k - side * 0.05
		ci.draw_rect(Rect2(a, along * 0.5 + side * 0.1).abs(), col)
		k += 1.0

## At night, warm light from the bridge lamps spilling onto the water on both sides (additive glow layer).
static func draw_glow(ci: CanvasItem, view: Rect2, a: float, glow: Callable) -> void:
	var warm := Color(1.0, 0.74, 0.4)
	var now := Time.get_ticks_msec() / 1000.0
	for e in list:
		if not e.lit or not view.intersects(e.r.grow(3)): continue
		var r: Rect2 = e.r
		var gx: float = (e.gx0 + e.gx1) / 2.0
		var ends: Array = [Vector2(gx, r.position.y - 0.6), Vector2(gx, r.end.y + 0.7)] if e.h else \
			[Vector2(r.position.x - 0.7, r.get_center().y), Vector2(r.end.x + 0.7, r.get_center().y)]
		for p in ends:
			if not Town.is_water_t(Town.t_at(floori(p.x), floori(p.y))): continue
			glow.call(ci, p, 1.5, Color(warm, 0.16 * a))
			# broken glints of lamplight on the ripples where the shadow ends
			var L: float = (e.gx1 - e.gx0) if e.h else r.size.y
			var n := int(L * 2.0)
			for j in n:
				var f := (j + 0.5) / n
				var wob := sin(now * 2.2 + j * 1.9 + p.x + p.y) * 0.12
				var lit := 0.5 + 0.5 * sin(now * 1.7 + j * 2.7 + p.x)
				var c := Color(warm, 0.2 * a * lit)
				if e.h: ci.draw_rect(Rect2(e.gx0 + f * L - 0.15 + wob * 0.5, p.y + wob, 0.3, 0.05), c)
				else: ci.draw_rect(Rect2(p.x + wob, r.position.y + f * L - 0.15 + wob * 0.5, 0.05, 0.3), c)

## Gannet Harbor's suspension bridge: the deck on its stiffening truss, two towers rising high above it,
## the main cables sweeping down from the tower tops between them and out to the anchorages, with the
## hangers dropping to the deck. After dark the cables are strung with lights.
const SUSP_H := 13.0         # how high the tower tops stand above the deck, drawn straight up
const SUSP_ANCHOR := [52.0, 109.0]   # where the main cables come down to the anchorages
static func _susp_deck(ci: CanvasItem, e: Dictionary, view: Rect2) -> void:
	var r: Rect2 = e.r
	var A: float = 1.0 - 0.6 * e.see
	var x0 := maxf(r.position.x, view.position.x - 2)
	var x1 := minf(r.end.x, view.end.x + 2)
	var w := x1 - x0
	var y0 := r.position.y
	var y1 := r.end.y
	var now := Time.get_ticks_msec() / 1000.0
	var steel := Color("#7d949c", A)
	var steel_dk := Color("#56707a", A)
	var asphalt := Color("#474c54", A)
	var dark := Game.darkness() > 0.3
	# the stiffening truss along the south face
	ci.draw_rect(Rect2(x0, y1 - 0.15, w, 0.75), steel_dk)
	ci.draw_rect(Rect2(x0, y1 - 0.15, w, 0.12), steel)
	var k := floorf(x0)
	while k < x1:
		ci.draw_line(Vector2(k, y1 - 0.05), Vector2(k + 0.5, y1 + 0.55), steel, 0.06)
		ci.draw_line(Vector2(k + 0.5, y1 + 0.55), Vector2(k + 1.0, y1 - 0.05), steel, 0.06)
		k += 1.0
	ci.draw_rect(Rect2(x0, y1 + 0.55, w, 0.08), steel)
	# the approach piers on land
	for px in Gannet.PIERS:
		if px + 2 < x0 or px > x1: continue
		ci.draw_rect(Rect2(px + 0.1, y1 + 0.63, 1.8, 1.0), Color("#a9a59c", A))
		ci.draw_rect(Rect2(px + 1.4, y1 + 0.63, 0.5, 1.0), Color("#86827a", A))
	# the deck: shoulders, two lanes each way, a barrier down the middle
	ci.draw_rect(Rect2(x0, y0 - 0.3, w, r.size.y + 0.3), asphalt)
	ci.draw_rect(Rect2(x0, y0 - 0.3, w, 0.3), Color("#9a9ea4", A))
	ci.draw_rect(Rect2(x0, y1 - 0.45, w, 0.3), Color("#9a9ea4", A))
	var mid := (y0 + y1 - 0.45) / 2.0
	ci.draw_rect(Rect2(x0, mid - 0.12, w, 0.24), Color("#c9ccd0", A))
	for ly in [y0 + 0.9, mid + 1.0]:
		var dx := floorf(x0)
		while dx < x1:
			ci.draw_rect(Rect2(dx + 0.2, ly, 0.6, 0.07), Color(1, 1, 1, 0.55 * A)); dx += 1.6
	ci.draw_rect(Rect2(x0, y0 + 0.05, w, 0.05), Color("#e3b23c", 0.8 * A)); ci.draw_rect(Rect2(x0, y1 - 0.6, w, 0.05), Color("#e3b23c", 0.8 * A))
	var lanes := [[y0 + 0.5, 1.0, 6.0], [y0 + 1.4, 1.0, 7.5], [mid + 0.6, -1.0, 6.5], [mid + 1.45, -1.0, 8.0]]
	for li in lanes.size():
		var L: Array = lanes[li]
		for j in 6:
			var span := float(Town.MW) + 24.0
			var cx := fposmod(now * L[2] * L[1] + j * span / 6.0 + li * 7.3, span) - 12.0
			if cx < x0 - 3 or cx > x1 + 3: continue
			var big := (j + li) % 5 == 0
			Art.car(ci, Vector2(cx, L[0]), 0.0 if L[1] > 0 else PI, Color(Art.CAR_COLORS[(j * 3 + li) % Art.CAR_COLORS.size()], A), 2.6 if big else 1.7, 0.8 if big else 0.72)
	# the anchorages, where the cables come down: big concrete blocks on both sides of the deck
	for ax in SUSP_ANCHOR:
		if ax + 3 < x0 or ax - 3 > x1: continue
		for ay in [y0 - 0.9, y1 - 0.2]:
			ci.draw_rect(Rect2(ax - 1.6, ay, 3.2, 1.1), Color("#b9b4a8", A))
			ci.draw_rect(Rect2(ax - 1.6, ay, 3.2, 0.2), Color("#d6d1c4", A))
			ci.draw_rect(Rect2(ax + 0.9, ay, 0.7, 1.1), Color("#9a958a", A))
	# the cables and hangers on the north side, then the towers, then the south side in front
	_susp_cable(ci, x0, x1, y0 + 0.1, A, dark, now)
	for tx in Gannet.TOWERS: _susp_tower(ci, float(tx) + 1.0, y0, y1, A, dark, now)
	_susp_cable(ci, x0, x1, y1 - 0.25, A, dark, now)

## How high the main cable is over the deck at x: up at the tower tops, sagging to just over the deck in
## the middle of the main span, and down to the deck at the anchorages.
static func _cable_h(x: float) -> float:
	var t0: float = Gannet.TOWERS[0] + 1.0
	var t1: float = Gannet.TOWERS[1] + 1.0
	if x <= SUSP_ANCHOR[0] or x >= SUSP_ANCHOR[1]: return -1.0
	if x < t0:
		var u := (x - SUSP_ANCHOR[0]) / (t0 - SUSP_ANCHOR[0])
		return SUSP_H * u * (0.55 + 0.45 * u)
	if x > t1:
		var u := (SUSP_ANCHOR[1] - x) / (SUSP_ANCHOR[1] - t1)
		return SUSP_H * u * (0.55 + 0.45 * u)
	var m := (x - (t0 + t1) / 2.0) / ((t1 - t0) / 2.0)
	return 0.9 + (SUSP_H - 0.9) * m * m

static func _susp_cable(ci: CanvasItem, x0: float, x1: float, deck_y: float, A: float, dark: bool, now: float) -> void:
	var a0 := maxf(x0, SUSP_ANCHOR[0])
	var a1 := minf(x1, SUSP_ANCHOR[1])
	if a1 <= a0: return
	var col := Color("#c9d2d6", A)
	var hang := Color(0.8, 0.84, 0.86, 0.75 * A)
	# hangers, one every tile
	var hx := ceilf(a0)
	while hx < a1:
		var h := _cable_h(hx)
		if h > 0.25: ci.draw_line(Vector2(hx, deck_y - h), Vector2(hx, deck_y), hang, 0.035)
		hx += 1.0
	var pts := PackedVector2Array()
	var x := a0
	while x <= a1:
		pts.append(Vector2(x, deck_y - maxf(0.0, _cable_h(x)))); x += 0.5
	pts.append(Vector2(a1, deck_y - maxf(0.0, _cable_h(a1))))
	if pts.size() > 1:
		ci.draw_polyline(pts, Color(0.2, 0.26, 0.3, 0.5 * A), 0.22)
		ci.draw_polyline(pts, col, 0.14)
	# the necklace lights along the cables after dark
	if dark:
		var lx := ceilf(a0 * 0.5) * 2.0
		while lx < a1:
			var tw := 0.75 + 0.25 * sin(now * 2.0 + lx)
			ci.draw_circle(Vector2(lx, deck_y - maxf(0.0, _cable_h(lx))), 0.09, Color(1.0, 0.93, 0.7, tw * A))
			lx += 2.0

## One tower: two tall legs seen one behind the other, with the portal struts between them, a cap with the
## cable saddles and a red light on top.
static func _susp_tower(ci: CanvasItem, cx: float, y0: float, y1: float, A: float, dark: bool, now: float) -> void:
	var top := y0 + 0.1 - SUSP_H
	var face := Color("#8ea3aa", A)
	var side := Color("#6a818a", A)
	var lit := Color("#b3c4c9", A)
	# the base on the water (or the rocks) below the south edge of the deck
	ci.draw_rect(Rect2(cx - 1.1, y1 - 0.2, 2.2, 1.2), Color("#a9a59c", A))
	ci.draw_rect(Rect2(cx - 1.1, y1 + 0.8, 2.2, 0.15), Color(0, 0, 0, 0.25 * A))
	# the legs, tapering a little toward the top
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 0.75, y1 + 0.2), Vector2(cx + 0.75, y1 + 0.2), Vector2(cx + 0.55, top), Vector2(cx - 0.55, top)]), face)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx + 0.35, y1 + 0.2), Vector2(cx + 0.75, y1 + 0.2), Vector2(cx + 0.55, top), Vector2(cx + 0.3, top)]), side)
	ci.draw_line(Vector2(cx - 0.72, y1 + 0.2), Vector2(cx - 0.53, top), lit, 0.08)
	# the recessed panels and the portal struts
	for k in 4:
		var py := lerpf(y1 - 1.0, top + 1.2, k / 3.0)
		ci.draw_rect(Rect2(cx - 0.62, py - 0.25, 1.24, 0.42), side)
		ci.draw_rect(Rect2(cx - 0.62, py - 0.25, 1.24, 0.08), lit)
	for k in 3:
		var py := lerpf(y1 - 1.8, top + 2.4, k / 2.0)
		ci.draw_rect(Rect2(cx - 0.3, py - 1.3, 0.35, 1.0), Color(0.05, 0.1, 0.14, 0.35 * A))
	# the cap and saddles
	ci.draw_rect(Rect2(cx - 0.7, top - 0.35, 1.4, 0.45), lit)
	ci.draw_rect(Rect2(cx - 0.7, top + 0.0, 1.4, 0.1), side)
	var blink := 0.5 + 0.5 * sin(now * 2.6 + cx)
	ci.draw_circle(Vector2(cx, top - 0.5), 0.13, Color(1, 0.2, 0.15, (0.55 + 0.45 * blink if dark else 0.8) * A))
