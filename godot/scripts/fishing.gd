class_name Fishing
extends Node2D
## Fish shadows swimming in every body of water, plus the whole fishing minigame:
## aim and cast, wait and twitch, nibble, bite, and the reel fight.

signal landed(c: Dictionary)
signal message(text: String)

const SHCOUNT := { 1: 5, 7: 7, 2: 16, 3: 6, 4: 4, 5: 5, 6: 6, 9: 12, 10: 6, 11: 6, 12: 7, 13: 10, 14: 24, 15: 18, 16: 6, 17: 5 }
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
# manholes: every cover drawn in the street can be pried up and fished with Lou's pry bar
var manholes: Array = []   # tile centres, worked out once from the street tiles
var manhole := -1          # the manhole being fished, or -1
var bite_at := 0.0
var hold_t := 0.0
const MANHOLE_TRIES := 3

func _ready() -> void:
	for y in Town.MH:
		for x in Town.MW:
			var i := Town.idx(x, y)
			if Town.region[i] and Town.is_water_t(Town.tile[i]):
				var r: int = Town.region[i]
				if not regtiles.has(r): regtiles[r] = []
				regtiles[r].append(Vector2i(x, y))
			if Town.floodable[i]:
				if not regtiles.has(7): regtiles[7] = []
				regtiles[7].append(Vector2i(x, y))
			if is_manhole_tile(x, y): manholes.append(Vector2(x + 0.5, y + 0.5))

## The same test the street art uses to draw a manhole cover, so every cover you can see is one you can fish.
static func is_manhole_tile(x: int, y: int) -> bool:
	if Town.tile[Town.idx(x, y)] != Town.T.ROAD or Town.in_bridge(x, y): return false
	var h := Town.hash2(x, y)
	return h > 0.4 and h < 0.406

## The manhole the player is standing at, or -1.
func manhole_near() -> int:
	if player.in_boat(): return -1
	for i in manholes.size():
		var m: Vector2 = manholes[i]
		if m.distance_to(player.position) < 1.25 and Unlocks.open_p(m): return i
	return -1

func start_manhole(i: int) -> void:
	if not Game.S.gear.has("prybar"): emit_signal("message", "The cover's too heavy to lift by hand. Lou sells a pry bar for $15."); return
	if Game.S.cooler.size() >= Game.S.cooler_cap: emit_signal("message", "Cooler's full. Sell at Lou's first."); return
	var mh: Dictionary = Game.S.get("mh", {})
	var r: Dictionary = mh.get(str(i), {})
	if not r.is_empty() and int(r.day) == int(Game.S.day) and int(r.n) >= MANHOLE_TRIES:
		emit_signal("message", "Nothing else down this one today. Try another manhole."); return
	player.path.clear()
	manhole = i; bob = manholes[i]; spot = 8; state = "wait"; t = 0.0; wait_t = 0.0; quiet = true; target = null; blind = false; twitch = 0.0; hold_t = 0.0
	bite_at = randf_range(2.5, 7.0); splash = 0.35; splash_big = false
	player.face = (bob - player.position).angle()
	Game.S.visited["8"] = 1
	Sound.play("cast"); Sound.play_later("plop", 0.3, -4.0)
	emit_signal("message", "You pry up the cover and drop a line into the dark.")

func _manhole_wait(dt: float) -> void:
	t += dt; twitch -= dt
	if holding:
		hold_t += dt
		if hold_t > 0.5: state = "idle"; holding = false; emit_signal("message", "You pull your line back up."); return
	else: hold_t = 0.0
	if t >= bite_at - (1.5 if twitch > 0 else 0.0):
		var f = pick_fish(8, func(_x): return true)
		if f == null: return
		fish = f; fw = fish_weight(f); blind = true; state = "nibble"; t = 0.0; nib = randf_range(0.3, 1.0); Sound.play("nibble")
		if not Game.S.has("mh") or not (Game.S.mh is Dictionary): Game.S.mh = {}
		var r: Dictionary = Game.S.mh.get(str(manhole), {})
		Game.S.mh[str(manhole)] = { "day": Game.S.day, "n": (int(r.n) if not r.is_empty() and int(r.day) == int(Game.S.day) else 0) + 1 }

func flooded_at(x: int, y: int) -> bool: return Town.inb(x, y) and Town.floodable[Town.idx(x, y)] and Game.flooded()
func is_water(p: Vector2) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	return Town.is_water_t(Town.t_at(x, y)) or flooded_at(x, y)
func region_at(p: Vector2) -> int:
	var x := floori(p.x)
	var y := floori(p.y)
	if not Town.inb(x, y): return 0
	return 7 if flooded_at(x, y) else Town.region[Town.idx(x, y)]

func near_water() -> bool:
	if player.in_boat(): return true
	var px := floori(player.position.x)
	var py := floori(player.position.y)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if is_water(Vector2(px + dx, py + dy)) and Vector2(px + dx + 0.5, py + dy + 0.5).distance_to(player.position) < 1.75: return true
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
	for k in 20:   # not on a tile the curved bank mostly covers
		if swimmable(Vector2(tp) + Vector2(0.5, 0.5), reg): break
		tp = cand.pick_random()
	if not swimmable(Vector2(tp) + Vector2(0.5, 0.5), reg): return
	var w := fish_weight(f)
	shadows.append({ "reg": reg, "pos": Vector2(tp) + Vector2(0.5, 0.5), "goal": Vector2(tp) + Vector2(0.5, 0.5), "fish": f, "w": w, "dir": randf() * TAU,
		"speed": randf_range(0.35, 0.7) * (0.55 if f.get("legend", false) else 1.0), "spook": 0.0, "wary": 0.0, "go": false, "fade": 0.0, "leaving": false,
		"wob": randf() * TAU, "len": clampf(0.34 + sqrt(w) * 0.19, 0.32, 2.8), "hooked": false, "gone": false, "bounce": 0.0, "bumps": 0 })

func shadow_goal(s: Dictionary) -> void:
	var tiles: Array = regtiles[s.reg]
	for k in 14:
		var v: Vector2i = tiles.pick_random()
		var p := Vector2(v) + Vector2(0.5, 0.5)
		# only somewhere it can swim to in a straight line, so it never sets off into a bank or an island
		if p.distance_to(s.pos) < 5 and near_ok(s.fish, v.x, v.y) and clear_swim(s.pos, p, s.reg): s.goal = p; return
	s.goal = s.pos

## Can a fish be here? Its own water region, and on the curved shores (beaches, Bird Key, Maple Park
## Pond) the water you can see, with a little room so it doesn't poke its nose into the bank.
func swimmable(p: Vector2, reg: int, margin := 0.42) -> bool:
	if region_at(p) != reg or not is_water(p): return false
	if reg != 7 and Ground.is_coast(floori(p.x), floori(p.y)) and Ground.land_at(p) > margin: return false
	return true

## Open water all the way from a to b.
func clear_swim(a: Vector2, b: Vector2, reg: int) -> bool:
	var n := ceili(a.distance_to(b) / 0.25)
	for i in range(1, n + 1):
		if not swimmable(a.lerp(b, float(i) / n), reg): return false
	return true

## A fish ran into the edge: bump off it like a ball off a wall, nudged a little at random,
## and swim straight out that way for a moment before picking somewhere new.
func bounce(s: Dictionary, heading: Vector2) -> void:
	var open := Vector2.ZERO          # points away from the wall, toward open water
	for k in 16:
		var d := Vector2.from_angle(k * TAU / 16)
		for r in [0.4, 0.8]:
			if swimmable(s.pos + d * r, s.reg): open += d / r
	var nd: Vector2
	if open.length() < 0.01: nd = -heading
	else:
		var n := open.normalized()
		nd = heading.bounce(n) if heading.dot(n) < 0 else heading
		nd = (nd + n * 0.35).normalized()   # lean out from the wall so corners don't trap it
	nd = nd.rotated(randf_range(-0.35, 0.35))
	# keep it only if that way is actually open; otherwise take the nearest open heading
	if not clear_swim(s.pos, s.pos + nd * 0.6, s.reg):
		var found := false
		for k in range(1, 12):
			for sgn in [1, -1]:
				var tr := nd.rotated(sgn * k * PI / 12)
				if not found and clear_swim(s.pos, s.pos + tr * 0.6, s.reg): nd = tr; found = true
			if found: break
	s.dir = nd.angle(); s.bounce = randf_range(0.7, 1.3); s.bumps += 1
	s.goal = s.pos + nd * 2.0
	if s.go and s.bumps >= 2:   # couldn't find a way to the bait, so it loses interest
		s.go = false
		if is_same(s, target): drop_target(0)

func update_shadows(dt: float) -> void:
	var band := Game.time_band()
	var flood := Game.flooded()
	for reg in SHCOUNT:
		if reg == 7 and not flood: continue
		var n := 0
		for s in shadows:
			if s.reg == reg and not s.leaving: n += 1
		if n < SHCOUNT[reg] and randf() < dt * (3.0 if n < SHCOUNT[reg] / 2 else 0.5): spawn_shadow(reg)
	for s in shadows:
		if (s.fish.has("t") and not (band in s.fish.t)) or (s.reg == 7 and not flood): s.leaving = true
		s.fade = s.fade - dt * 0.6 if s.leaving else minf(1.0, s.fade + dt * 0.5)
		s.spook -= dt; s.wary -= dt
		s.wob += dt * (14.0 if s.spook > 0 or s.hooked else 5.0)
		if s.hooked or (is_same(s, target) and state != "wait"): continue
		var goal: Vector2 = s.goal
		var sp: float = s.speed
		var fwd := Vector2(cos(s.dir), sin(s.dir))
		if s.bounce > 0:
			# just bumped off the edge: keep swimming out the way it bounced
			s.bounce -= dt; goal = s.pos + fwd * 2.0
			if s.spook > 0: sp *= 2.4
			if s.bounce <= 0: shadow_goal(s)
		elif s.spook > 0 and bob != null:
			goal = s.pos + flee_dir(s) * 3.0; sp *= 2.8
		elif s.go and bob != null and state == "wait":
			goal = bob; sp *= 1.25
		else:
			s.bumps = 0
			if s.pos.distance_to(s.goal) < 0.3 or randf() < dt * 0.08: shadow_goal(s)
			goal = s.goal
		var d: float = s.pos.distance_to(goal)
		if d > 0.04:
			if s.bounce <= 0:
				var want = (goal - s.pos).angle()
				s.dir += wrapf(want - s.dir, -PI, PI) * minf(1.0, dt * 4)
			fwd = Vector2(cos(s.dir), sin(s.dir))
			var np: Vector2 = s.pos + fwd * minf(d, sp * dt)
			var nose: Vector2 = np + fwd * minf(0.45, s.len * 0.4)
			# the bait can sit right at the bank, so a fish going for it only needs the water tile there
			var near_bait: bool = s.go and bob != null and np.distance_to(bob) < 1.0
			if near_bait and is_water(np) and region_at(np) == s.reg: s.pos = np
			elif swimmable(np, s.reg) and swimmable(nose, s.reg): s.pos = np
			elif not swimmable(s.pos, s.reg):
				# somehow already over the bank (old save, flood going down): head for the nearest open water
				s.pos = s.pos.move_toward(open_water_near(s.pos, s.reg), sp * dt)
			else: bounce(s, fwd)
	shadows = shadows.filter(func(s): return not (s.gone or (s.leaving and s.fade <= 0)))

func open_water_near(p: Vector2, reg: int) -> Vector2:
	for r in [0.3, 0.6, 1.0, 1.5, 2.0, 3.0]:
		for k in 12:
			var c: Vector2 = p + Vector2.from_angle(k * TAU / 12) * r
			if swimmable(c, reg): return c
	return p

## Away from the bait, but along open water rather than straight into the bank.
func flee_dir(s: Dictionary) -> Vector2:
	var away: Vector2 = (s.pos - bob).normalized()
	if away == Vector2.ZERO: away = Vector2.from_angle(s.dir)
	for k in 7:
		for sgn in [1, -1]:
			var tr := away.rotated(sgn * k * PI / 8)
			if clear_swim(s.pos, s.pos + tr * 1.5, s.reg): return tr
	return away

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
		Sound.play("cast")
		emit_signal("message", "Snagged a bush. Reel it back and try again." if tt == Town.T.BUSH or tt == Town.T.TREE else "That landed on dry land. Try again.")
		return
	bob = p; spot = region_at(p); state = "wait"; t = 0.0; wait_t = 0.0; target = null; blind = false; twitch = 0.0
	Sound.play("cast"); Sound.play_later("plop", 0.22, -2.0 if quiet else 2.0)
	splash = 0.35 if quiet else 0.7; splash_big = not quiet
	WaterFx.ripple(p, 0.6 if quiet else 1.1)
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
	drop_target(0); state = "idle"; holding = false; fish = null; manhole = -1

func action_down() -> void:
	match state:
		"power": release_cast()
		"wait":
			twitch = 1.4; holding = true
			if manhole >= 0: splash = 0.25; splash_big = false; return
			var a: float = (player.position - bob).angle()
			var n: Vector2 = bob + Vector2.from_angle(a) * 0.3
			if is_water(n): bob = n
			splash = 0.25; splash_big = false
		"nibble":
			emit_signal("message", "Too early! It spat the hook."); Sound.play("splash", -4)
			drop_target(6); state = "wait"; wait_t = 0.0; t = 0.0; blind = false
		"bite":
			Sound.play("splash")
			state = "reel"; tension = 0.35; progress = 0.3; ang = 0.0; run = 0.0; run_t = randf_range(0.6, 1.4); thrash_t = randf_range(1.0, 2.2); holding = true
			bob0 = bob
			var a: float = (bob - player.position).angle()
			shore = player.position + Vector2.from_angle(a) * 0.9
			perp = Vector2(-sin(a), cos(a))
			if perp.x < -0.2 or (absf(perp.x) <= 0.2 and perp.y < 0): perp = -perp
			if manhole >= 0: shore = bob0; perp = Vector2.ZERO
			if target != null: target.hooked = true
		"reel": holding = true

func action_up() -> void: holding = false

func update(dt: float) -> void:
	update_shadows(dt)
	var rl: Dictionary = Game.rod()
	var rt: float = rl.t
	var rr: float = rl.r
	if splash > 0: splash -= dt
	player.fishing_pose = state != "idle"
	player.rod_pull = pull if state == "reel" else 0
	player.rod_bend = clampf(tension, 0.0, 1.2) if state == "reel" else (0.25 if state == "bite" else 0.0)
	match state:
		"power":
			t += dt; power = (sin(t * 2.6 - PI / 2) + 1) / 2
			if turn != 0:
				aim += turn * 1.8 * dt; tgt = aim_target(aim)
			elif tgt != null and not tgt.get("point", false): aim = (tgt.pos - player.position).angle()
			if tgt != null and (tgt.get("gone", false) or tgt.get("leaving", false) or tgt.get("hooked", false)): tgt = null
			green = clampf((tgt.pos.distance_to(player.position) - MINR) / (MAXR - MINR), 0, 1) if tgt != null else 0.55
			player.face = aim
		"wait" when manhole >= 0: _manhole_wait(dt)
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
					var rate: float = (0.22 if s.fish.get("legend", false) else 0.45 if s.fish.pull > 0.6 else 0.85) * (2.0 if twitch > 0 and not s.fish.get("legend", false) else 1.0) * Game.bait_mul(s.fish) * (1.0 if quiet else 0.6) * (1.0 + 0.7 * Game.wx.rain)
					if randf() < rate * dt: s.go = true; target = s; break
				if target == null and wait_t > 14 and randf() < dt * 0.25:
					var f = pick_fish(spot, func(x): return x.get("junk", false) or (not x.get("legend", false) and x.pull <= 0.55))
					if f != null: fish = f; fw = fish_weight(f); blind = true; state = "nibble"; t = 0.0; nib = randf_range(0.3, 0.9); Sound.play("nibble")
			elif target.leaving or target.gone or target.spook > 0: drop_target(0)
			elif target.pos.distance_to(bob) < 0.32:
				state = "nibble"; t = 0.0; nib = randf_range(0.4, 1.3) * (1.5 if target.fish.get("legend", false) else 1.0); blind = false; Sound.play("nibble")
		"nibble":
			t += dt
			if target != null: target.pos = bob - Vector2.from_angle(target.dir) * target.len * 0.45
			if t >= nib:
				if target != null: fish = target.fish; fw = target.w
				state = "bite"; t = 0.0; splash = 0.6; splash_big = true; Sound.play("bite")
		"bite":
			t += dt
			if target != null: target.pos = bob - Vector2.from_angle(target.dir) * target.len * 0.45
			if t > 0.95 + float(Game.rod().hook):
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
				tension += fp * 0.32 * rt; splash = 0.45; splash_big = true; Sound.play("splash", -3); thrash_t = randf_range(1.1, 3.0) / (0.55 + fp)
			tension = maxf(0.0, tension)
			var k := clampf(progress, 0, 1) * 0.85
			bob = bob0 + (shore - bob0) * k + perp * ang * 1.6
			if target != null:
				target.pos = bob; target.dir = (bob - player.position).angle() + ang * 0.8 + sin(target.wob) * 0.4
			if tension >= 1:
				state = "idle"; holding = false; drop_target(20); Sound.play("snap")
				emit_signal("message", "Snap! The line broke." + (" That felt like something legendary." if fish.get("legend", false) else ""))
			elif progress <= 0:
				state = "idle"; holding = false; drop_target(20); emit_signal("message", "It got away."); Sound.play("splash")
			elif progress >= 1: _land()
	if state == "idle": bob = null; manhole = -1
	queue_redraw()

func _land() -> void:
	var f: Dictionary = fish
	var w := fw if fw > 0 else fish_weight(f)
	state = "idle"; holding = false
	Sound.play("legend" if f.get("legend", false) else "catch", 0.0, 0.0)
	if target != null: target.gone = true; target = null
	var value: int = int(f.flat) if f.has("flat") else maxi(1, int(round(w * f.pp)))
	var rec: Dictionary = Game.S.journal.get(f.n, {})
	var is_record: bool = rec.is_empty() or w > rec.w
	Game.S.journal[f.n] = { "w": maxf(w, rec.get("w", 0.0)), "spot": spot, "n": rec.get("n", 0) + 1, "legend": f.get("legend", false) }
	emit_signal("landed", { "n": f.n, "w": w, "value": value, "spot": spot, "legend": f.get("legend", false), "junk": f.get("junk", false),
		"release": f.get("release", false), "rep": f.get("rep", 1), "note": f.get("note", ""), "record": is_record, "day": Game.S.day, "tm": Game.S.min,
		"mutant": f.get("mutant", false), "pull": f.pull })

# ---------- drawing ----------
## The manhole you're fishing: a black hole in the street with the cover slid off to one side.
func _draw_open_manhole(ci: CanvasItem, m: Vector2) -> void:
	ci.draw_circle(m + Vector2(0.03, 0.04), 0.33, Color(0, 0, 0, 0.3))
	ci.draw_circle(m, 0.3, Color("#0b0c0d"))
	ci.draw_arc(m, 0.3, 0, TAU, 24, Color("#3a3d41"), 0.05)
	var c := m + Vector2(0.55, 0.32)
	ci.draw_circle(c + Vector2(0.03, 0.04), 0.3, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, 0.3, Color("#5a5c5e"))
	ci.draw_circle(c, 0.25, Color("#3e4042"))
	for k in range(-2, 3): ci.draw_rect(Rect2(c.x - 0.2, c.y + k * 0.08 - 0.015, 0.4, 0.03), Color(0.55, 0.55, 0.56, 0.5))
	ci.draw_arc(c, 0.3, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.15), 0.03)

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
	if manhole >= 0: _draw_open_manhole(ci, manholes[manhole])
	var b: Vector2 = bob
	var dip := 0.0
	# the bobber rides the little waves, rocking side to side, and sends out slow rings
	var sway := Vector2(sin(now * 1.3 + b.y) * 0.03, sin(now * 1.7 + b.x) * 0.025)
	if state != "reel": b += sway
	if state == "wait" or state == "nibble":
		for i in 2:
			var kr := fmod(now * 0.6 + i * 0.5, 1.0)
			ci.draw_set_transform(b + Vector2(0, 0.06), 0, Vector2(1, 0.45))
			ci.draw_arc(Vector2.ZERO, 0.18 + kr * 0.55, 0, TAU, 24, Color(1, 1, 1, 0.3 * (1.0 - kr)), 0.035)
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
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
		# the fish fights at the surface: churned water and spray, more of it the harder it pulls
		var fury := clampf(tension, 0.2, 1.0)
		Art.ellipse(ci, b + Vector2(0, 0.05), 0.45 + fury * 0.3, 0.16 + fury * 0.1, Color(1, 1, 1, 0.18 + 0.12 * sin(now * 13)))
		for i in 7:
			var k := fmod(now * (1.6 + fury) + i / 7.0, 1.0)
			var sd := floorf(now * (1.6 + fury) + i / 7.0)
			var a := Town.hash2(int(sd) * 7 + i, i * 13) * TAU
			var reach := (0.25 + Town.hash2(i, int(sd)) * 0.45) * (0.6 + fury)
			var dp := b + Vector2(cos(a), sin(a) * 0.5) * reach * k + Vector2(0, -sin(k * PI) * (0.25 + fury * 0.35))
			ci.draw_circle(dp, 0.05 * (1.0 - k * 0.5), Color(1, 1, 1, 0.8 * (1.0 - k) * fury))
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
		# a burst of droplets thrown up and falling back
		for i in 10:
			var a := i * TAU / 10 + 0.3
			var dp := b + Vector2(cos(a), sin(a) * 0.45) * (0.2 + k * 0.9) * big + Vector2(0, -sin(clampf(k, 0, 1) * PI) * 0.6 * big)
			ci.draw_circle(dp, 0.06 * big + 0.02, Color(1, 1, 1, clampf(1 - k, 0, 1) * 0.9))
		if splash_big: Art.ellipse(ci, b + Vector2(0, -0.1 - k * 0.3), 0.18 * (1 - k * 0.5), 0.35 * (1 - k), Color(1, 1, 1, clampf(0.7 - k, 0, 1)))
		ci.draw_set_transform(b, 0, Vector2(1, 0.4))
		ci.draw_arc(Vector2.ZERO, (0.3 + k * 1.1) * big + 0.15, 0, TAU, 24, Color(1, 1, 1, clampf(1 - k, 0, 1)), 0.06)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
