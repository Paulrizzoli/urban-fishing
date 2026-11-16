class_name Fishing
extends Node2D
## Fish shadows swimming in every body of water, plus the whole fishing minigame:
## aim and cast, wait and twitch, nibble, bite, and the reel fight.

signal landed(c: Dictionary)
signal message(text: String)

const SHCOUNT := { 1: 5, 2: 16, 3: 6, 4: 4, 5: 5, 6: 6, 9: 12, 10: 6, 11: 6, 12: 7, 13: 10, 14: 24, 15: 18, 16: 6, 17: 5 }
const BAND := [0.22, 0.82]
const MINR := 1.2
const MAXR := 5.6
const SWEET := 0.075

var player: Player
var shadows: Array = []
var regtiles := {}

# minigame state
var state := "idle"
var t := 0.0
var power := 0.0
var aim := 0.0
var green := 0.55
var tgt = null          # a shadow dictionary or a {x,y,point} target
var bob = null          # Vector2
var bob0 := Vector2.ZERO
var shore := Vector2.ZERO
var perp := Vector2.ZERO
var fish = null
var fw := 0.0
var spot := 0
var tension := 0.3
var progress := 0.3
var ang := 0.0
var run := 0.0
var run_t := 0.0
var thrash_t := 0.0
var splash := 0.0
var splash_big := false
var twitch := 0.0
var target = null
var nib := 0.0
var wait_t := 0.0
var quiet := true
var blind := false
var holding := false
var pull := 0              # -1 / 0 / 1 from the arrow keys
var turn := 0

func _ready() -> void:
	for y in Town.MH:
		for x in Town.MW:
			var i := Town.idx(x, y)
			if Town.region[i] and Town.is_water_t(Town.tile[i]):
				var r: int = Town.region[i]
				if not regtiles.has(r): regtiles[r] = []
				regtiles[r].append(Vector2i(x, y))

func is_water(p: Vector2) -> bool: return Town.is_water_t(Town.t_at(floori(p.x), floori(p.y)))
func region_at(p: Vector2) -> int: return Town.region[Town.idx(floori(p.x), floori(p.y))] if Town.inb(floori(p.x), floori(p.y)) else 0

func near_water() -> bool:
	var px := floori(player.position.x)
	var py := floori(player.position.y)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if Town.is_water_t(Town.t_at(px + dx, py + dy)) and Vector2(px + dx + 0.5, py + dy + 0.5).distance_to(player.position) < 1.75: return true
	return false

# ---------- which fish ----------
func near_ok(f: Dictionary, x: int, y: int) -> bool:
	match f.get("near", ""):
		"runway": return x >= 93 and x <= 100
		"island": return Vector2(x - 62, (y - 165) * 1.8).length() < 10
		"marina": return x >= 83 and y <= 165
		"far": return y >= 177
	if f.get("bridge", false): return (x >= 36 and x <= 46) or (x >= 54 and x <= 64)
	return true

func fish_weight(f: Dictionary) -> float:
	var w0: float = f.w[0]
	var w1: float = f.w[1]
	var v := w0 + (w1 - w0) * pow(randf(), 0.8 if f.get("legend", false) else 1.7)
	return snappedf(v, 0.01 if w1 < 3 else 0.1)

func pick_fish(reg: int, ok: Callable) -> Variant:
	if not Game.spots.has(reg): return null
	var band := Game.time_band()
	var lst := []
	for f in Game.spots[reg].fish:
		if f.has("t") and not (band in f.t): continue
		if f.get("alien", false): continue
		if ok.call(f): lst.append(f)
	if lst.is_empty(): return null
	var ws := []
	var total := 0.0
	for f in lst:
		var w: float = f.r * Game.bait_mul(f) * (0.5 if f.get("legend", false) and Game.rod_level() == 0 else 1.0)
		ws.append(w); total += w
	var s := randf() * total
	for i in lst.size():
		s -= ws[i]
		if s <= 0: return lst[i]
	return lst[-1]

# ---------- shadows ----------
func spawn_shadow(reg: int) -> void:
	var tiles: Array = regtiles.get(reg, [])
	if tiles.is_empty(): return
	var has_legend := false
	for s in shadows:
		if s.reg == reg and s.fish.get("legend", false) and not s.leaving: has_legend = true
	var f = pick_fish(reg, func(x): return not x.get("junk", false) and not (has_legend and x.get("legend", false)))
	if f == null: return
	var cand := tiles
	if f.has("near") or f.get("bridge", false): cand = tiles.filter(func(v): return near_ok(f, v.x, v.y))
	if cand.is_empty(): return
	var tp: Vector2i = cand.pick_random()
	var w := fish_weight(f)
	shadows.append({ "reg": reg, "pos": Vector2(tp) + Vector2(0.5, 0.5), "goal": Vector2(tp) + Vector2(0.5, 0.5), "fish": f, "w": w, "dir": randf() * TAU,
		"speed": randf_range(0.35, 0.7) * (0.55 if f.get("legend", false) else 1.0), "spook": 0.0, "wary": 0.0, "go": false, "fade": 0.0, "leaving": false,
		"wob": randf() * TAU, "len": clampf(0.34 + sqrt(w) * 0.19, 0.32, 2.8), "hooked": false, "gone": false })

func shadow_goal(s: Dictionary) -> void:
	var tiles: Array = regtiles[s.reg]
	for k in 14:
		var v: Vector2i = tiles.pick_random()
		var p := Vector2(v) + Vector2(0.5, 0.5)
		if p.distance_to(s.pos) < 5 and near_ok(s.fish, v.x, v.y): s.goal = p; return
	s.goal = s.pos

func update_shadows(dt: float) -> void:
	var band := Game.time_band()
	for reg in SHCOUNT:
		var n := 0
		for s in shadows:
			if s.reg == reg and not s.leaving: n += 1
		if n < SHCOUNT[reg] and randf() < dt * (3.0 if n < SHCOUNT[reg] / 2 else 0.5): spawn_shadow(reg)
	for s in shadows:
		if s.fish.has("t") and not (band in s.fish.t): s.leaving = true
		s.fade = s.fade - dt * 0.6 if s.leaving else minf(1.0, s.fade + dt * 0.5)
		s.spook -= dt; s.wary -= dt
		s.wob += dt * (14.0 if s.spook > 0 or s.hooked else 5.0)
		if s.hooked or (is_same(s, target) and state != "wait"): continue
		var goal: Vector2 = s.goal
		var sp: float = s.speed
		if s.spook > 0 and bob != null:
			goal = s.pos + (s.pos - bob).normalized() * 3.0; sp *= 2.8
		elif s.go and bob != null and state == "wait":
			goal = bob; sp *= 1.25
		elif s.pos.distance_to(s.goal) < 0.3 or randf() < dt * 0.08: shadow_goal(s)
		var d: float = s.pos.distance_to(goal)
		if d > 0.04:
			var want = (goal - s.pos).angle()
			s.dir += wrapf(want - s.dir, -PI, PI) * minf(1.0, dt * 4)
			var np: Vector2 = s.pos + Vector2(cos(s.dir), sin(s.dir)) * minf(d, sp * dt)
			if is_water(np) and region_at(np) == s.reg: s.pos = np
			else: shadow_goal(s); s.dir += PI * 0.6
	shadows = shadows.filter(func(s): return not (s.gone or (s.leaving and s.fade <= 0)))

func visible_shadow(s: Dictionary) -> bool: return not s.leaving and not s.hooked and s.fade > 0.5

# ---------- the minigame ----------
func start_cast(pt = null) -> void:
	if not near_water(): return
	if Game.S.cooler.size() >= Game.S.cooler_cap: emit_signal("message", "Cooler's full. Sell at Lou's first."); return
	player.path.clear()
	state = "power"; t = 0.0
	tgt = null
	if pt != null:
		var sd := 1.3
		for s in shadows:
			if visible_shadow(s) and s.pos.distance_to(pt) < sd: sd = s.pos.distance_to(pt); tgt = s
		if tgt == null: tgt = { "pos": pt, "point": true }
	else:
		var bd := 99.0
		for s in shadows:
			if not visible_shadow(s): continue
			var d: float = s.pos.distance_to(player.position)
			if d >= MINR - 0.2 and d <= MAXR + 0.3 and d < bd: bd = d; tgt = s
	aim = (tgt.pos - player.position).angle() if tgt != null else player.face
	player.face = aim

func aim_target(a: float) -> Variant:
	var best = null
	var bs := 0.32
	for s in shadows:
		if not visible_shadow(s): continue
		var d: float = s.pos.distance_to(player.position)
		if d < MINR - 0.2 or d > MAXR + 0.3: continue
		var da := absf(wrapf((s.pos - player.position).angle() - a, -PI, PI))
		if da < bs: bs = da; best = s
	return best

func release_cast() -> void:
	var err := absf(power - green)
	quiet = err < SWEET
	var d := MINR + power * (MAXR - MINR)
	var p := player.position + Vector2(cos(aim), sin(aim)) * d
	if not quiet: p += Vector2.from_angle(randf() * TAU) * minf(1.4, err * 3)
	if not is_water(p):
		state = "idle"
		var tt := Town.t_at(floori(p.x), floori(p.y))
		emit_signal("message", "Snagged a bush. Reel it back and try again." if tt == Town.T.BUSH or tt == Town.T.TREE else "That landed on dry land. Try again.")
		return
	bob = p; spot = region_at(p); state = "wait"; t = 0.0; wait_t = 0.0; target = null; blind = false; twitch = 0.0
	splash = 0.35 if quiet else 0.7; splash_big = not quiet
	if not quiet:
		for s in shadows:
			if s.reg == spot and s.pos.distance_to(p) < 2.4 + err * 4: s.spook = 2.2; s.wary = 7.0; s.go = false
	var on_it: bool = tgt != null and not tgt.get("point", false) and tgt.pos.distance_to(p) < 1.3
	emit_signal("message", ("Right on it. Now wait…" if on_it else "Quiet cast.") if quiet else "Splash! That spooked anything nearby.")

func drop_target(wary: float) -> void:
	if target != null:
		target.go = false; target.hooked = false
		if wary > 0: target.spook = 2.5; target.wary = wary
	target = null

func cancel() -> void:
	drop_target(0); state = "idle"; holding = false; fish = null

func action_down() -> void:
	match state:
		"power": release_cast()
		"wait":
			twitch = 1.4; holding = true
			var a: float = (player.position - bob).angle()
			var n: Vector2 = bob + Vector2.from_angle(a) * 0.3
			if is_water(n): bob = n
			splash = 0.25; splash_big = false
		"nibble":
			emit_signal("message", "Too early! It spat the hook.")
			drop_target(6); state = "wait"; wait_t = 0.0; t = 0.0; blind = false
		"bite":
			state = "reel"; tension = 0.35; progress = 0.3; ang = 0.0; run = 0.0; run_t = randf_range(0.6, 1.4); thrash_t = randf_range(1.0, 2.2); holding = true
			bob0 = bob
			var a: float = (bob - player.position).angle()
			shore = player.position + Vector2.from_angle(a) * 0.9
			perp = Vector2(-sin(a), cos(a))
			if perp.x < -0.2 or (absf(perp.x) <= 0.2 and perp.y < 0): perp = -perp
			if target != null: target.hooked = true
		"reel": holding = true

func action_up() -> void: holding = false

func update(dt: float) -> void:
	update_shadows(dt)
	var rl: Dictionary = Game.rods[Game.rod_level()]
	var rt: float = rl.t
	var rr: float = rl.r
	if splash > 0: splash -= dt
	player.fishing_pose = state != "idle"
	match state:
		"power":
			t += dt; power = (sin(t * 2.6 - PI / 2) + 1) / 2
			if turn != 0:
				aim += turn * 1.8 * dt; tgt = aim_target(aim)
			elif tgt != null and not tgt.get("point", false): aim = (tgt.pos - player.position).angle()
			if tgt != null and (tgt.get("gone", false) or tgt.get("leaving", false) or tgt.get("hooked", false)): tgt = null
			green = clampf((tgt.pos.distance_to(player.position) - MINR) / (MAXR - MINR), 0, 1) if tgt != null else 0.55
			player.face = aim
		"wait":
			t += dt; wait_t += dt; twitch -= dt
			if holding:
				var a: float = (player.position - bob).angle()
				var n: Vector2 = bob + Vector2.from_angle(a) * dt
				if not is_water(n) or n.distance_to(player.position) < 1.0:
					drop_target(0); state = "idle"; holding = false; emit_signal("message", "Reeled all the way in. Cast again."); return
				bob = n; twitch = maxf(twitch, 0.3)
			if target == null:
				for s in shadows:
					if s.reg != spot or s.wary > 0 or s.spook > 0 or s.fade < 0.6 or s.leaving: continue
					var R := 2.3 + (0.8 if Game.bait_mul(s.fish) > 1 else 0.0) + (1.6 if twitch > 0 else 0.0)
					if s.pos.distance_to(bob) > R: continue
					var rate: float = (0.22 if s.fish.get("legend", false) else 0.45 if s.fish.pull > 0.6 else 0.85) * (2.0 if twitch > 0 and not s.fish.get("legend", false) else 1.0) * Game.bait_mul(s.fish) * (1.0 if quiet else 0.6)
					if randf() < rate * dt: s.go = true; target = s; break
				if target == null and wait_t > 14 and randf() < dt * 0.25:
					var f = pick_fish(spot, func(x): return x.get("junk", false) or (not x.get("legend", false) and x.pull <= 0.55))
					if f != null: fish = f; fw = fish_weight(f); blind = true; state = "nibble"; t = 0.0; nib = randf_range(0.3, 0.9)
			elif target.leaving or target.gone or target.spook > 0: drop_target(0)
			elif target.pos.distance_to(bob) < 0.32:
				state = "nibble"; t = 0.0; nib = randf_range(0.4, 1.3) * (1.5 if target.fish.get("legend", false) else 1.0); blind = false
		"nibble":
			t += dt
			if target != null: target.pos = bob - Vector2.from_angle(target.dir) * target.len * 0.45
			if t >= nib:
				if target != null: fish = target.fish; fw = target.w
				state = "bite"; t = 0.0; splash = 0.6; splash_big = true
		"bite":
			t += dt
			if target != null: target.pos = bob - Vector2.from_angle(target.dir) * target.len * 0.45
			if t > 0.95 + Game.rod_level() * 0.1:
				emit_signal("message", "Missed it! Hook it the moment it dips.")
				drop_target(8); state = "wait"; wait_t = 0.0; t = 0.0; blind = false
		"reel":
			var fp: float = fish.pull
			run_t -= dt
			if run_t <= 0:
				run = 0.0 if randf() < 0.25 else (-1.0 if randf() < 0.5 else 1.0); run_t = randf_range(0.8, 2.2) / (0.6 + fp)
			ang += (run * (0.45 + fp * 0.9) + pull * 1.35) * dt * 0.85
			ang -= ang * dt * 0.25; ang = clampf(ang, -1.05, 1.05)
			var side := absf(ang)
			if holding:
				tension += (0.45 + 0.6 * fp) * rt * dt
				progress += (0.26 * rr * (1.2 - fp * 0.6) if tension >= BAND[0] and tension <= BAND[1] else 0.05) * (1 - minf(0.7, side * 0.75)) * dt
			else:
				tension -= 0.75 * dt; progress -= (0.03 + 0.06 * fp) * dt
			if side > 0.55: tension += (side - 0.55) * 1.1 * rt * dt
			if side >= 1: tension += 0.3; ang *= 0.4; emit_signal("message", "It ran the line sideways! Pull the other way.")
			thrash_t -= dt
			if thrash_t <= 0:
				tension += fp * 0.32 * rt; splash = 0.45; splash_big = true; thrash_t = randf_range(1.1, 3.0) / (0.55 + fp)
			tension = maxf(0.0, tension)
			var k := clampf(progress, 0, 1) * 0.85
			bob = bob0 + (shore - bob0) * k + perp * ang * 1.6
			if target != null:
				target.pos = bob; target.dir = (bob - player.position).angle() + ang * 0.8 + sin(target.wob) * 0.4
			if tension >= 1:
				state = "idle"; holding = false; drop_target(20)
				emit_signal("message", "Snap! The line broke." + (" That felt like something legendary." if fish.get("legend", false) else ""))
			elif progress <= 0:
				state = "idle"; holding = false; drop_target(20); emit_signal("message", "It got away.")
			elif progress >= 1: _land()
	if state == "idle": bob = null
	queue_redraw()

func _land() -> void:
	var f: Dictionary = fish
	var w := fw if fw > 0 else fish_weight(f)
	state = "idle"; holding = false
	if target != null: target.gone = true; target = null
	var value: int = int(f.flat) if f.has("flat") else maxi(1, int(round(w * f.pp)))
	var rec: Dictionary = Game.S.journal.get(f.n, {})
	var is_record: bool = rec.is_empty() or w > rec.w
	Game.S.journal[f.n] = { "w": maxf(w, rec.get("w", 0.0)), "spot": spot, "n": rec.get("n", 0) + 1, "legend": f.get("legend", false) }
	emit_signal("landed", { "n": f.n, "w": w, "value": value, "spot": spot, "legend": f.get("legend", false), "junk": f.get("junk", false),
		"release": f.get("release", false), "rep": f.get("rep", 1), "note": f.get("note", ""), "record": is_record, "day": Game.S.day })

# ---------- drawing ----------
func _draw() -> void:
	var dk := Game.darkness()
	var cam_rect := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var view := Rect2(cam_rect.position / Game.TS, cam_rect.size / Game.TS).grow(3)
	for s in shadows:
		if not view.has_point(s.pos): continue
		var al: float = 0.3 * s.fade
		if s.reg == 5: al *= 0.75
		if dk > 0.3: al *= 0.65
		if s.fish.get("legend", false): al = minf(0.5, al * 1.45)
		var glow: bool = s.fish.get("glow", false)
		Art.fish_shadow(self, s.pos, s.dir, s.len, al * 1.3 if glow else al, glow, s.wob)
		if s.fish.get("legend", false) and s.fade > 0.5 and not s.hooked:
			draw_set_transform(s.pos, s.dir, Vector2(1, 0.5))
			draw_arc(Vector2.ZERO, s.len * 0.75, 0, TAU, 24, Color(1, 1, 1, 0.1 + 0.08 * sin(Time.get_ticks_msec() / 450.0)), 0.04)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## The line, bobber, aim marker and splash. Drawn above everything else in the world.
func draw_line_layer(ci: CanvasItem) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if state == "power":
		var d := MINR + power * (MAXR - MINR)
		var l := player.position + Vector2.from_angle(aim) * d
		var ok := absf(power - green) < SWEET
		var mid := (player.position + l) / 2 + Vector2(0, -1.4)
		var arc := PackedVector2Array()
		for i in 13: arc.append(Art._quad(player.position + Vector2(0, -0.4), mid, l, i / 12.0))
		ci.draw_dashed_line(arc[0], arc[6], Color(1, 1, 1, 0.55), 0.05, 0.2)
		ci.draw_dashed_line(arc[6], arc[12], Color(1, 1, 1, 0.55), 0.05, 0.2)
		if tgt != null:
			var tp: Vector2 = tgt.pos
			var gc := Color(0.56, 0.82, 0.62, 0.95)
			ci.draw_arc(tp, 0.55, 0, TAU, 24, gc, 0.07)
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: ci.draw_line(tp + dv * 0.35, tp + dv * 0.85, gc, 0.07)
		ci.draw_arc(l, 0.28 if ok else 0.38, 0, TAU, 24, Color("#8fd19e") if ok else Color(1, 1, 1, 0.95), 0.09)
		ci.draw_circle(l, 0.07, Color("#8fd19e") if ok else Color.WHITE)
		return
	if state == "idle" or bob == null: return
	var b: Vector2 = bob
	var dip := 0.0
	if state == "wait": dip = sin(now * 3) * 0.04
	elif state == "nibble": dip = maxf(0, sin(now * 24)) * 0.08
	elif state == "bite": dip = 0.2 + sin(now * 30) * 0.05
	var r := player.rod_tip() + (Vector2.from_angle(player.face + pull * 0.5) - Vector2.from_angle(player.face)) * 0.95
	var ctrl := (r + b) / 2 + (-perp * ang * 0.4 if state == "reel" else Vector2(0, 0.4))
	var line := PackedVector2Array()
	for i in 13: line.append(Art._quad(r, ctrl, b + Vector2(0, dip), i / 12.0))
	ci.draw_polyline(line, Color(1, 0.67, 0.59, 0.95) if state == "reel" and tension > BAND[1] else Color(1, 1, 1, 0.85), 0.05)
	if state == "reel":
		if target == null: Art.fish_shadow(ci, b, (b - player.position).angle() + ang * 0.8, clampf(0.34 + sqrt(maxf(fw, 1)) * 0.19, 0.32, 2.8), 0.4, false, now * 14)
		var rr := 0.35 + sin(now * 9) * 0.08
		ci.draw_set_transform(b, 0, Vector2(1, 0.5)); ci.draw_arc(Vector2.ZERO, rr + 0.25, 0, TAU, 24, Color(1, 1, 1, 0.5), 0.05); ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		Art.ellipse(ci, b + Vector2(0, 0.12), 0.3 + absf(dip), 0.1, Color(1, 1, 1, 0.35))
		ci.draw_arc(b + Vector2(0, dip - 0.06), 0.13, PI, TAU, 12, Color("#e2583e"), 0.13)
		ci.draw_arc(b + Vector2(0, dip - 0.06), 0.065, 0, PI, 12, Color.WHITE, 0.13)
		if state == "bite": Art.text(ci, b + Vector2(0, -0.45), "!", 0.7, Color("#e2583e"), Color.WHITE)
	if splash > 0:
		var big := 1.0 if splash_big else 0.45
		var k := 1.0 - splash / 0.7
		ci.draw_set_transform(b, 0, Vector2(1, 0.4))
		ci.draw_arc(Vector2.ZERO, (0.3 + k * 1.1) * big + 0.15, 0, TAU, 24, Color(1, 1, 1, clampf(1 - k, 0, 1)), 0.06)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
