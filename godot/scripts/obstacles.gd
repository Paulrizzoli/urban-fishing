class_name Obstacles
extends RefCounted
## Things you bump into that aren't tiles: cars parked in driveways and lots, cars driving by,
## and the boats at the marina. Each one is a box (centre, angle, half length, half width).
## On foot you bump into cars; in the kayak or skiff you bump into boats.

static var parked: Array = []       # [centre, angle, half length, half width] for every parked car
static var _built := false
static var traffic: Traffic         # set by main, for the cars on the road
static var harbor: Harbor           # set by main, for the marina boats
## Set by main each frame: you have a line out, a card is open or the game is paused. Cars and boats
## wait for you then instead of running you over.
static var player_busy := false

static func reset() -> void:
	_built = false; parked.clear()

## Where the car in a driveway sits and which way it points: [centre, angle].
static func driveway_car(dw: Dictionary) -> Array:
	var r: Rect2 = dw.r
	var d: Vector2i = dw.d
	var near_house := r.position + (Vector2(r.size.x / 2, 1.0) if d.y == 1 else Vector2(r.size.x / 2, r.size.y - 1.0) if d.y == -1 else Vector2(r.size.x - 1.0, r.size.y / 2) if d.x == -1 else Vector2(1.0, r.size.y / 2))
	var rot := (Vector2(d) * -1.0).angle() if Town.hash2(int(r.position.y), 5) > 0.5 else Vector2(d).angle()
	return [near_house, rot]

## The cars parked along a parking lot's top row: [centre, angle, colour index hash] for each.
static func lot_cars(d: Dictionary) -> Array:
	var out := []
	for x in range(d.x0, d.x1 + 1):
		var hh := Town.hash2(x * 17, d.y0 * 5)
		if hh > 0.55: continue
		# keep the space in front of a shop or market door clear, so you can walk out of it
		if Town.t_at(x, d.y0 - 1) == Town.T.DOOR or Town.t_at(x, d.y0 - 2) == Town.T.DOOR: continue
		var cyy: float = d.y0 + 1.15 + (0.12 if hh > 0.3 else 0.0)
		out.append([Vector2(x + 0.53, cyy), PI / 2 if hh > 0.2 else -PI / 2, x])
	return out

static func _build() -> void:
	_built = true
	parked.clear()
	for dw in Town.driveways:
		if not dw.car: continue
		var c := driveway_car(dw)
		parked.append([c[0], c[1], 0.8, 0.39])
	for d in Town.decor:
		if d.k != "parking": continue
		for c in lot_cars(d): parked.append([c[0], c[1], 0.83, 0.4])

## How far a circle of radius r at p sinks into the box (0 if it doesn't touch it).
static func box_depth(p: Vector2, r: float, c: Vector2, ang: float, hl: float, hw: float) -> float:
	var q := (p - c).rotated(-ang)
	var cl := Vector2(clampf(q.x, -hl, hl), clampf(q.y, -hw, hw))
	if cl == q: return r + minf(hl - absf(q.x), hw - absf(q.y))   # centre inside the box
	return maxf(r - q.distance_to(cl), 0.0)

static func box_hit(p: Vector2, r: float, c: Vector2, ang: float, hl: float, hw: float) -> bool:
	return box_depth(p, r, c, ang, hl, hw) > 0.0

## How deep a circle of radius r at p sinks into the deepest car (on_water false) or boat (on_water true)
## it touches, or 0 if it's clear.
static func depth(p: Vector2, r: float, on_water: bool) -> float:
	var d := 0.0
	if on_water:
		if harbor != null:
			for b in harbor.boats:
				if b.out_of_sight() or b.centre.distance_squared_to(p) > 9.0: continue
				d = maxf(d, box_depth(p, r, b.centre, b.heading, Harbor.HL, Harbor.HW))
		return d
	if not _built: _build()
	for o in parked:
		if o[0].distance_squared_to(p) < 4.0: d = maxf(d, box_depth(p, r, o[0], o[1], o[2], o[3]))
	if traffic != null:
		for c in traffic.cars:
			if not c.visible or c.fade < 0.5 or c.position.distance_squared_to(p) > 4.0: continue
			d = maxf(d, box_depth(p, r, c.position, c.ang, c.L * 0.5, c.W * 0.5))
	return d

## The tiles a parked car fills, so a walk you click for goes around parked cars instead of
## into them (and stopping there).
static func parked_tiles() -> Array:
	if not _built: _build()
	var out := []
	for o in parked:
		var c: Vector2 = o[0]
		for y in range(floori(c.y) - 2, floori(c.y) + 3):
			for x in range(floori(c.x) - 2, floori(c.x) + 3):
				if box_depth(Vector2(x + 0.5, y + 0.5), 0.2, c, o[1], o[2], o[3]) > 0.0: out.append(Vector2i(x, y))
	return out

static func blocked(p: Vector2, r: float, on_water: bool) -> bool: return depth(p, r, on_water) > 0.0
