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
		var e := { "r": r, "h": b.get("h", false), "wet": wet, "foot": foot, "road": b.get("road", false), "lit": wet and not foot, "see": 0.0 }
		list.append(e)
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

## The bridge over the water at p, or -1.
static func covered(p: Vector2) -> int:
	var x := floori(p.x)
	var y := floori(p.y)
	if not Town.inb(x, y) or _under.is_empty(): return -1
	return _under[Town.idx(x, y)] - 1

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
		for y in range(int(r.position.y), int(r.end.y)):
			for x in range(int(r.position.x), int(r.end.x)):
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
		if view.intersects(e.r.grow(1)): _deck(ci, e)

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
		var ends: Array = [Vector2(r.get_center().x, r.position.y - 0.6), Vector2(r.get_center().x, r.end.y + 0.7)] if e.h else \
			[Vector2(r.position.x - 0.7, r.get_center().y), Vector2(r.end.x + 0.7, r.get_center().y)]
		for p in ends:
			if not Town.is_water_t(Town.t_at(floori(p.x), floori(p.y))): continue
			glow.call(ci, p, 1.5, Color(warm, 0.16 * a))
			# broken glints of lamplight on the ripples where the shadow ends
			var L: float = r.size.x if e.h else r.size.y
			var n := int(L * 2.0)
			for j in n:
				var f := (j + 0.5) / n
				var wob := sin(now * 2.2 + j * 1.9 + p.x + p.y) * 0.12
				var lit := 0.5 + 0.5 * sin(now * 1.7 + j * 2.7 + p.x)
				var c := Color(warm, 0.2 * a * lit)
				if e.h: ci.draw_rect(Rect2(r.position.x + f * L - 0.15 + wob * 0.5, p.y + wob, 0.3, 0.05), c)
				else: ci.draw_rect(Rect2(p.x + wob, r.position.y + f * L - 0.15 + wob * 0.5, 0.05, 0.3), c)
