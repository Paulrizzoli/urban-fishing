class_name Player
extends Node2D
## The angler: keyboard walking, click-to-walk on a grid path, and tile collision.
## Lives inside the y-sorted entities node; position is in tiles.

var face := PI / 2
var moving := false
var bob := 0.0
var path: Array = []
var astar := AStarGrid2D.new()
var fishing_pose := false

func _ready() -> void:
	position = Vector2(Game.S.x, Game.S.y)
	face = Game.S.face
	astar.region = Rect2i(0, 0, Town.MW, Town.MH)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in Town.MH:
		for x in Town.MW:
			if not passable(x, y): astar.set_point_solid(Vector2i(x, y))

static func walkable(x: int, y: int) -> bool:
	if not Town.inb(x, y): return false
	var t: int = Town.tile[Town.idx(x, y)]
	if t == Town.T.GRATE: return Game.S.gear.has("flashlight") and Game.S.gear.has("waders")
	return not (t in Town.BLOCK)

static func passable(x: int, y: int) -> bool: return walkable(x, y)

func solid_at(p: Vector2) -> bool: return not walkable(floori(p.x), floori(p.y))

func collides(p: Vector2) -> bool:
	var r := 0.3
	return solid_at(p + Vector2(-r, -r)) or solid_at(p + Vector2(r, -r)) or solid_at(p + Vector2(-r, r)) or solid_at(p + Vector2(r, r))

func walk_to(target: Vector2) -> void:
	var tx := floori(target.x)
	var ty := floori(target.y)
	if not passable(tx, ty):
		# tapped water or a wall: walk to the nearest open tile beside it
		var best := Vector2i(-1, -1)
		var bd := 99.0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var x := tx + dx
				var y := ty + dy
				if not passable(x, y): continue
				var d := Vector2(x + 0.5, y + 0.5).distance_to(target) + Vector2(x + 0.5, y + 0.5).distance_to(position) * 0.05
				if d < bd: bd = d; best = Vector2i(x, y)
		if best.x < 0: return
		tx = best.x; ty = best.y
	var from := Vector2i(floori(position.x), floori(position.y))
	if astar.is_point_solid(from): return
	var pts := astar.get_point_path(from, Vector2i(tx, ty))
	path = []
	for p in pts: path.append(p + Vector2(0.5, 0.5))
	if path.size(): path.remove_at(0)
	face = (target - position).angle()

func step(dt: float, input_dir: Vector2) -> void:
	var dir := input_dir
	if dir != Vector2.ZERO: path.clear()
	elif path.size():
		var to: Vector2 = path[0] - position
		if to.length() < 0.15:
			path.remove_at(0)
		else: dir = to.normalized()
	var speed := 4.4
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		var before := position
		var nx := position + Vector2(dir.x * speed * dt, 0)
		if not collides(nx): position = nx
		var ny := position + Vector2(0, dir.y * speed * dt)
		if not collides(ny): position = ny
		if before.distance_to(position) < 0.0005: path.clear()
		face = dir.angle(); moving = true; bob += dt * 10
	else: moving = false
	Game.S.x = position.x; Game.S.y = position.y; Game.S.face = face
	queue_redraw()

func _draw() -> void:
	var p := Vector2(0, -absf(sin(bob)) * 0.06 if moving else 0.0)
	Art.ellipse(self, Vector2(0, 0.3), 0.38, 0.16, Color(0, 0, 0, 0.28))
	Art.ellipse(self, p, 0.34, 0.28, Color("#13807b"))
	for d in [Vector2(-0.15, -0.05), Vector2(0.12, 0.08), Vector2(0.05, -0.12)]: draw_circle(p + d, 0.05, Color("#f2b134"))
	draw_circle(p + Vector2(0, -0.24), 0.18, Color("#e0b48c"))
	Art.ellipse(self, p + Vector2(0, -0.3), 0.3, 0.17, Color("#c9a574"))
	draw_circle(p + Vector2(0, -0.32), 0.14, Color(0, 0, 0, 0.12))
	var rl := 1.1 if fishing_pose else 0.7
	var a := face if fishing_pose else face + 0.6
	draw_line(p + Vector2(cos(a), sin(a)) * 0.2 + Vector2(0, -0.05), p + Vector2(cos(a) * rl, sin(a) * rl - (0.4 if fishing_pose else 0.15)), Color("#3d2b1a"), 0.06)

func rod_tip() -> Vector2:
	return position + Vector2(cos(face) * 0.95, sin(face) * 0.95 - 0.4)
