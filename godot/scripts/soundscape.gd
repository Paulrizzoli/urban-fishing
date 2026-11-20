class_name Soundscape
extends Node
## The sounds of where you are (v0.9.42): surf and gulls at the beach, the spillway's roar, the mill,
## the ballpark crowd, fountains, the power station's hum, wind on stormy days; cars and boats going by,
## your own skiff's motor and kayak paddle, footsteps that change with what you walk on, the reel's
## drag and the line singing under strain, and guards who shout when they spot you.
## Every loop is a Sound.set_loop() turned up by how close its source is. main.gd makes one of these.

var player: Player
var fishing: Fishing
var traffic: Traffic
var harbor: Harbor
var guards: Guards
var menu_open := func() -> bool: return false

var surf_pts: Array[Vector2] = []    # sand right at the water's edge
var gull_pts: Array[Vector2] = []    # open water where gulls hang about
var areas: Array = []                # { k, stream, r: Rect2, reach, gain, when: Callable }
var scan_t := 0.0
var near_d := {}                     # cached distances, refreshed a few times a second
var step_phase := 0
var paddle_t := 0.0
var shout_cd := 0.0
var prev_detect := 0.0
var bat_t := 20.0
var prev_state := "idle"

func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var T := Town.T
	for y in range(0, Town.MH, 2):
		for x in range(0, Town.MW, 2):
			var t := Town.t_at(x, y)
			if t == T.SAND:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]:
					if Town.is_water_t(Town.t_at(x + d.x, y + d.y)): surf_pts.append(Vector2(x + 0.5, y + 0.5)); break
	var big: Array = [[13, 14, 15], [Ironwater.RES], [Gannet.HARBOR, Gannet.MARKET, Gannet.OUTER]][Town.level]
	for y in range(0, Town.MH, 4):
		for x in range(0, Town.MW, 4):
			if Town.inb(x, y) and Town.is_water_t(Town.t_at(x, y)) and int(Town.region[Town.idx(x, y)]) in big: gull_pts.append(Vector2(x + 0.5, y + 0.5))
	if Town.level == 0:
		areas.append({ "k": "hum", "stream": "hum", "r": Rect2(63, 57, 43, 18), "reach": 8.0, "gain": 0.7 })
		for fo in [[Vector2(60.5, 130.7), 1.0], [Vector2(30.5, 127.6), 0.7]]:
			areas.append({ "k": "fountain%d" % areas.size(), "stream": "fountain", "r": Rect2(fo[0] - Vector2(0.5, 0.5), Vector2(1, 1)), "reach": 7.0 * fo[1], "gain": 0.8 * fo[1] })
	elif Town.level == 2:
		# Gannet Harbor: the container port's cranes and reefers, the outfall pouring out, the market floor at dawn
		areas.append({ "k": "hum", "stream": "hum", "r": Rect2(42, 136, 36, 28), "reach": 10.0, "gain": 0.8 })
		areas.append({ "k": "outfall", "stream": "spillway", "r": Rect2(Gannet.PIPE - Vector2(1, 1), Vector2(2, 2)), "reach": 9.0, "gain": 0.55 })
		areas.append({ "k": "market", "stream": "crowd", "r": Rect2(42, 32, 45, 12), "reach": 10.0, "gain": 0.45, "when": func(): return Game.hour() >= 3 and Game.hour() < 11 })
		# the tide mill's wheel, and the fountains in Kettle Bank Plaza's pool
		areas.append({ "k": "mill", "stream": "mill", "r": Rect2(Gannet.WHEEL - Vector2(1.5, 1.5), Vector2(2, 3)), "reach": 9.0, "gain": 0.6 })
		areas.append({ "k": "fountain", "stream": "fountain", "r": Rect2(22, 51, 12, 3), "reach": 6.0, "gain": 0.6 })
	else:
		areas.append({ "k": "spill", "stream": "spillway", "r": Rect2(44, 29, 24, 20), "reach": 38.0, "gain": 1.0 })
		areas.append({ "k": "mill", "stream": "mill", "r": Rect2(16, 39, 22, 15), "reach": 14.0, "gain": 0.9, "when": func(): return Game.hour() >= 6 and Game.hour() < 21 })
		areas.append({ "k": "crowd", "stream": "crowd", "r": Rect2(74, 63, 20, 25), "reach": 24.0, "gain": 0.9, "when": func(): return _game_on() })

## Riverhawks Field has a game on from noon to ten at night, rained out in a storm.
static func _game_on() -> bool:
	return Game.hour() >= 12 and Game.hour() < 22 and not Game.wx.get("storm", false)

## Which splash a lure or bait makes going in: a worm's soft plip up to a popper's chug.
static func entry() -> String:
	match String(Game.S.bait):
		"worms", "bread", "jig": return "lure_tiny"
		"shrimp", "lure", "glowlure": return "lure_small"
		"popper": return "lure_big"
	return "lure_med"

## A hooked fish's splash, by its weight in pounds.
static func fish_splash(w: float) -> String:
	return "fish_s" if w < 3.0 else "fish_m" if w < 12.0 else "fish_l"

static func _near(pts: Array[Vector2], p: Vector2) -> float:
	var best := 1e9
	for q in pts: best = minf(best, q.distance_squared_to(p))
	return sqrt(best)

## 1 at the source, easing to 0 at `reach` tiles away.
static func fall(d: float, reach: float) -> float:
	return pow(clampf(1.0 - d / reach, 0.0, 1.0), 2.0)

func _process(dt: float) -> void:
	if player == null: return
	if get_tree().paused or menu_open.call():
		Sound.stop_loops(); Sound.duck = 0.0; return
	var p := player.position
	var dk := Game.darkness()
	var rain: float = Game.wx.get("rain", 0.0)
	scan_t -= dt
	if scan_t <= 0:
		scan_t = 0.25
		near_d.surf = _near(surf_pts, p)
		near_d.gull = _near(gull_pts, p)
	# ---- places ----
	Sound.set_loop("surf", "surf", fall(near_d.surf, 16.0) * (1.0 + rain * 0.3))
	Sound.set_loop("gulls", "gulls", fall(near_d.gull, 14.0) * (1.0 - dk) * (1.0 - rain * 0.8) * 0.8)
	var roar := 0.0
	for a in areas:
		var d := _rect_dist(a.r, p)
		var on: bool = a.when.call() if a.has("when") else true
		var v: float = fall(d, a.reach) * a.gain * (1.0 if on else 0.0)
		Sound.set_loop(a.k, a.stream, v, 1.0, "Ambience", 0.6)
		if a.k == "spill": roar = v
	Sound.set_loop("wind", "wind", clampf((TownLife.wind() - 1.3) / 1.6, 0.0, 1.0) * 0.7)
	# ---- cars: the two nearest engines, and a city hum from how many are about ----
	var cars: Array = []
	var busy := 0
	if traffic != null:
		for c in traffic.cars:
			if not c.visible or c.fade < 0.2: continue
			var d: float = c.position.distance_to(p)
			if d < 16: busy += 1
			if d < 11: cars.append([d, c])
	cars.sort_custom(func(a, b): return a[0] < b[0])
	for i in 2:
		if i < cars.size():
			var c = cars[i][1]
			Sound.set_loop("engine%d" % i, "engine", fall(cars[i][0], 11.0) * clampf(0.25 + c.speed / 4.0, 0.0, 1.0), 0.75 + c.speed * 0.09 + i * 0.04, "SFX", 3.0)
		else: Sound.set_loop("engine%d" % i, "engine", 0.0, 1.0, "SFX", 3.0)
	Sound.set_loop("city", "city", clampf((busy - 2) / 8.0, 0.0, 1.0) * 0.8)
	# ---- boats: the nearest marina boat under way, and your own skiff ----
	var bd := 1e9
	var bs := 0.0
	if harbor != null:
		for b in harbor.boats:
			if b.state == "moored" or b.state == "away": continue
			var d: float = b.centre.distance_to(p)
			if d < bd: bd = d; bs = b.speed
	Sound.set_loop("boat", "motor", fall(bd, 20.0) * clampf(0.3 + bs / 3.0, 0.0, 1.0), 0.8 + bs * 0.12, "SFX", 2.0)
	var skiff := player.in_boat() and player.boat_kind() == "skiff"
	Sound.set_loop("skiff", "motor", (0.8 if player.moving else 0.3) if skiff else 0.0, 1.25 if player.moving else 0.7, "SFX", 2.0)
	# ---- you: footsteps and paddle strokes ----
	if player.in_boat():
		if player.boat_kind() == "kayak" and player.moving:
			paddle_t -= dt
			if paddle_t <= 0: paddle_t = 0.62; Sound.play("paddle", -2.0, 0.1)
		else: paddle_t = 0.2
	elif player.moving:
		var ph := int(player.bob / PI)
		if ph != step_phase: step_phase = ph; Sound.play(_step_kind(p, rain), -1.0, 0.12)
	# ---- the fight: the drag and the line ----
	var reel := fishing.state == "reel"
	var ten: float = fishing.tension if reel else 0.0
	Sound.set_reeling(reel and fishing.holding and not menu_open.call(), 1.15 - clampf(ten, 0.0, 1.0) * 0.35)
	var drag := 0.0
	if reel: drag = clampf(absf(fishing.run) * (0.35 + fishing.fish.pull * 0.6) + maxf(0.0, ten - 0.62) * 2.0, 0.0, 1.0)
	Sound.set_loop("drag", "drag", drag * 0.9, 0.85 + ten * 0.3 + absf(fishing.run) * 0.1, "SFX", 6.0)
	Sound.set_loop("line", "line", smoothstep(0.5, 1.0, ten) * 0.9, 0.8 + ten * 0.45, "SFX", 4.0)
	Sound.duck = maxf(0.6 if reel else 0.0, roar * 0.8)
	prev_state = fishing.state
	# ---- guards: a shout when one has really seen you ----
	shout_cd -= dt
	if guards != null:
		if guards.detect > 0.3 and prev_detect <= 0.3 and shout_cd <= 0 and guards.detect_by != null:
			shout_cd = 5.0
			var w: Dictionary = guards.detect_by
			var near: float = clampf(-2.0 - w.pos.distance_to(p) * 0.4, -10.0, -2.0)
			match String(w.kind):
				"cam": Sound.play("cam_beep", near)
				"dog": Sound.play("bark", near, 0.1)
				_:
					var q := Sound.play(["shout_hey", "shout_heyyou", "shout_stop"].pick_random(), near, 0.0)
					# each guard keeps the same voice: a pitch from who they are
					if q != null: q.pitch_scale = 0.85 + float(hash(str(w.get("who", ""))) % 30) / 100.0
					Sound.play_later("whistle", 0.5, near - 3.0)
		prev_detect = guards.detect
	# ---- the ballpark: a hit and the crowd going up, now and then ----
	if Town.level == 1 and _game_on():
		bat_t -= dt
		if bat_t <= 0:
			bat_t = randf_range(18.0, 40.0)
			var d := _rect_dist(Rect2(74, 63, 20, 25), p)
			if d < 30: Sound.play("bat", clampf(-3.0 - d * 0.5, -18.0, -3.0), 0.05)

static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)

## What your feet sound like on what you're standing on. In the rain, hard ground splashes.
func _step_kind(p: Vector2, rain: float) -> String:
	var x := floori(p.x)
	var y := floori(p.y)
	if not Town.inb(x, y): return "step_hard"
	var T := Town.T
	if (Town.floodable[Town.idx(x, y)] and Game.flooded()) or Player.zone_of(p) == 4 and Town.level == 0: return "step_wet"
	var t := Town.t_at(x, y)
	if t == T.DOCK: return "step_wood"
	if t == T.SAND: return "step_sand"
	if t in [T.GRASS, T.FAIR, T.BUSH, T.HIDE, T.TREE, T.PATH]: return "step_wet" if rain > 0.6 and randf() < 0.3 else "step_grass"
	return "step_wet" if rain > 0.3 and randf() < 0.5 else "step_hard"

# ---------- test hooks ----------
## --sounddebug prints the loops that are playing once a second.
## --sounddemo=cast|fight|guard|bat runs a short scripted bit, for recording the sound preview with
## Godot's --write-movie (see tools/make_sound_preview.sh).
func run_test_hooks() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--sounddebug": Sound.log = true; _debug_loop()
		if a.begins_with("--sounddemo="): _demo(a.substr(12))
		if a.begins_with("--sounddir="): demo_dir = deg_to_rad(float(a.substr(11)))

func _debug_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		var on := []
		for k in Sound.loops:
			if Sound.loops[k].v > 0.01: on.append("%s %.2f" % [k, Sound.loops[k].v])
		print("LOOPS ", ", ".join(on), " | music ", Sound.track, " duck %.2f" % Sound.duck_now)

func _wait(s: float) -> void: await get_tree().create_timer(s).timeout

## A cast toward demo_dir, 3 tiles out; miss > 0 makes it a sloppy one.
var demo_dir := PI
func _demo_cast(miss: float) -> void:
	fishing.start_cast()
	fishing.aim = demo_dir; player.face = demo_dir; fishing.tgt = null
	fishing.power = (2.4 - Fishing.MINR) / (fishing.reach() - Fishing.MINR); fishing.green = fishing.power - miss
	fishing.release_cast()

func _demo(which: String) -> void:
	await _wait(0.6)
	match which:
		"cast":   # the same cast with four baits, from a worm to a popper, then a sloppy one and twitches
			for b in ["worms", "shrimp", "spoon", "popper"]:
				Game.S.bait = b
				_demo_cast(0.0); await _wait(1.3)
				if b == "popper":
					for d in [1, -1, 1]: fishing.twitch_side(d); await _wait(0.45)
				fishing.cancel(); await _wait(0.3)
			Game.S.bait = "spoon"; _demo_cast(0.3); await _wait(1.2)
		"fight":  # a big fish: the hookset, splashes, the drag and the line singing, then landing it
			var f: Dictionary = {}
			for x in Game.spots[fishing.spot].fish:
				if not x.get("junk", false) and not x.get("legend", false) and (f.is_empty() or float(x.pull) > float(f.pull)): f = x
			fishing.fish = f; fishing.fw = 24.0; fishing.state = "bite"; fishing.action_down()
			fishing.thrash_t = 0.8; fishing.run_t = 0.1
			for i in 140:
				fishing.holding = (i % 30) < 20
				fishing.thrash_t = 0.0 if i % 25 == 12 else maxf(fishing.thrash_t, 0.2)
				if i % 25 == 12: fishing.tension = minf(fishing.tension, 0.5)
				await _wait(0.05)
				fishing.tension = minf(fishing.tension, 0.9); fishing.ang = clampf(fishing.ang, -0.5, 0.5)
				fishing.progress = clampf(fishing.progress, 0.2, 0.8)
			fishing.progress = 1.0; fishing.holding = true; await _wait(2.5)
		"guard":  # whoever's nearest spots you
			var best = null
			for w in guards.watchers:
				if best == null or w.pos.distance_to(player.position) < best.pos.distance_to(player.position): best = w
			for i in 3:
				prev_detect = 0.0; shout_cd = 0.0; guards.detect_by = best; guards.detect = 0.35
				await _wait(2.2)
		"bat": bat_t = 0.5
