class_name WaterFx
extends Node2D
## Life on the water: the wake behind your kayak or skiff, rings where things touch the water,
## fish that jump now and then, and the reflections of towers, boats and lamps on the water.
## Two of these sit in the world: one under the fish shadows for reflections (mode "under"),
## one over them for wakes, rings and jumps (mode "over").

static var rings: Array = []      # { p, r (size), t (age), life }
static var jumps: Array = []      # { p, dir, t, len }
static var trail: Array = []      # { p, a (heading), t, kind }

var mode := "over"
var player: Player
var fishing: Fishing
var jump_t := 3.0

## A ring of ripples spreading out from p. size 1 is a lure landing.
static func ripple(p: Vector2, size := 1.0, life := 1.4) -> void:
	rings.append({ "p": p, "r": size, "t": 0.0, "life": life })

var fx_test := "--fxtest" in OS.get_cmdline_user_args()   # test hook: freeze a wake, a jump and rings in view

func _process(dt: float) -> void:
	if mode == "under":
		# reflections are off on low graphics
		visible = Game.quality > 0
		if visible: queue_redraw()
		return
	queue_redraw()
	if fx_test:
		if trail.is_empty():
			for i in 12: trail.append({ "p": player.position - Vector2.from_angle(player.face) * (1.1 + i * 0.3) + Vector2(0, 0.1), "a": player.face, "t": i * 0.15, "kind": player.boat_kind() })
			jumps.append({ "p": player.position + Vector2(3.0, 1.5), "dir": 0.3, "t": 0.45, "len": 0.7, "hold": true })
			ripple(player.position + Vector2(-3.0, 2.0), 1.1, 99.0)
			rings[-1].t = 0.6
		return
	for r in rings: r.t += dt
	rings = rings.filter(func(r): return r.t < r.life)
	for w in trail: w.t += dt
	trail = trail.filter(func(w): return w.t < 2.2)
	# lay down wake as the boat moves
	if player.in_boat() and player.moving:
		var kind := player.boat_kind()
		var stern := player.position - Vector2.from_angle(player.face) * (1.1 if kind == "skiff" else 0.9) + Vector2(0, 0.1)
		if trail.is_empty() or trail[-1].p.distance_to(stern) > 0.18:
			trail.append({ "p": stern, "a": player.face, "t": 0.0, "kind": kind })
	# fish jumping
	for j in jumps: j.t += dt / 0.85
	for j in jumps:
		if j.t >= 1.0 and not j.get("in", false):
			j.in = true
			ripple(j.p + Vector2.from_angle(j.dir) * j.len * 1.4, 0.8 * j.len / 0.6)
			if j.p.distance_to(player.position) < 14: Sound.play("plop", -10.0)
	jumps = jumps.filter(func(j): return j.t < 1.0)
	jump_t -= dt
	if jump_t <= 0:
		jump_t = randf_range(3.5, 8.0)
		_try_jump()

func _view() -> Rect2:
	var cam_rect := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return Rect2(cam_rect.position / Game.TS, cam_rect.size / Game.TS)

## Pick a fish shadow on screen (or open water if there isn't one) and have it leap.
func _try_jump() -> void:
	var view := _view().grow(-1)
	var cands := []
	for s in fishing.shadows:
		if view.has_point(s.pos) and not s.hooked and not s.leaving and s.fade > 0.5 and s.reg != 5: cands.append(s)
	var p := Vector2.ZERO
	var len := 0.5
	if not cands.is_empty():
		var s: Dictionary = cands.pick_random()
		p = s.pos; len = clampf(s.len * 0.7, 0.35, 1.1)
	else:
		var ok := false
		for i in 20:
			p = view.position + Vector2(randf() * view.size.x, randf() * view.size.y)
			var t := Town.t_at(floori(p.x), floori(p.y))
			if Town.is_water_t(t) and t != Town.T.SWATER and Town.depth[Town.idx(floori(p.x), floori(p.y))] >= 2: ok = true; break
		if not ok: return
	if fishing.bob != null and p.distance_to(fishing.bob) < 2.0: return
	var dir := randf() * TAU
	if not Town.is_water_t(Town.t_at(floori(p.x + cos(dir) * len * 1.4), floori(p.y + sin(dir) * len * 1.4))): dir += PI
	jumps.append({ "p": p, "dir": dir, "t": 0.0, "len": len })
	ripple(p, 0.7 * len / 0.6)

func _draw() -> void:
	var view := _view().grow(3)
	if mode == "under": _draw_reflections(view); return
	var now := Time.get_ticks_msec() / 1000.0
	# wake: a widening V of foam behind the boat, and churned water right behind the motor
	for w in trail:
		if not view.has_point(w.p): continue
		var k: float = w.t / 2.2
		var fw := Vector2.from_angle(w.a)
		var side := Vector2(-fw.y, fw.x)
		var skiff: bool = w.kind == "skiff"
		var spread := (0.35 + k * (2.2 if skiff else 1.2))
		var a := (1.0 - k) * (0.6 if skiff else 0.42)
		for sd in [-1.0, 1.0]:
			var c: Vector2 = w.p + side * spread * sd * 0.5 - fw * k * 0.4
			draw_line(c - fw * 0.12, c + fw * 0.12 + side * sd * 0.06, Color(1, 1, 1, a), 0.07 * (1.0 - k * 0.5))
		if skiff and k < 0.35:
			draw_circle(w.p + side * sin(w.t * 20.0 + w.p.x) * 0.12, 0.2 * (1.0 - k * 2.0), Color(1, 1, 1, 0.4 * (1.0 - k / 0.35)))
	if player.in_boat() and player.moving:
		# a bow wave curling off the front
		var fw := Vector2.from_angle(player.face)
		var bow := player.position + fw * (1.5 if player.boat_kind() == "skiff" else 1.1) + Vector2(0, 0.1)
		for sd in [-1.0, 1.0]:
			var sdv: Vector2 = Vector2(-fw.y, fw.x) * sd
			draw_polyline(PackedVector2Array([bow, bow + sdv * 0.25 - fw * 0.3, bow + sdv * 0.45 - fw * 0.8]), Color(1, 1, 1, 0.5), 0.06)
	# rings
	for r in rings:
		if not view.has_point(r.p): continue
		var k: float = r.t / r.life
		for i in 2:
			var kk := k - i * 0.18
			if kk <= 0: continue
			draw_set_transform(r.p, 0, Vector2(1, 0.5))
			draw_arc(Vector2.ZERO, (0.15 + kk * 0.9) * r.r, 0, TAU, 28, Color(1, 1, 1, 0.55 * (1.0 - kk)), 0.05)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# jumping fish: an arc out of the water and back in, with drips falling off
	for j in jumps:
		if not view.has_point(j.p): continue
		var t: float = j.t
		var fw := Vector2.from_angle(j.dir)
		var L: float = j.len
		var ground: Vector2 = j.p + fw * L * 1.4 * t
		var hgt := sin(t * PI) * (0.5 + L * 0.6)
		var body := ground + Vector2(0, -hgt)
		Art.ellipse(self, ground + Vector2(0, 0.05), L * 0.4 * (1.0 - hgt * 0.4), L * 0.12, Color(0.02, 0.1, 0.14, 0.25))
		var vel: Vector2 = fw * L * 1.4 + Vector2(0, -cos(t * PI) * PI * (0.5 + L * 0.6))
		var ang := vel.angle()
		draw_set_transform(body, ang, Vector2.ONE)
		var silver := Color("#c9d6dc")
		Art.ellipse(self, Vector2.ZERO, L * 0.5, L * 0.16, silver)
		Art.ellipse(self, Vector2(0.02, -L * 0.04), L * 0.4, L * 0.07, Color("#eef4f6"))
		Art.ellipse(self, Vector2(0, L * 0.08), L * 0.4, L * 0.05, Color("#7e9aa6"))
		draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.42, 0), Vector2(-L * 0.72, -L * 0.2), Vector2(-L * 0.64, 0), Vector2(-L * 0.72, L * 0.2)]), Color("#9fb3bc"))
		draw_circle(Vector2(L * 0.36, -L * 0.03), L * 0.035, Color("#1e2428"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		for i in 4:
			var dk := fmod(now * 3.0 + i * 0.25, 1.0)
			draw_circle(body + Vector2((i - 1.5) * 0.08, dk * hgt), 0.03, Color(1, 1, 1, 0.7 * (1.0 - dk) * hgt))

## Reflections on the water: towers mirrored into the water in front of them, moored boats and the
## pier, each broken up by the ripples. Drawn under the fish shadows.
func _draw_reflections(view: Rect2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dk := Game.darkness() / 0.62
	for b in Town.buildings:
		if b.kind != "sky" and b.kind != "flat" and b.kind != "marina" and b.kind != "mega": continue
		var H: float = Art.sky_geom(b).x if b.kind == "sky" else 0.9
		var y0: float = b.y + b.h
		var reach := H * 0.75 + 0.5
		if not view.intersects(Rect2(b.x - 1, y0, b.w + 2, reach)): continue
		var c := Color(b.color)
		var col := Art.shade(c, -0.25)
		for ty in range(int(y0), int(y0 + reach) + 1):
			for tx in range(int(b.x), int(ceil(b.x + b.w))):
				if not Town.is_water_t(Town.t_at(tx, ty)) or Town.t_at(tx, ty) == Town.T.SWATER: continue
				var dd := (ty + 0.5 - y0) / reach
				var wob := sin(now * 1.6 + ty * 1.3 + tx * 0.4) * 0.06
				var a := 0.22 * (1.0 - dd)
				draw_rect(Rect2(tx + wob, ty, 1, 1), Color(col.r, col.g, col.b, a))
				# lit windows shimmer in the reflection at night
				if b.kind == "sky" and dk > 0.3 and Town.hash2(tx * 3, ty * 5 + int(now * 2.0)) > 0.55:
					draw_rect(Rect2(tx + 0.2 + wob * 2.0, ty + 0.3, 0.3, 0.08), Color(1, 0.84, 0.5, 0.35 * dk * (1.0 - dd)))
				elif b.kind == "sky" and dk <= 0.3:
					draw_rect(Rect2(tx + 0.15 + wob * 2.0, ty + 0.4, 0.7, 0.05), Color(1, 1, 1, 0.08 * (1.0 - dd)))
	# moored boats: a soft, wobbling white blur just below each hull
	for mb in [93.5, 103.5, 108.5]:
		var mp := Vector2(mb, 160.4)
		if not view.has_point(mp): continue
		for k in 5:
			var wob := sin(now * 2.0 + k * 1.7 + mb) * 0.08
			draw_rect(Rect2(mp.x - 0.45 + wob, mp.y + 1.6 + k * 0.22, 0.9, 0.12), Color(1, 1, 1, 0.1 * (1.0 - k / 5.0)))
