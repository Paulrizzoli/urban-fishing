class_name Guards
extends Node2D
## Everyone who keeps you off private water: patrols, gate guards, cameras and floodlights.
## Also the things that open windows for sneaking: the HOA resident's car and the airport jets.
## This node draws the vision cones; each watcher's body is y-sorted with the other entities.

signal busted(w: Dictionary)

const PLANE_CYCLE := 55.0
const HOA_CYCLE := 26.0

var player: Player
var fishing: Fishing
var watchers: Array = []
var exits := {}
var znames := {}
var detect := 0.0
var detect_by = null
var plane_t := 18.0
var hoa_t := 6.0
var plane_hint := false

func setup(ents: Node2D) -> void:
	var f := FileAccess.open("res://data/watch.json" if Town.level == 0 else "res://data/watch2.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k in d.exit: exits[int(k)] = Vector2(d.exit[k][0], d.exit[k][1])
	for k in d.zname: znames[int(k)] = d.zname[k]
	for src in d.watchers:
		var w: Dictionary = src.duplicate(true)
		var start: Array = w.fixed if w.has("fixed") else w.path[0]
		w.pos = Vector2(start[0], start[1])
		w.dir = float(w.get("dir", 0.0))
		w.wp = 1; w.alert = 0.0; w.seen = false
		var ww := w
		w.node = Drawer.make(func(ci): _draw_watcher(ci, ww), w.pos.y, true)
		ents.add_child(w.node)
		watchers.append(w)
	ents.add_child(Drawer.make(_draw_hoa_car, 84.0, true))

func zone_at(p: Vector2) -> int:
	var x := floori(p.x)
	var y := floori(p.y)
	return Town.zone[Town.idx(x, y)] if Town.inb(x, y) else 0

func active(w: Dictionary) -> bool:
	if not w.has("hours"): return true
	var h := Game.hour()
	var a: float = w.hours[0]
	var b: float = w.hours[1]
	return (h >= a and h < b) if a < b else (h >= a or h < b)

func is_night() -> bool: return Game.darkness() > 0.3

func radius(w: Dictionary) -> float:
	return (float(w.rNight) if is_night() and w.has("rNight") else float(w.r)) * (1.0 - 0.3 * Game.wx.rain)

func in_hiding() -> bool:
	var t := Town.t_at(floori(player.position.x), floori(player.position.y))
	return t == Town.T.BUSH or t == Town.T.HIDE

func los_clear(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) * 2)
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var t := Town.t_at(floori(p.x), floori(p.y))
		if t == Town.T.BLD or t == Town.T.WALL or t == Town.T.TREE: return false
	return true

func can_see(w: Dictionary) -> bool:
	if not active(w): return false
	if zone_at(player.position) != int(w.zone): return false
	var fishing_now := fishing.state != "idle"
	if in_hiding() and not fishing_now: return false
	if w.has("disguise") and Game.S.gear.has(w.disguise) and not fishing_now:
		var h := Game.hour()
		if not w.has("dHours") or (h >= w.dHours[0] and h < w.dHours[1]): return false
	var d := player.position.distance_to(w.pos)
	if d > radius(w): return false
	var a := wrapf((player.position - w.pos).angle() - w.dir, -PI, PI)
	if absf(a) > deg_to_rad(w.fov) / 2 and d > 0.9: return false
	return los_clear(w.pos, player.position)

# ---------- the windows ----------
func plane_x() -> Variant: return 130.0 - plane_t * 13.5 if plane_t < 5 and Town.level == 0 else null
func plane_loud() -> bool:
	var x = plane_x()
	return x != null and x > 74 and x < 118
func hoa_car_pos() -> Variant:
	var k := hoa_t
	if k > 5 or Town.level != 0: return null
	if k < 2.5: return [Vector2(44 + k / 2.5 * 17.5, 83.5), 0.0]
	return [Vector2(61.5, 83.5 + (k - 2.5) / 2.5 * 9.5), PI / 2]
func hoa_gate_open() -> bool: return hoa_t > 1.8 and hoa_t < 4.7

func update(dt: float) -> void:
	var was_plane := plane_t < 5
	plane_t = fmod(plane_t + dt, PLANE_CYCLE)
	if plane_t < 5 and not was_plane and Town.level == 0 and player.position.distance_to(Vector2(96, 99)) < 45:
		Sound.play("jet", -2.0 if zone_at(player.position) == 7 else -8.0)
		if zone_at(player.position) == 7: plane_hint = true
	hoa_t = fmod(hoa_t + dt, HOA_CYCLE)
	Game.hoa_open = hoa_gate_open() and Town.level == 0
	var t := Time.get_ticks_msec() / 1000.0
	var seen_by = null
	var pz := zone_at(player.position)
	for w in watchers:
		var on := active(w)
		var was: Vector2 = w.pos
		if w.kind == "cam":
			var k := (sin(t * TAU / w.period) + 1) / 2
			w.dir = lerpf(w.sweep[0], w.sweep[1], k)
		elif w.has("path"):
			if not on:
				if w.has("home"): w.pos = Vector2(w.home[0], w.home[1]); w.dir = -PI / 2
			elif w.alert < 0.25:
				var tp := Vector2(w.path[w.wp][0], w.path[w.wp][1])
				var to: Vector2 = tp - w.pos
				var s: float = w.speed * (0.8 if is_night() else 1.0) * dt
				if to.length() <= s:
					w.pos = tp; w.wp = (w.wp + 1) % w.path.size()
				else:
					w.pos += to.normalized() * s
					w.dir += wrapf(to.angle() - w.dir, -PI, PI) * minf(1.0, dt * 6)
		w.moving = w.pos.distance_squared_to(was) > 0.000001
		if w.moving: w.phase = w.get("phase", 0.0) + dt * 9.0
		w.seen = not (plane_loud() and pz == 7) and can_see(w)
		if w.seen:
			if w.kind != "cam": w.dir += wrapf((player.position - w.pos).angle() - w.dir, -PI, PI) * minf(1.0, dt * 3)
			if seen_by == null or player.position.distance_to(w.pos) < player.position.distance_to(seen_by.pos): seen_by = w
		w.alert = minf(1.0, w.alert + dt) if w.seen else maxf(0.0, w.alert - dt * 0.5)
		w.node.position.y = w.pos.y
		w.node.get_child(0).position.y = -w.pos.y
	if seen_by != null:
		var d := player.position.distance_to(seen_by.pos)
		detect += dt * (0.55 + 0.9 * (1 - d / radius(seen_by))) * (1.7 if fishing.state != "idle" else 1.0)
		detect_by = seen_by
		if detect >= 1:
			detect = 0
			for w in watchers: w.alert = 0.0
			busted.emit(seen_by)
	else:
		detect = maxf(0.0, detect - dt * 0.4)
	queue_redraw()

# ---------- drawing ----------
func _draw() -> void:
	var cam_rect := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var view := Rect2(cam_rect.position / Game.TS, cam_rect.size / Game.TS).grow(14)
	for w in watchers:
		if not active(w) or not view.has_point(w.pos): continue
		var r := radius(w)
		var fov := deg_to_rad(w.fov)
		var hot: float = w.alert
		var pts := PackedVector2Array([w.pos])
		for i in 19:
			var a: float = w.dir - fov / 2 + fov * i / 18.0
			var rr := r
			var k := 0.5
			while k <= r:
				var p: Vector2 = w.pos + Vector2.from_angle(a) * k
				var tt := Town.t_at(floori(p.x), floori(p.y))
				if tt == Town.T.BLD or tt == Town.T.WALL or tt == Town.T.TREE: rr = k; break
				k += 0.5
			pts.append(w.pos + Vector2.from_angle(a) * rr)
		var fill := Color(0.89, 0.35, 0.24, 0.2 + hot * 0.25) if hot > 0.05 else Color(1, 0.89, 0.47, 0.22)
		draw_colored_polygon(pts, fill)
		pts.append(w.pos)
		draw_polyline(pts, Color(0.89, 0.35, 0.24, 0.7) if hot > 0.05 else Color(1, 0.89, 0.47, 0.55), 0.05)

func _draw_watcher(ci: CanvasItem, w: Dictionary) -> void:
	var on := active(w)
	var p: Vector2 = w.pos
	var navy := Color("#24365a")
	match w.kind:
		"desk", "dog":
			if not on: return
			if w.kind == "desk":
				ci.draw_rect(Rect2(p.x - 0.62, p.y + 0.12, 1.3, 0.4), Color(0, 0, 0, 0.22))
				Art.person(ci, p + Vector2(0, -0.05), w.dir, navy)
				ci.draw_rect(Rect2(p.x - 0.65, p.y + 0.05, 1.3, 0.38), Color("#3d4a52"))
				ci.draw_rect(Rect2(p.x - 0.65, p.y + 0.05, 1.3, 0.08), Color("#8b9196"))
			else:
				Art.person(ci, p, w.dir, Color("#3d4a52"), navy, false, w.get("phase", 0.0), w.get("moving", false))
				var dp: Vector2 = p - Vector2.from_angle(w.dir) * 0.7 + Vector2(0, 0.2)
				Art.ellipse(ci, dp, 0.18, 0.1, Color("#c98a5a"), w.dir)
				ci.draw_circle(dp + Vector2.from_angle(w.dir) * 0.18 + Vector2(0, -0.03), 0.08, Color("#c98a5a"))
				ci.draw_line(p, dp, Color(0.24, 0.16, 0.08, 0.6), 0.015)
		"cart":
			ci.draw_set_transform(p, w.dir, Vector2.ONE)
			ci.draw_rect(Rect2(-0.55, -0.32, 1.2, 0.72), Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(-0.6, -0.36, 1.2, 0.72), Color("#f4f4f0"))
			ci.draw_rect(Rect2(-0.6, -0.36, 0.5, 0.72), Color("#2f8a3e"))
			for o in [Vector2(-0.45, -0.42), Vector2(0.35, -0.42), Vector2(-0.45, 0.32), Vector2(0.35, 0.32)]: ci.draw_rect(Rect2(o, Vector2(0.22, 0.1)), Color("#333333"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			if on:
				ci.draw_circle(p + Vector2(0, -0.1), 0.16, Color("#e0b48c"))
				Art.ellipse(ci, p + Vector2(0, -0.15), 0.22, 0.12, Color("#2f8a3e"))
		"cam":
			ci.draw_rect(Rect2(p.x - 0.06, p.y - 0.06, 0.12, 0.5), Color("#555555"))
			ci.draw_set_transform(p, w.dir, Vector2.ONE)
			ci.draw_rect(Rect2(-0.15, -0.14, 0.5, 0.28), Color("#dfe3e6"))
			ci.draw_circle(Vector2(0.36, 0), 0.08, Color("#e2583e") if w.seen else Color("#333333"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"booth":
			ci.draw_rect(Rect2(p.x - 0.4, p.y - 0.5, 1.2, 1.2), Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(p.x - 0.55, p.y - 0.65, 1.1, 1.1), Color("#e9e4d8"))
			ci.draw_rect(Rect2(p.x - 0.55, p.y - 0.4, 0.15, 0.6), Color("#9fc4d6"))
			Art.person(ci, p, w.dir, navy, navy)
		"staff": Art.person(ci, p, w.dir, Color("#2f8a3e"), Color("#d9c28a"), false, w.get("phase", 0.0), w.get("moving", false))
		"hoa":
			var dp: Vector2 = p - Vector2.from_angle(w.dir) * 0.75 + Vector2(0, 0.15)
			ci.draw_line(p, dp, Color("#8a5a35"), 0.03)
			Art.ellipse(ci, dp, 0.2, 0.13, Color("#f4efe4"), w.dir)
			Art.person(ci, p, w.dir, Color("#f3a6a0"), Color("#f4efe4"), false, w.get("phase", 0.0), w.get("moving", false))
			ci.draw_rect(Rect2(p.x + 0.15, p.y - 0.05, 0.18, 0.22), Color("#fbf3e2"))
		"truck":
			Art.car(ci, p, w.dir, Color("#f1f1ee"), 2.0, 0.95)
			ci.draw_set_transform(p, w.dir, Vector2.ONE)
			ci.draw_rect(Rect2(0.05, -0.32, 0.14, 0.64), Color("#f2b134") if int(Time.get_ticks_msec() / 300) % 2 else Color("#e2583e"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_: Art.person(ci, p, w.dir, navy, navy, false, w.get("phase", 0.0), w.get("moving", false))
	if w.alert > 0.05 and w.kind != "cam":
		Art.text(ci, p + Vector2(0, -0.65), "!" if w.alert > 0.6 else "?", 0.6, Color("#e2583e"), Color.WHITE)

func _draw_hoa_car(ci: CanvasItem) -> void:
	var c = hoa_car_pos()
	if c != null: Art.car(ci, c[0], c[1], Color("#f1f1ee"), 1.9, 0.9)

## The jet overhead, and the detection meter over the player. Drawn above everything.
func draw_overlay(ci: CanvasItem) -> void:
	var x = plane_x()
	if x != null:
		var y := 99.5
		Art.ellipse(ci, Vector2(x + 1.4, y + 2.2), 3.6, 0.6, Color(0, 0, 0, 0.22))
		Art.ellipse(ci, Vector2(x, y), 3.6, 0.5, Color("#f4f6f8"))
		Art.poly(ci, [Vector2(x - 0.4, y), Vector2(x + 0.6, y - 3.8), Vector2(x + 1.2, y - 3.8), Vector2(x + 1, y), Vector2(x + 1.2, y + 3.8), Vector2(x + 0.6, y + 3.8)], Color("#f4f6f8"))
		Art.poly(ci, [Vector2(x + 2.6, y), Vector2(x + 3.2, y - 1.4), Vector2(x + 3.6, y - 1.4), Vector2(x + 3.5, y + 1.4), Vector2(x + 3.2, y + 1.4)], Color("#f4f6f8"))
		ci.draw_rect(Rect2(x + 2.9, y - 0.12, 0.7, 0.24), Color("#e2583e"))
		for i in 8: ci.draw_rect(Rect2(x - 2.6 + i * 0.6, y - 0.12, 0.2, 0.08), Color("#2b7ea6"))
	if detect > 0.02:
		var c := player.position + Vector2(0, -1.25)
		ci.draw_circle(c, 0.42, Color("#fbf3e2"))
		ci.draw_arc(c, 0.42, 0, TAU, 32, Color("#22313a"), 0.07)
		var pts := PackedVector2Array([c])
		for i in 25: pts.append(c + Vector2.from_angle(-PI / 2 + TAU * detect * i / 24.0) * 0.34)
		ci.draw_colored_polygon(pts, Color("#e2583e") if detect > 0.6 else Color("#f2b134"))
		Art.text(ci, c + Vector2(0, 0.2), "!" if detect > 0.6 else "?", 0.45, Color("#22313a"))
