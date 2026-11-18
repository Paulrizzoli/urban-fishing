class_name Player
extends Node2D
## The angler: keyboard walking, click-to-walk on a grid path, tile collision,
## and paddling or motoring around in the kayak or the skiff.

var face := PI / 2
var moving := false
var bob := 0.0
var path: Array = []
var walk_grid := AStarGrid2D.new()
var boat_grids := {}      # "kayak" / "skiff" -> AStarGrid2D, built the first time you launch
var fishing_pose := false
var rod_pull := 0        # set by Fishing: -1 / 0 / 1 while you pull against a fish
var rod_bend := 0.0      # set by Fishing: how hard the rod bows under the line's tension
var wake: Array = []

func _ready() -> void:
	position = Vector2(Game.S.x, Game.S.y)
	face = Game.S.face
	walk_grid = _grid(func(x, y): return walk_solid(x, y))

func _grid(solid: Callable) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, Town.MW, Town.MH)
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for y in Town.MH:
		for x in Town.MW:
			if solid.call(x, y): g.set_point_solid(Vector2i(x, y))
	return g

## Static walls for path planning. Gates count as open; collision decides at the gate itself.
static func walk_solid(x: int, y: int) -> bool:
	var t: int = Town.tile[Town.idx(x, y)]
	if t == Town.T.PGATE or t == Town.T.HGATE or t == Town.T.GRATE: return false
	return t in Town.BLOCK

## Call after the walkable map changes.
func rebuild_grids() -> void:
	walk_grid = _grid(func(x, y): return walk_solid(x, y))
	boat_grids.clear()

static func zone_of(p: Vector2) -> int:
	return Town.zone[Town.idx(floori(p.x), floori(p.y))] if Town.inb(floori(p.x), floori(p.y)) else 0

func in_boat() -> bool: return Game.S.get("boat", false)
func boat_kind() -> String: return Game.S.get("boat_kind", "kayak")

func walkable(x: int, y: int) -> bool:
	if not Town.inb(x, y): return false
	var t: int = Town.tile[Town.idx(x, y)]
	var h := Game.hour()
	match t:
		Town.T.GRATE: return Game.S.gear.has("flashlight") and Game.S.gear.has("waders")
		Town.T.PGATE: return (h >= 9 and h < 18) or zone_of(position) == 5
		Town.T.HGATE: return Game.hoa_open or zone_of(position) == 6
	return not (t in Town.BLOCK)

## Why you can't go through the storm drain grate right now, in plain words, or "" if you can.
static func drain_block() -> String:
	var miss := []
	if not Game.S.gear.has("flashlight"): miss.append("a flashlight")
	if not Game.S.gear.has("waders"): miss.append("waders")
	if miss.is_empty(): return ""
	return "The storm drain grate. You need %s to go down there. Lou sells %s." % [" and ".join(miss), "both" if miss.size() > 1 else "it"]

static func boatable(x: int, y: int, kind: String) -> bool:
	if not Town.inb(x, y): return false
	if Town.in_bridge(x, y): return true
	var t: int = Town.tile[Town.idx(x, y)]
	if not Town.is_water_t(t): return false
	if t == Town.T.DEEP and kind != "skiff": return false
	if t == Town.T.WARM and kind == "skiff": return false
	return true

func solid_at(p: Vector2) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	if in_boat(): return not boatable(x, y, boat_kind())
	return not walkable(x, y) or Town.is_water_t(Town.t_at(x, y))

func collides(p: Vector2) -> bool:
	var r := 0.3
	return solid_at(p + Vector2(-r, -r)) or solid_at(p + Vector2(r, -r)) or solid_at(p + Vector2(-r, r)) or solid_at(p + Vector2(r, r))

func _grid_now() -> AStarGrid2D:
	if not in_boat(): return walk_grid
	var k := boat_kind()
	if not boat_grids.has(k): boat_grids[k] = _grid(func(x, y): return not boatable(x, y, k))
	return boat_grids[k]

## Walking straight at a wall just beside a one-tile opening (the storm drain grate, a gate): slide sideways
## onto the opening's line so you go through it instead of snagging on its edge.
func _ease_into_gap(d: Vector2, amt: float) -> void:
	var side := Vector2(d.y, d.x).abs()
	var c := Vector2(floorf(position.x) + 0.5, floorf(position.y) + 0.5)
	for k in [0, 1, -1]:
		var o: Vector2 = c + side * k
		var off := (o - position).dot(side)
		if absf(off) > 0.75: continue
		var lined := position + side * off
		if collides(lined) or collides(lined + d * 0.2): continue
		var mv := clampf(off, -amt, amt)
		if not collides(position + side * mv): position += side * mv
		return

func walk_to(target: Vector2) -> void:
	var g := _grid_now()
	var tx := floori(target.x)
	var ty := floori(target.y)
	if not Town.inb(tx, ty) or g.is_point_solid(Vector2i(tx, ty)):
		# tapped somewhere you can't stand: go to the nearest open tile beside it
		var best := Vector2i(-1, -1)
		var bd := 99.0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := tx + dx
				var y := ty + dy
				if not Town.inb(x, y) or g.is_point_solid(Vector2i(x, y)): continue
				var d := Vector2(x + 0.5, y + 0.5).distance_to(target) + Vector2(x + 0.5, y + 0.5).distance_to(position) * 0.05
				if d < bd: bd = d; best = Vector2i(x, y)
		if best.x < 0: return
		tx = best.x; ty = best.y
	var from := Vector2i(floori(position.x), floori(position.y))
	if g.is_point_solid(from): return
	var pts := g.get_point_path(from, Vector2i(tx, ty))
	path = []
	for p in pts: path.append(p + Vector2(0.5, 0.5))
	if path.size(): path.remove_at(0)
	face = (target - position).angle()

func speed() -> float:
	if in_boat(): return 6.5 if boat_kind() == "skiff" else 3.4
	var fl := Town.floodable[Town.idx(floori(position.x), floori(position.y))] and Game.flooded()
	if fl or zone_of(position) == 4: return 2.6
	return 4.4

func step(dt: float, input_dir: Vector2) -> void:
	var dir := input_dir
	if dir != Vector2.ZERO: path.clear()
	elif path.size():
		var to: Vector2 = path[0] - position
		if to.length() < 0.15: path.remove_at(0)
		else: dir = to.normalized()
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		var before := position
		var sp := speed()
		var nx := position + Vector2(dir.x * sp * dt, 0)
		if not collides(nx): position = nx
		elif dir.y == 0.0: _ease_into_gap(Vector2(signf(dir.x), 0), sp * dt)
		var ny := position + Vector2(0, dir.y * sp * dt)
		if not collides(ny): position = ny
		elif dir.x == 0.0: _ease_into_gap(Vector2(0, signf(dir.y)), sp * dt)
		if before.distance_to(position) < 0.0005: path.clear()
		face = dir.angle(); moving = true; bob += dt * 10
	else: moving = false
	for w in wake: w.t += dt
	wake = wake.filter(func(w): return w.t < 1.6)
	if in_boat() and boat_kind() == "skiff" and moving and randf() < dt * 14:
		wake.append({ "p": position - Vector2.from_angle(face) * 1.3 + Vector2(0, 0.1), "a": face, "t": 0.0 })
	Game.S.x = position.x; Game.S.y = position.y; Game.S.face = face
	queue_redraw()

## Where each boat was left when you landed: kind -> [x, y, face, water x, water y].
## (x, y) is where it's drawn, pulled up on the bank for the kayak; the water spot is where you get back in.
## A boat you've landed stays put until you come back for it. One you've never landed goes wherever you do.
static func parked() -> Dictionary:
	if not (Game.S.get("parked") is Dictionary): Game.S.parked = {}
	return Game.S.parked

## The nearest water tile you could launch from, and which boat you'd take.
func launch_spot() -> Variant:
	if in_boat() or not (Game.S.gear.has("kayak") or Game.S.gear.has("skiff")): return null
	var pk := parked()
	# a boat you left here
	var best = null
	var bd := 2.4
	for kind in pk:
		if not Game.S.gear.has(kind): continue
		var v: Array = pk[kind]
		var d := Vector2(v[0], v[1]).distance_to(position)
		if d < bd: bd = d; best = [Vector2(v[3], v[4]), kind]
	if best != null: return best
	# or one you're carrying, at any edge
	var free_k: bool = Game.S.gear.has("kayak") and not pk.has("kayak")
	var free_s: bool = Game.S.gear.has("skiff") and not pk.has("skiff")
	if not (free_k or free_s): return null
	bd = 1.7
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := floori(position.x) + dx
			var y := floori(position.y) + dy
			if not Town.inb(x, y) or Town.tile[Town.idx(x, y)] != Town.T.WATER: continue
			var reg: int = Town.region[Town.idx(x, y)]
			if not (reg in [2, 9, 13, 14]): continue
			var kind := "skiff" if free_s and (reg == 13 or reg == 14) else "kayak" if free_k else ""
			if kind == "": continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(position)
			if d < bd: bd = d; best = [Vector2(x + 0.5, y + 0.5), kind]
	return best

func beach_spot() -> Variant:
	if not in_boat(): return null
	var best = null
	var bd := 1.7
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := floori(position.x) + dx
			var y := floori(position.y) + dy
			if not walkable(x, y) or Town.is_water_t(Town.t_at(x, y)) or Town.in_bridge(x, y): continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(position)
			if d < bd: bd = d; best = Vector2(x + 0.5, y + 0.5)
	return best

func toggle_boat() -> String:
	path.clear()
	if in_boat():
		var b = beach_spot()
		if b == null: return ""
		var w := position
		if boat_kind() == "skiff": parked()["skiff"] = [w.x, w.y, face, w.x, w.y]
		else:
			# drag the kayak half up the bank, nose first, and step off beside it
			var dir: Vector2 = (b - w).normalized()
			var k: Vector2 = b - dir * 0.5 + dir.orthogonal() * 0.8
			parked()["kayak"] = [k.x, k.y, dir.angle(), w.x, w.y]
		position = b; Game.S.boat = false
		return "You tie up the skiff and hop off." if boat_kind() == "skiff" else "You drag the kayak up the bank."
	var l = launch_spot()
	if l == null: return ""
	var pk := parked()
	if pk.has(l[1]):
		var v: Array = pk[l[1]]
		face = float(v[2]) + (PI if l[1] == "kayak" else 0.0)
		pk.erase(l[1])
	position = l[0]; Game.S.boat = true; Game.S.boat_kind = l[1]
	return "The outboard coughs twice and catches. Steer with the arrow keys or click the water." if l[1] == "skiff" else "You push off. Paddle with the arrow keys or click the water."

func _draw() -> void:
	if in_boat():
		var rot := face
		if boat_kind() == "skiff":
			draw_set_transform(Vector2(0, 0.1), rot, Vector2.ONE)
			draw_skiff(self)
		else:
			draw_set_transform(Vector2(0, 0.1), rot, Vector2.ONE)
			draw_kayak(self, sin(bob * 0.6) * 0.5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var z := zone_of(position)
	var look := { "shirt": Color("#13807b"), "pants": Color("#c9b48a"), "skin": Color("#e0b48c"), "hair": Color("#6b4a2a"),
		"hat": Color("#c9a574"), "hat_kind": "wide", "dots": true, "seated": in_boat() }
	if Game.S.gear.has("polo") and z == 1:
		look.shirt = Color.WHITE; look.dots = false; look.hat = Color("#f2f2f2"); look.hat_kind = "cap"
	elif Game.S.gear.has("suit") and z == 8:
		look.shirt = Color("#3d4a52"); look.dots = false; look.tie = true; look.pants = Color("#2c353b")
	if Game.S.gear.has("lanyard") and z == 2: look.lanyard = true
	var walking := moving and not in_boat()
	if fishing_pose:
		var tip := rod_tip() - position + (Vector2.from_angle(face + rod_pull * 0.5) - Vector2.from_angle(face)) * 0.95
		Art.character(self, Vector2.ZERO, face, look, bob, false, 2, tip, rod_bend)
	else:
		Art.character(self, Vector2.ZERO, face, look, bob, walking, 1)

## The boats, drawn around their own middle and pointing right (rotate with draw_set_transform first).
static func draw_skiff(ci: CanvasItem) -> void:
	Art.ellipse(ci, Vector2(0.1, 0.12), 1.5, 0.55, Color(0, 0, 0, 0.25))
	Art.poly(ci, [Vector2(1.55, 0), Vector2(0.9, -0.48), Vector2(-1.2, -0.52), Vector2(-1.25, 0.52), Vector2(0.9, 0.48)], Color("#f4f6f8"))
	Art.poly(ci, [Vector2(1.3, 0), Vector2(0.8, -0.38), Vector2(-1.05, -0.38), Vector2(-1.08, 0.38), Vector2(0.8, 0.38)], Color("#d8dde0"))
	ci.draw_rect(Rect2(-0.05, -0.22, 0.4, 0.44), Color("#3d4a52")); ci.draw_rect(Rect2(0.3, -0.2, 0.08, 0.4), Color("#9fd3f0"))
	ci.draw_rect(Rect2(-1.45, -0.16, 0.3, 0.32), Color("#22313a"))

## paddle: how far the paddle is swung, or null for one lying along the deck
static func draw_kayak(ci: CanvasItem, paddle: Variant) -> void:
	Art.ellipse(ci, Vector2(0.08, 0.1), 1.15, 0.3, Color(0, 0, 0, 0.25))
	Art.ellipse(ci, Vector2.ZERO, 1.15, 0.29, Color("#f2b134"))
	Art.ellipse(ci, Vector2.ZERO, 0.36, 0.17, Color("#22313a"))
	if paddle == null:
		ci.draw_line(Vector2(-0.95, 0.1), Vector2(0.9, -0.06), Color("#3d2b1a"), 0.06)
		for e in [Vector2(-0.95, 0.1), Vector2(0.9, -0.06)]: Art.ellipse(ci, e, 0.16, 0.07, Color("#2b7ea6"))
	else:
		var pa: float = paddle
		ci.draw_line(Vector2(-0.1 + pa * 0.3, -0.75), Vector2(0.1 - pa * 0.3, 0.75), Color("#3d2b1a"), 0.06)

func rod_tip() -> Vector2:
	return position + Vector2(cos(face) * 0.95, sin(face) * 0.95 - 0.4)
