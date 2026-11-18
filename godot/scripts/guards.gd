class_name Guards
extends Node2D
## Everyone who keeps you off private water: patrols, gate guards, cameras and floodlights.
## Also the things that open windows for sneaking: the HOA resident's car and the airport jets.
## This node draws the vision cones; each watcher's body is y-sorted with the other entities.

signal busted(w: Dictionary)

const PLANE_CYCLE := 55.0
const HOA_CYCLE := 26.0
const HOA_GATE := Vector2i(61, 86)    # the Heron Lakes gate, in its wall
const PARK_GATE := Vector2i(20, 86)   # the Sunsplash Jungle Park gate, in its fence

var player: Player
var fishing: Fishing
var watchers: Array = []
var exits := {}
var znames := {}
var detect := 0.0
const CATCH_SLOW := 2.0   # how much longer than the old pace a guard takes to bust you
var detect_by = null
var plane_t := 18.0
var hoa_t := 6.0
var hoa_swing := 0.0    # how far the Heron Lakes gate has swung open, 0 shut to 1 wide open
var park_swing := 0.0   # the same for the Sunsplash Jungle Park gate
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
	if Town.level == 0:
		ents.add_child(Drawer.make(_draw_hoa_gate, HOA_GATE.y + 0.95, true, Rect2(HOA_GATE.x - 4, HOA_GATE.y - 2, 8, 4)))
		ents.add_child(Drawer.make(_draw_park_gate, PARK_GATE.y + 0.95, true, Rect2(PARK_GATE.x - 3, PARK_GATE.y - 2, 6, 4)))

## Test hook (--guards=seconds): move everyone on a route along it, as if that much time had passed.
func walk_ahead(secs: float) -> void:
	for w in watchers:
		if not w.has("path") or w.kind == "cam": continue
		var left := secs * float(w.speed)
		while left > 0.0:
			var tp := Vector2(w.path[w.wp][0], w.path[w.wp][1])
			var to: Vector2 = tp - w.pos
			if to.length() <= left:
				left -= to.length(); w.pos = tp; w.wp = (w.wp + 1) % w.path.size()
			else:
				w.pos += to.normalized() * left; w.dir = to.angle(); left = 0.0
		w.node.position.y = w.pos.y
		w.node.get_child(0).position.y = -w.pos.y

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
## Sunsplash Jungle Park keeps its gate open 9 AM to 6 PM (you can always walk out).
static func park_open() -> bool:
	var h := Game.hour()
	return h >= 9 and h < 18

func update(dt: float) -> void:
	var was_plane := plane_t < 5
	plane_t = fmod(plane_t + dt, PLANE_CYCLE)
	if plane_t < 5 and not was_plane and Town.level == 0 and player.position.distance_to(Vector2(96, 99)) < 45:
		Sound.play("jet", -2.0 if zone_at(player.position) == 7 else -8.0)
		if zone_at(player.position) == 7: plane_hint = true
	hoa_t = fmod(hoa_t + dt, HOA_CYCLE)
	Game.hoa_open = hoa_gate_open() and Town.level == 0
	hoa_swing = move_toward(hoa_swing, 1.0 if Game.hoa_open else 0.0, dt * 1.8)
	park_swing = move_toward(park_swing, 1.0 if park_open() else 0.0, dt * 1.2)
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
				if w.has("home"): w.pos = Vector2(w.home[0], w.home[1]); w.dir = -PI / 2; w.off = true
			elif w.get("off", false):
				# back on duty: start the route again, rather than walk a straight line from home
				# (that line can cut across water or through buildings)
				w.off = false; w.pos = Vector2(w.path[0][0], w.path[0][1]); w.wp = 1 % w.path.size()
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
		# CATCH_SLOW halves the rate, so you get twice as long to break away once someone spots you
		detect += dt * (0.55 + 0.9 * (1 - d / radius(seen_by))) * (1.7 if fishing.state != "idle" else 1.0) / CATCH_SLOW
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

## One leaf of a swing gate seen from the front: hinged at `hinge` (its foot), `w` wide and `h` tall,
## pointing along `side` (1 right, -1 left) when shut and swinging in toward you as `open` goes to 1.
static func _gate_leaf(ci: CanvasItem, hinge: Vector2, w: float, h: float, side: float, open: float, iron: Color, bars: int, spears: bool) -> void:
	var a := open * PI / 2 * 0.92
	var run := Vector2(cos(a) * w * side, sin(a) * w)   # the foot of the leaf, from the hinge out to its free end
	var up := Vector2(0, -h)
	# its shadow on the ground
	Art.poly(ci, [hinge + Vector2(0.05, 0.04), hinge + run + Vector2(0.05, 0.04), hinge + run + Vector2(0.18, 0.1), hinge + Vector2(0.18, 0.1)], Color(0, 0, 0, 0.16))
	var lw := 0.035 + 0.02 * (1 - absf(cos(a)))
	for i in bars + 1:
		var k := float(i) / bars
		var f := hinge + run * k
		var top := f + up * (1.0 + (0.08 if spears and i % 2 == 1 else 0.0))
		ci.draw_line(f, top, iron, lw * (1.6 if i == 0 or i == bars else 1.0))
		if spears: ci.draw_circle(top, lw * 0.9, iron)
	for r in [0.12, 0.82]:
		ci.draw_line(hinge + up * r, hinge + run + up * r, iron, 0.05)
	# a curl of scrollwork near the top
	if spears and cos(a) > 0.25:
		var mid := hinge + run * 0.5 + up * 0.66
		ci.draw_arc(mid, 0.09, PI, TAU, 10, iron, 0.03)

## A square gatepost seen from the front: its face and a cap on top, with a lantern if `lamp`.
static func _gate_post(ci: CanvasItem, foot: Vector2, w: float, h: float, face: Color, cap: Color, lamp: bool) -> void:
	ci.draw_rect(Rect2(foot.x - w / 2 + 0.08, foot.y - 0.08, w, 0.18), Color(0, 0, 0, 0.18))
	ci.draw_rect(Rect2(foot.x - w / 2, foot.y - h, w, h), face)
	ci.draw_rect(Rect2(foot.x - w / 2, foot.y - h, w, 0.06), face.darkened(0.12))
	ci.draw_rect(Rect2(foot.x - w / 2 - 0.05, foot.y - h - 0.2, w + 0.1, 0.22), cap)
	ci.draw_rect(Rect2(foot.x - w / 2 - 0.05, foot.y - h + 0.0, w + 0.1, 0.04), cap.darkened(0.25))
	if lamp:
		var lp := foot + Vector2(0, -h - 0.34)
		ci.draw_rect(Rect2(lp.x - 0.08, lp.y - 0.06, 0.16, 0.2), Color("#2d3236"))
		var glow := Game.darkness()
		ci.draw_rect(Rect2(lp.x - 0.05, lp.y - 0.02, 0.1, 0.13), Color("#fff2c4").lerp(Color("#fbd56b"), glow))
		if glow > 0.05:
			for k in 3: ci.draw_circle(lp + Vector2(0, 0.05), 0.25 + k * 0.22, Color(1, 0.9, 0.6, 0.14 * glow / (k + 1)))

## The Heron Lakes gate: stucco posts with lanterns, a pair of black iron gates that swing in when a
## resident's car comes up, a call box out front with a red or green light, and a RESIDENTS ONLY plaque.
func _draw_hoa_gate(ci: CanvasItem) -> void:
	if Town.t_at(HOA_GATE.x, HOA_GATE.y) != Town.T.HGATE: return
	var x := float(HOA_GATE.x)
	var foot := float(HOA_GATE.y) + 0.78
	var iron := Color("#22282c")
	# the plaque on the wall to the left
	var pl := Rect2(x - 3.1, foot - 0.62, 2.2, 0.5)
	ci.draw_rect(Rect2(pl.position + Vector2(0.06, 0.06), pl.size), Color(0, 0, 0, 0.2))
	ci.draw_rect(pl, Color("#2f4a3c"))
	ci.draw_rect(pl.grow(-0.04), Color("#3c5d4b"))
	Art.text(ci, pl.get_center() + Vector2(0, -0.08), "HERON LAKES", 0.17, Color("#e9dfc4"))
	Art.text(ci, pl.get_center() + Vector2(0, 0.12), "RESIDENTS ONLY", 0.11, Color("#c7d3c0"))
	# the gates, behind the posts
	_gate_leaf(ci, Vector2(x + 0.02, foot), 0.48, 0.62, 1.0, hoa_swing, iron, 6, true)
	_gate_leaf(ci, Vector2(x + 0.98, foot), 0.48, 0.62, -1.0, hoa_swing, iron, 6, true)
	_gate_post(ci, Vector2(x - 0.2, foot), 0.38, 0.72, Color("#eadcc2"), Color("#c96f4a"), true)
	_gate_post(ci, Vector2(x + 1.2, foot), 0.38, 0.72, Color("#eadcc2"), Color("#c96f4a"), true)
	# the call box on its post, out on the sidewalk where the cars pull up
	var cb := Vector2(x - 0.55, float(HOA_GATE.y) - 0.35)
	ci.draw_rect(Rect2(cb.x - 0.03, cb.y - 0.2, 0.06, 0.4), Color("#5b6064"))
	ci.draw_rect(Rect2(cb.x - 0.13, cb.y - 0.42, 0.26, 0.26), Color("#33393d"))
	ci.draw_rect(Rect2(cb.x - 0.09, cb.y - 0.38, 0.18, 0.1), Color("#8fa3ad"))
	ci.draw_circle(cb + Vector2(0, -0.22), 0.04, Color("#5fd16b") if Game.hoa_open else Color("#e2583e"))

## The Sunsplash Jungle Park gate: two bamboo-yellow posts and green tube gates, with a CLOSED sign
## hung on them outside opening hours.
func _draw_park_gate(ci: CanvasItem) -> void:
	if Town.t_at(PARK_GATE.x, PARK_GATE.y) != Town.T.PGATE: return
	var x := float(PARK_GATE.x)
	var foot := float(PARK_GATE.y) + 0.62
	var green := Color("#2f8a5c")
	_gate_leaf(ci, Vector2(x + 0.04, foot), 0.46, 0.5, 1.0, park_swing, green, 4, false)
	_gate_leaf(ci, Vector2(x + 0.96, foot), 0.46, 0.5, -1.0, park_swing, green, 4, false)
	_gate_post(ci, Vector2(x - 0.06, foot), 0.16, 0.66, Color("#e2b04a"), Color("#e2583e"), false)
	_gate_post(ci, Vector2(x + 1.06, foot), 0.16, 0.66, Color("#e2b04a"), Color("#e2583e"), false)
	if park_swing < 0.15:
		var sg := Rect2(x + 0.14, foot - 0.48, 0.72, 0.28)
		ci.draw_line(Vector2(sg.position.x + 0.12, sg.position.y), Vector2(x + 0.5, foot - 0.58), Color("#5b4630"), 0.02)
		ci.draw_line(Vector2(sg.end.x - 0.12, sg.position.y), Vector2(x + 0.5, foot - 0.58), Color("#5b4630"), 0.02)
		ci.draw_rect(sg, Color("#fbf3e2"))
		Art.text(ci, sg.get_center() + Vector2(0, 0.01), "CLOSED", 0.14, Color("#c93b2a"))

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
