extends Node2D
## Builds the town (Port Mullet, or Ironwater or Gannet Harbor after the coach) and runs the game loop: walking, fishing, the clock, night lights, the shops and home.

const TS := Game.TS
const LOU_DOOR := Vector2(48.5, 32.4)
const HOME_DOOR := Vector2(8.75, 10.5)
const MARINA_DOOR := Vector2(88.5, 145.3)
const OLDTIMER := Vector2(37.4, 49.4)
const ROSA := Vector2(34.4, 165.6)
const STORY_LINES_OK := ["Lou whistles. The regulars nod.", "Somebody buys you a soda.", "Lou writes it on the whiteboard."]
const STORY_LINES_NO := ["Lou laughs so hard he has to sit down.", "A regular holds his hands two inches apart.", "\"Sure it was, buddy.\""]
## Lou's bait chart: shown the first time you walk into Lou's, and in the Gear tab.
const BAIT_TIP := "\"Worms catch a bit of everything. Bread for mullet, tilapia and koi. Hot dogs for catfish. Lures for bass. Live shrimp for snook, tarpon and redfish. Press B to switch.\""
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const SEE_THROUGH := preload("res://shaders/see_through.gdshader")

var world: Node2D
var ents: Node2D
var player: Player
var fishing: Fishing
var hud: Hud
var cam: Camera2D
var night: CanvasModulate
var lamp_lights: Array[PointLight2D] = []
var glow_layer: CanvasLayer
var glow_node: Drawer
var sky_nodes: Array = []
var save_t := 0.0
var near := ""
var latch := { "shop": false, "home": false, "marina": false, "fin": false, "drain": false, "boat": false, "gate": false }
var watch_zone := -1
var watch_seen := {}   # zone -> when its "who's watching" line last showed (seconds)
const DRAIN_GRATE := Vector2(46.5, 57.5)
# where the doors and the people you talk to are in this town (Ironwater moves them, see _place_town)
var lou_door := LOU_DOOR
var home_door := HOME_DOOR
var marina_door := MARINA_DOOR
var oldtimer_at := OLDTIMER
var rosa_at := ROSA
const COACH_FARE := 25
const COACH_SPECIES := 8   # kinds of fish to catch in Port Mullet before Lou sends you north
const COACH_SPECIES_GH := 6   # kinds of fish to catch in Ironwater before the coach to Gannet Harbor runs
## The coaches between the towns: [from, to] -> [fare, hours].
const COACHES := { "0-1": [25, 6], "1-0": [25, 6], "0-2": [45, 12], "2-0": [45, 12], "1-2": [30, 5], "2-1": [30, 5] }
const WALT := Vector2(46.9, 45.55)
const THEO := Vector2(88.7, 107.55)
var guards: Guards
var prev_zone := 0
var prev_pos := Vector2.ZERO
var last_sale := 0
var pending_catch = null
var shop_tab := "sell"
var home_tab := "rest"
var rod_pick := ["p_glass", "p_reel", ""]   # the blank, reel and grip picked at the workbench
var marina_tab := "boats"
var fin_tab := "aisles"
var buyer_tab := "sell"
var journal_tab := "spots"
var weather: Weather
var ground_tex: Texture2D
var ground_mat: ShaderMaterial
var water_fx: WaterFx
var traffic: Traffic
var harbor: Harbor
var town_life: TownLife
var soundscape: Soundscape
var base_zoom := 1.0
var zoom_k := 1.0        # extra zoom while a fish is on the line
var shake := 0.0         # seconds of screen shake left
var shake_px := 0.0
## Flagpoles outside City Hall, the marina, the golf club and Lou's, and the fountains in the plaza pool and Bayfront Park pond.
const FLAGS := [[Vector2(9.4, 146.7), "town"], [Vector2(85.0, 145.7), "marina"], [Vector2(65.0, 30.8), "golf"], [Vector2(52.6, 32.6), "shop"]]
const FOUNTAINS := [[Vector2(60.5, 130.7), 1.0], [Vector2(30.5, 127.6), 0.7]]
var glow_tex: GradientTexture2D
var open_lamps: Array = []    # street lamps whose glow isn't hidden behind a tower
var ach_t := 0.0
var menu: Menu
var saved_shown := -10.0
var title_t := 0.0
var music_t := 0.0
var prev_detect := 0.0
var alert_t := 0.0
# test hook: godot --path . -- --at=x,y,hour --shot=out.png [--open=shop]
var test_shot := ""
var test_frames := 0
const LABEL_SECS := 5.0
var label_seen := {}   # place-name label -> seconds it has been on screen
var test_knockout := false     # --knocked always knocks you out instead of rolling for a bump
var test_dir := Vector2.ZERO   # --walk=dx,dy holds that direction down, for checking what you bump into
var test_shot_frame := 90   # --shot-frame=N takes the shot later, e.g. to see a prompt fade out

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level=") and not Game.S.get("coach_in", false): Game.S.level = int(a.substr(8))
	Town.ensure(int(Game.S.level))
	_place_town()
	# the test hooks that put you somewhere or deep in the story skip Lou's sneaking lesson
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at=") or a.begins_with("--story=") or a.begins_with("--act2=") or a.begins_with("--boat="): Game.S.sneak_lesson = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at=") and not Game.S.get("coach_in", false):
			var v := a.substr(5).split(",")
			Game.S.x = float(v[0]); Game.S.y = float(v[1]); Game.S.min = float(v[2]) * 60.0; Game.S.started = true
		if a.begins_with("--shot="): test_shot = a.substr(7)
		if a.begins_with("--face="): Game.S.face = deg_to_rad(float(a.substr(7)))
		if a.begins_with("--shot-frame="): test_shot_frame = int(a.substr(13))
		if a.begins_with("--boat="): Game.S.boat = true; Game.S.boat_kind = a.substr(7); Game.S.gear.kayak = 1; Game.S.gear.skiff = 1
		if a == "--lesson": Game.S.sneak_lesson = false   # see Lou's sneaking lesson on the next guarded ground
		if a.begins_with("--day="): Game.S.day = int(a.substr(6)); Game.S.min += (Game.S.day - 1) * 1440.0
		if a.begins_with("--story="): Game.S.saga.ch = int(a.substr(8)) - 1; Game.S.saga.done = int(a.substr(8)) > 1; Game.S.day = maxi(int(Game.S.day), Story.NOTE_DAY)
		if a == "--gear=all":
			for g in Game.gear: Game.S.gear[g.id] = 1
			Game.S.cooler_cap = 30; Game.S.cash = 2000
		if a.begins_with("--gear=") and a != "--gear=all":
			for gid in a.substr(7).split("+"): Game.S.gear[gid] = 1
		if a == "--parts=all":
			for p in Crafting.PARTS: Game.S.parts[p] = 3 if p != "p_bigreel" else 0
		if a.begins_with("--lure="): Game.S.lures[a.substr(7)] = 3; Game.S.bait = a.substr(7)
		if a == "--cooler=junk": # a cooler of junk, for checking the pictures in the Sell tab
			for sid in Game.spots:
				for fd in Game.spots[sid].fish:
					if fd.get("junk", false) and Game.S.cooler.size() < 8 and not Game.S.cooler.any(func(c): return c.n == fd.n):
						Game.S.cooler.append({ "n": fd.n, "w": fd.w[0], "value": int(fd.get("flat", 1)), "spot": sid, "legend": false, "junk": true, "day": 1, "tm": 0 })
		if a == "--cooler=fresh": # today's catch from this town's spots: some on the menus and boards, some not, one from yesterday, and a junk
			var want := ["Mullet", "Mangrove Snapper", "Mahi-Mahi", "Snook", "Sheepshead", "Blue Crab", "Koi", "Kingfish"] if Game.S.level == 0 else ["Striped Bass", "Bluefish", "Atlantic Cod", "Spiny Dogfish", "Scup", "Koi", "Tautog", "Haddock"] if Game.S.level == 2 else ["Walleye", "Yellow Perch", "Black Crappie", "Common Carp", "Rainbow Trout", "Channel Catfish", "Sauger", "Bluegill"]
			for n in want:
				for sid in Game.spots:
					var fd = Game.spots[sid].fish.filter(func(f): return f.n == n)
					if fd.is_empty() or Game.S.cooler.any(func(c): return c.n == n): continue
					var w: float = snappedf(lerpf(fd[0].w[0], fd[0].w[1], 0.4), 0.1)
					var old: bool = Game.S.cooler.size() == 3
					Game.S.cooler.append({ "n": n, "w": w, "value": maxi(1, roundi(w * fd[0].pp)), "spot": sid, "legend": false, "junk": false, "day": int(Game.S.day) - (1 if old else 0), "tm": 0 })
			Game.S.cooler_cap = maxi(Game.S.cooler_cap, 12)
		if a == "--cooler=sample":
			for f in [[1, 2], [1, 4], [1, 5], [4, 1], [14, 4], [15, 0], [2, 7], [16, 7]]:
				var fd: Dictionary = Game.spots[f[0]].fish[f[1]]
				Game.S.cooler.append({ "n": fd.n, "w": fd.w[0], "value": 20 + f[1] * 7, "spot": f[0], "legend": fd.get("legend", false), "junk": fd.get("junk", false), "day": 1, "tm": 0 })
		if a.begins_with("--act2="): Game.S.saga.finished = true; Game.S.saga.ch = 7; Game.S.act2.ch = int(a.substr(7)) - 1; Game.S.act2.done = int(a.substr(7)) > 1; Game.S.day = maxi(int(Game.S.day), 9)
	Game.wx = Weather.compute(int(Game.S.day), Game.hour())
	RenderingServer.set_default_clear_color(Color("#0b1a3a"))
	Bridges.setup()
	world = Node2D.new()
	world.scale = Vector2(TS, TS)
	add_child(world)
	# ground
	var ground := Sprite2D.new()
	ground.texture = Ground.make_texture()
	ground_tex = ground.texture
	ground.centered = false
	ground.scale = Vector2.ONE / Ground.PX
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("water_mask", Ground.make_water_mask())
	mat.set_shader_parameter("materials", Ground.make_material_tex())
	mat.set_shader_parameter("coast", Ground.make_coast_tex())
	mat.set_shader_parameter("water_col", Ground.water_tex)
	mat.set_shader_parameter("map_size", Vector2(Town.MW, Town.MH))
	ground.material = mat
	ground_mat = mat
	ground.z_index = -10
	world.add_child(ground)
	for cy in ceili(Town.MH / 8.0):
		for cx in ceili(Town.MW / 8.0):
			var ch := GroundChunk.new(cx, cy)
			ch.z_index = -9
			world.add_child(ch)
	# bridges, driveways, parked cars and fences, in 16-tile blocks so only the blocks on screen get drawn
	for cy in range(0, Town.MH, 16):
		for cx in range(0, Town.MW, 16):
			var reg := Rect2(cx, cy, 16, 16)
			var statics := Drawer.make(func(ci): _draw_statics(ci, reg))
			statics.z_index = -8
			world.add_child(statics)
	# dark, shaded water under and beside the bridges, below the fish and boats
	var under_br := Drawer.make(func(ci): Bridges.draw_under(ci, _view_tiles().grow(2)), 0, true)
	under_br.z_index = -6
	world.add_child(under_br)
	var part_glints := Drawer.make(func(ci): Crafting.draw_spots(ci), 0.0, true)
	part_glints.z_index = -6
	world.add_child(part_glints)
	fishing = Fishing.new()
	fishing.z_index = -5
	world.add_child(fishing)
	var refl := WaterFx.new()
	refl.mode = "under"
	refl.z_index = -6
	world.add_child(refl)
	# everything that stands up is y-sorted
	ents = Node2D.new()
	ents.y_sort_enabled = true
	world.add_child(ents)
	for b in Town.buildings:
		if b.kind == "sky": b.wins = Art.sky_windows(b)
	var shadows := Drawer.make(func(ci):
		for b in Town.buildings:
			if b.kind == "sky": Art.sky_shadow(ci, b))
	shadows.z_index = -7
	world.add_child(shadows)
	for b in Town.buildings:
		var bb: Dictionary = b
		var n: Node2D
		match bb.kind:
			"sky": n = Drawer.make(func(ci): Art.sky(ci, bb), bb.y + bb.h - 0.05, true, Art.sky_bounds(bb).grow(8))
			"house": n = Drawer.make(func(ci): Art.house(ci, bb), bb.y + bb.h - 0.05)
			"tower": n = Drawer.make(func(ci): Art.cooling_tower(ci, bb, Time.get_ticks_msec() / 1000.0), bb.y + bb.h - 0.05, true, Rect2(bb.x, bb.y, bb.w, bb.h).grow(10))
			"volcano": n = Drawer.make(func(ci): Art.volcano(ci, bb, Time.get_ticks_msec() / 1000.0), bb.y + bb.h - 0.05, true, Rect2(bb.x, bb.y, bb.w, bb.h).grow(10))
			"shack", "fishmkt", "supper", "hall": n = Drawer.make(func(ci): BuyersArt.building(ci, bb, Time.get_ticks_msec() / 1000.0), bb.y + bb.h - 0.05, true, Rect2(bb.x, bb.y, bb.w, bb.h).grow(4))
			"containers": n = Drawer.make(func(ci): Gannet.draw_containers(ci, bb), bb.y + bb.h - 0.05)
			"ship": n = Drawer.make(func(ci): Gannet.draw_ship(ci, bb), bb.y + bb.h - 0.05)
			_: n = Drawer.make(func(ci): Art.flat(ci, bb), bb.y + bb.h - 0.05)
		ents.add_child(n)
		if bb.kind == "sky":
			sky_nodes.append([n, bb])
			n.get_child(0).light_mask = 2    # street lamps light the street, not the rooftops
			var hm := ShaderMaterial.new()
			hm.shader = SEE_THROUGH
			n.get_child(0).material = hm
			bb.see = 0.0
	for y in Town.MH:
		for x in Town.MW:
			var t: int = Town.tile[Town.idx(x, y)]
			var xx := x
			var yy := y
			if t == Town.T.TREE:
				var tn := Drawer.make(func(ci): Art.tree(ci, xx, yy, Time.get_ticks_msec() / 1000.0), y + 0.9, true, Rect2(x - 1.5, y - 1.5, 4, 4))
				(tn.get_child(0) as Drawer).sway = true
				ents.add_child(tn)
			elif t == Town.T.BUSH: ents.add_child(Drawer.make(func(ci): Art.bush(ci, xx, yy), y + 0.85))
	var anglers := [[Vector2(3.6, 18.4), 0.2], [Vector2(16.5, 22.6), 3.4], [Vector2(29.6, 162.5), PI], [Vector2(31.4, 160.2), 0.0], [Vector2(37.4, 49.4), -0.3]]
	if Town.level == 1: anglers = [[Vector2(47.4, 70.4), 0.0], [Vector2(64.6, 140.2), PI], [Vector2(50.5, 27.4), -PI / 2], [Vector2(21.5, 78.6), -1.2], [Vector2(66.4, 47.6), PI + 0.3]]
	# picnic tables by the fish shack, the price boards by the fish markets
	for bd in Buyers.here():
		for pr in BuyersArt.props(bd): ents.add_child(Drawer.make(pr[0], pr[1], false, pr[2]))
	if Town.level == 2: anglers = [[Vector2(64.1, 30.6), 0.0], [Vector2(64.1, 56.4), 0.0], [Vector2(80.4, 86.5), 0.2], [Vector2(64.1, 127.6), 0.0], [Vector2(63.2, 176.5), 0.3], [Vector2(84.5, 108.2), PI / 2]]
	for a in anglers:
		var p: Vector2 = a[0]
		var d: float = a[1]
		ents.add_child(Drawer.make(func(ci): Art.person(ci, p, d, Color("#f2b134"), Color("#c9a574"), true), p.y))
	if Town.level == 0:
		ents.add_child(Drawer.make(func(ci):
			if Game.hour() >= 7 and Game.hour() < 19: Art.person(ci, Vector2(50.6, 32.55), 0.4, Color("#13807b"), Color("#e2583e")), 32.55, true))
	elif Town.level == 1: _ironwater_props()
	else: _gannet_props()
	player = Player.new()
	ents.add_child(player)
	for k in ["kayak", "skiff"]: ents.add_child(ParkedBoat.new(k))
	fishing.player = player
	# bridge decks over the boats, fish and wake, so things on the water go under them
	var decks := Drawer.make(func(ci): Bridges.draw_decks(ci, _view_tiles().grow(2)), 0, true)
	decks.z_index = -4
	world.add_child(decks)
	if Town.level >= 1:
		# the high viaduct (or the suspension bridge) goes over everything under it, people and cars and trees included
		var high := Drawer.make(func(ci): Bridges.draw_high(ci, _view_tiles().grow(3 if Town.level == 1 else 16)), 0, true)
		high.z_index = 1
		world.add_child(high)
		var foam := Drawer.make(func(ci):
			if Town.level == 1: Ironwater.draw_water(ci, _view_tiles().grow(2), Time.get_ticks_msec() / 1000.0)
			else: Gannet.draw_water(ci, _view_tiles().grow(2), Time.get_ticks_msec() / 1000.0), 0, true)
		foam.z_index = -4
		world.add_child(foam)
	water_fx = WaterFx.new()
	water_fx.z_index = -4
	water_fx.player = player
	water_fx.fishing = fishing
	world.add_child(water_fx)
	refl.player = player
	refl.fishing = fishing
	if Town.level == 0:
		ents.add_child(Drawer.make(func(ci):
			ci.draw_rect(Rect2(ROSA.x + 0.25, ROSA.y - 0.05, 0.36, 0.3), Color("#e9e4d8"))
			Art.person(ci, ROSA, PI / 2 + 0.35, Color("#e2583e"), Color("#fbf3e2"), true)
			ci.draw_circle(ROSA + Vector2(-0.42, 0.1), 0.14, Color("#9aa6ad")), ROSA.y))
		ents.add_child(Drawer.make(func(ci): ci.draw_rect(Rect2(OLDTIMER.x - 0.5, OLDTIMER.y + 0.15, 0.3, 0.3), Color("#2c5f8a")), OLDTIMER.y + 0.01))
	elif Town.level == 2:
		# Theo, on his cooler at the end of the Narrows Park pier
		ents.add_child(Drawer.make(func(ci):
			ci.draw_rect(Rect2(THEO.x - 0.22, THEO.y - 0.02, 0.44, 0.34), Color("#2b7ea6"))
			ci.draw_rect(Rect2(THEO.x - 0.22, THEO.y - 0.02, 0.44, 0.08), Color("#f4f2ea"))
			Art.person(ci, THEO, 0.1, Color("#2f3a4a"), Color("#8a5a35"), true)
			ci.draw_rect(Rect2(THEO.x - 0.6, THEO.y + 0.05, 0.3, 0.26), Color("#e9e4d8")), THEO.y))
	else:
		# Walt, on his bucket at the end of the tailwater pier
		ents.add_child(Drawer.make(func(ci):
			ci.draw_rect(Rect2(WALT.x - 0.2, WALT.y - 0.02, 0.4, 0.34), Color("#c9603a"))
			Art.person(ci, WALT, -PI / 2 + 0.3, Color("#3d6e5a"), Color("#c9a574"), true)
			ci.draw_rect(Rect2(WALT.x + 0.35, WALT.y + 0.05, 0.3, 0.26), Color("#e9e4d8")), WALT.y))
	# boats tied up at the marina, which head out now and then
	harbor = Harbor.new()
	harbor.player = player
	add_child(harbor)
	harbor.setup(ents)
	harbor.hit_player.connect(_capsized)
	Obstacles.harbor = harbor
	for lp in Town.lamps:
		var t := Town.t_at(floori(lp.x), floori(lp.y))
		if Town.is_water_t(t) or t == Town.T.BLD: continue
		var lpp: Vector2 = lp
		ents.add_child(Drawer.make(func(ci): Art.lamp_post(ci, lpp), lp.y))
	for bs in Story.bus_list():
		var bp: Vector2 = bs[1]
		ents.add_child(Drawer.make(func(ci): draw_bus_stop(ci, bp), bp.y - 0.2))
	guards = Guards.new()
	guards.player = player
	guards.fishing = fishing
	guards.z_index = -4
	world.add_child(guards)
	guards.setup(ents)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--guards="): guards.walk_ahead(float(a.substr(9)))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hoa="): guards.hoa_t = float(a.substr(6))   # where the HOA resident's car is in its run
	traffic = Traffic.new()
	traffic.player = player
	add_child(traffic)
	traffic.setup(ents)
	traffic.hit_player.connect(_knocked_down)
	Obstacles.traffic = traffic
	soundscape = Soundscape.new()
	soundscape.player = player; soundscape.fishing = fishing; soundscape.traffic = traffic; soundscape.harbor = harbor; soundscape.guards = guards
	soundscape.menu_open = func() -> bool: return menu != null and menu.title_open
	add_child(soundscape)
	soundscape.setup()
	soundscape.run_test_hooks.call_deferred()
	town_life = TownLife.new()
	town_life.player = player
	add_child(town_life)
	town_life.setup(ents)
	var flags: Array = [FLAGS, [[Vector2(81.4, 105.7), "town"], [Vector2(36.6, 88.6), "shop"], [Vector2(84.5, 85.2), "golf"]],
		[[Vector2(36.6, 55.6), "town"], [Vector2(56.4, 70.6), "marina"], [Vector2(52.6, 51.6), "shop"], [Vector2(64.0, 102.0), "town"]]][Town.level]
	var fountains: Array = FOUNTAINS if Town.level == 0 else []
	for fl in flags:
		var fp: Vector2 = fl[0]
		var fs: String = fl[1]
		ents.add_child(Drawer.make(func(ci): TownLife.flag(ci, fp, fs, Time.get_ticks_msec() / 1000.0 + fp.x), fp.y, true, Rect2(fp - Vector2(1, 3.5), Vector2(4, 5))))
	for fo in fountains:
		var fop: Vector2 = fo[0]
		var fob: float = fo[1]
		ents.add_child(Drawer.make(func(ci): TownLife.fountain(ci, fop, Time.get_ticks_msec() / 1000.0 + fop.x, fob), fop.y + 0.1, true, Rect2(fop - Vector2(3, 3.5), Vector2(6, 5))))
	var overlay := Drawer.make(guards.draw_overlay, 0, true)
	overlay.z_index = 7
	world.add_child(overlay)
	var flood := Drawer.make(_draw_flood, 0, true)
	flood.z_index = -6
	world.add_child(flood)
	guards.busted.connect(_busted)
	Game.new_day.connect(_on_new_day)
	if Game.cur_order() == null: Game.new_order()
	elif Unlocks.early() and not Game.S.order.done and not Game.order_easy(Game.cur_order()): Game.new_order()
	var line := Drawer.make(fishing.draw_line_layer, 0, true)
	line.z_index = 5
	world.add_child(line)
	var wxd := Drawer.make(func(ci): Weather.ripples(ci, _view_tiles()), 0, true)
	wxd.z_index = 4
	world.add_child(wxd)
	var gulls := Drawer.make(_draw_gulls, 0, true)
	gulls.z_index = 6
	world.add_child(gulls)
	var labels := Drawer.make(_draw_labels, 0, true)
	labels.z_index = 6
	world.add_child(labels)
	# camera, night and lamps
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0; cam.limit_top = -int(TS * 2); cam.limit_right = int(Town.MW * TS); cam.limit_bottom = int(Town.MH * TS)
	add_child(cam)
	cam.position = player.position * TS
	cam.reset_smoothing()
	Art.view_x = player.position.x
	night = CanvasModulate.new()
	add_child(night)
	var tex := GradientTexture2D.new()
	tex.width = 128; tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 0.92, 0.75, 1)); gr.set_color(1, Color(1, 0.85, 0.6, 0))
	tex.gradient = gr
	for lp in Town.lamps:
		var l := PointLight2D.new()
		l.texture = tex
		l.position = lp * TS
		l.texture_scale = 3.4 * TS / 64.0
		l.energy = 0.0
		l.range_item_cull_mask = 1
		l.enabled = false
		add_child(l)
		lamp_lights.append(l)
	# lit windows sit on their own layer so the night tint doesn't dim them
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 1
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	var gw := Node2D.new(); gw.scale = Vector2(TS, TS); glow_layer.add_child(gw)
	var gholder := Drawer.make(_draw_night_glow, 0, true)
	gw.add_child(gholder)
	# soft light that blooms around lamps, lit windows and headlights, added on top
	var bloom := Drawer.make(_draw_bloom, 0, true)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bloom.get_child(0).material = add
	gw.add_child(bloom)
	glow_tex = GradientTexture2D.new()
	glow_tex.width = 64; glow_tex.height = 64
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5); glow_tex.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	glow_tex.gradient = gg
	weather = Weather.new()
	add_child(weather)
	hud = Hud.new()
	hud.fishing = fishing
	add_child(hud)
	Game.hint.connect(hud.flash)
	Game.toast.connect(hud.toast)
	hud.action_pressed.connect(_action_down)
	hud.action_released.connect(func(): fishing.action_up())
	hud.boat_pressed.connect(_toggle_boat)
	fishing.message.connect(hud.flash)
	fishing.landed.connect(_on_landed)
	get_viewport().size_changed.connect(_fit_zoom)
	_fit_zoom()
	menu = Menu.new()
	menu.hud = hud
	add_child(menu)
	menu.title_closed.connect(func(): if not Game.S.started: _intro())
	Game.saved.connect(func():
		var now := Time.get_ticks_msec() / 1000.0
		if now - saved_shown > 4.0 and Game.S.started and not menu.title_open: saved_shown = now; hud.show_saved())
	if test_shot == "" and not Game.skip_title:
		menu.show_title()
		menu.fade_in(1.0)
	else:
		if Game.skip_title: menu.fade_in(0.6)
		Game.skip_title = false
		if not Game.S.started: _intro()
	_coach_arrival()
	for a in OS.get_cmdline_user_args():
		if a == "--title": hud.close(); menu.show_title()
		if a == "--pause": menu.show_pause()
		if a == "--controls": menu.show_controls()
		if a == "--settings": menu.show_settings()
	for a in OS.get_cmdline_user_args():
		if a == "--open=shop": open_shop()
		if a == "--open=gear": shop_tab = "gear"; open_shop()
		if a == "--open=order": shop_tab = "order"; open_shop()
		if a == "--open=marina": open_marina()
		if a.begins_with("--open=buy:"): # --open=buy:<id>[:sell|menu|board|talk]
			var v := a.substr(11).split(":")
			buyer_tab = v[1] if v.size() > 1 else "sell"; open_buyer(v[0])
		if a.begins_with("--open=board:"): open_board(a.substr(13))
		if a == "--open=fin": fin_tab = "aisles"; open_fin()
		if a == "--open=fin-talk": fin_tab = "talk"; open_fin()
		if a == "--fin-sing": Fintastic.sing()
		if a == "--fin-closed": Game.S.act2.finished = true
		if a.begins_with("--fin-buy="): # --fin-buy=finclub+turbo+energy: buy these at FINTASTIC! with $2000 on you
			Game.S.cash = 2000
			for gid in a.substr(10).split("+"):
				var d := Fintastic.DAY_ITEMS.filter(func(x): return x[0] == gid)
				if d.is_empty(): _fin_buy(gid, Fintastic.price(int(Game.gear.filter(func(g): return g.id == gid)[0].price), gid))
				else: _fin_day(gid, Fintastic.price(int(d[0][3]), gid), d[0][4])
		if a == "--junk-gallery": # every junk picture on one screen: big ones as on the catch card, small as in the Sell tab
			var jl := CanvasLayer.new(); jl.layer = 20; add_child(jl)
			var jc := Control.new(); jc.set_anchors_preset(Control.PRESET_FULL_RECT); jl.add_child(jc)
			var jf := Story.all_fish().filter(func(f): return f.get("junk", false))
			jc.draw.connect(func():
				jc.draw_rect(Rect2(Vector2.ZERO, jc.size), Color("#eef4f2"))
				var cols := 6
				var cw := jc.size.x / cols
				var ch := jc.size.y / ceili(jf.size() / float(cols))
				for i in jf.size():
					var r := Rect2((i % cols) * cw, floorf(i / cols) * ch, cw, ch)
					JunkArt.draw(jc, jf[i].n, Rect2(r.position + Vector2(6, 4), Vector2(cw * 0.62, ch - 26)), 0.3)
					ItemIcons.draw_catch(jc, { "n": jf[i].n, "junk": true }, Rect2(r.position + Vector2(cw * 0.7, ch * 0.25), Vector2(48, 48)))
					jc.draw_string(Game.font_bold, r.position + Vector2(6, r.size.y - 5), jf[i].n, HORIZONTAL_ALIGNMENT_LEFT, cw - 8, 11, Color("#22313a")))
		if a == "--gallery": # every fish drawing on one screen, for checking FishArt
			var gl := CanvasLayer.new(); gl.layer = 20; add_child(gl)
			var gc := Control.new(); gc.set_anchors_preset(Control.PRESET_FULL_RECT); gl.add_child(gc)
			var fl := Story.all_fish().filter(func(f): return not f.get("junk", false))
			gc.draw.connect(func():
				gc.draw_rect(Rect2(Vector2.ZERO, gc.size), Color("#eef4f2"))
				var cols := 8
				var cw := gc.size.x / cols
				var ch := gc.size.y / ceili(fl.size() / float(cols))
				for i in fl.size():
					var r := Rect2((i % cols) * cw, floorf(i / cols) * ch, cw, ch)
					FishArt.draw(gc, fl[i].n, Rect2(r.position + Vector2(6, 4), r.size - Vector2(12, 22)), 0.5, fl[i].get("legend", false))
					gc.draw_string(Game.font_bold, r.position + Vector2(6, r.size.y - 5), fl[i].n, HORIZONTAL_ALIGNMENT_LEFT, cw - 8, 11, Color("#22313a")))
		if a.begins_with("--legends="): # land the first N legends, for checking the trophy wall
			var lg := Story.all_fish().filter(func(f): return f.get("legend", false)).slice(0, int(a.substr(10)))
			for f in lg: Game.S.journal[f.n] = { "w": float(f.w[1]) * 0.9, "spot": 1, "n": 1, "legend": true }
			for f in Story.all_fish().slice(0, 12):
				if not f.get("legend", false) and not f.get("junk", false): Game.S.journal[f.n] = { "w": float(f.w[0]), "spot": 1, "n": 1, "legend": false }
		if a.begins_with("--slam="):
			for pl in a.substr(7).split(","): Game.S.trophies.append({ "day": 7, "fmt": "big", "place": int(pl), "v": 10.0 })
		if a == "--open=home": home_tab = "rest"; open_home()
		if a.begins_with("--pet="): # --pet=kind,seconds: hold Chum's reaction there for a screenshot
			var pv := a.substr(6).split(","); HomeArt.pet_kind = int(pv[0]); HomeArt.test_since = float(pv[1]); HomeArt.pet_t = 0.0
		if a == "--open=bench": home_tab = "bench"; open_home()
		if a == "--open=rodbench": home_tab = "rod"; open_home()
		if a.begins_with("--homerod="): Game.S.homerod = Crafting.rod_stats(Array(a.substr(10).split(","))); Game.S.use_home = true
		if a == "--busted": _busted(guards.watchers[0])
		if a.begins_with("--walk="): var wv := a.substr(7).split(","); test_dir = Vector2(float(wv[0]), float(wv[1]))
		if a == "--knocked": test_knockout = true; _knocked_down(traffic.cars[0])
		if a == "--bumped": _knocked_down(traffic.cars[0])
		if a == "--capsize": _capsized(harbor.boats[0])
		if a.begins_with("--harbor=go"): harbor.test_go = true; harbor.test_route = int(a.substr(12)) if a.length() > 12 else -1
		if a.begins_with("--harbor=hold,"): # a boat under way at player + (dx, dy), heading at you, horn going
			var hv := a.substr(14).split(",")
			var hb: Harbor.Boat = harbor.boats[0]
			hb.state = "out"; hb.centre = player.position + Vector2(float(hv[0]), float(hv[1]))
			hb.heading = (player.position - hb.centre).angle(); hb.speed = Harbor.CRUISE; hb.horn_fx = 99.0
			harbor.test_hold = true
			for i in 14: WaterFx.trail.append({ "p": hb.centre - Vector2.from_angle(hb.heading) * (Harbor.HL + i * 0.3) + Vector2(0, 0.1), "a": hb.heading, "t": i * 0.15, "kind": "skiff" })
		if a.begins_with("--traffic=hold,"): # a car at player + (dx, 0) in your lane, coming at you, horn going
			var tv := float(a.substr(15))
			var tc: Traffic.Car = traffic.cars[0]
			tc.position = player.position + Vector2(tv, 0); tc.d = Vector2i(-int(signf(tv)), 0); tc.ang = Vector2(tc.d).angle()
			tc.fade = 1.0; tc.horn_fx = 99.0; tc.speed = 0.0
			traffic.test_hold = true
		if a == "--harbor=back": # a boat on its way back in, out in the bay
			var hb: Harbor.Boat = harbor.boats[0]
			hb.set_meta("out_route", harbor._route_out(hb)); hb.state = "away"; hb.away_t = 0.0
		if a == "--rosa": talk_rosa()
		if a == "--open=marina-slam": marina_tab = "slam"; open_marina()
		if a == "--open=note": shop_tab = "note"; open_shop()
		if a == "--open=journal": open_journal()
		if a == "--open=fame": journal_tab = "fame"; open_journal()
		if a == "--open=news": journal_tab = "news"; open_journal()
		if a == "--beach": _toggle_boat()
		if a.begins_with("--parked="): # --parked=kind,x,y: that boat was left beached at (x, y), for checking delivery
			var pv := a.substr(9).split(","); Game.S.gear[pv[0]] = 1
			Player.parked()[pv[0]] = [float(pv[1]), float(pv[2]), 0.0, float(pv[1]), float(pv[2])]
		if a == "--open=map": open_map()
		if a == "--open=icons": # every item picture, big, for checking the art
			var ids := ["p_spoon", "p_caps", "p_beads", "p_feather", "p_wire", "p_glow", "p_glass", "p_graphite", "p_reel", "p_bigreel", "p_cork", "p_foam", "p_tape", "spoon", "popper", "jig", "glowlure", "rod0", "rod1", "rod2", "rod3", "rod4", "worms", "bait", "lure", "hotdog", "bread", "squid", "cooler", "mcooler", "camera", "polo", "lanyard", "flashlight", "waders", "geiger", "prybar", "kayak", "bigtank", "suit", "skiff", "shades", "turbo", "harness", "megacooler", "finclub", "energy", "magnet", "sigrod", "junk"]
			var sheet := Control.new(); sheet.custom_minimum_size = Vector2(1180, 600)
			sheet.draw.connect(func():
				for i in ids.size():
					var r := Rect2(Vector2((i % 12) * 98 + 4, (i / 12) * 104 + 4), Vector2(88, 88))
					sheet.draw_rect(r, Color("#fff8ea"))
					ItemIcons.draw(sheet, ids[i], r.grow(-8))
					sheet.draw_string(Game.font_bold, r.position + Vector2(2, 100), ids[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#22313a")))
			hud.open([["node", sheet]], true)
		if a == "--open=bus": open_bus(0)
		if a.begins_with("--open=catches="): # every fish and bit of junk in town N, drawn as on the catch card, for checking the art
			var lv := int(a.substr(15))
			var names := []
			for sid in Game.spots:
				if Town.spot_town(int(sid)) != lv: continue
				for fd in Game.spots[sid].fish:
					if not names.any(func(x): return x[0] == fd.n): names.append([fd.n, fd.get("junk", false), fd.get("legend", false)])
			var sheet := Control.new(); sheet.custom_minimum_size = Vector2(1180, ceili(names.size() / 8.0) * 92)
			sheet.draw.connect(func():
				for i in names.size():
					var r := Rect2(Vector2((i % 8) * 147 + 2, (i / 8) * 92 + 2), Vector2(141, 70))
					sheet.draw_rect(r, Color("#fbf6e6") if names[i][2] else Color("#eef4f2"))
					if names[i][1]: JunkArt.draw(sheet, names[i][0], r.grow(-8))
					else: FishArt.draw(sheet, names[i][0], r.grow(-6), 0.0, names[i][2])
					sheet.draw_string(Game.font_bold, r.position + Vector2(2, 84), names[i][0], HORIZONTAL_ALIGNMENT_LEFT, 141, 11, Color("#22313a")))
			hud.open([["node", sheet]], true)
		if a.begins_with("--coach="): # ride the coach to town N (the scene reloads there; then this does nothing)
			var to := int(a.substr(8))
			if int(Game.S.level) != to: Game.S.cash = maxi(int(Game.S.cash), int(COACHES.get("%d-%d" % [Town.level, to], [COACH_FARE])[0])); _take_coach(to)
		if a == "--fresh-iw": Game.S.iw_seen = false
		if a == "--fresh-gh": Game.S.gh_seen = false
		if a == "--weigh":
			Story.sign_up()
			Game.S.cooler.append({ "n": "Snook", "w": 31.4, "value": 90, "spot": 14, "legend": false, "junk": false, "day": Game.S.day, "tm": Game.S.min + 5 })
			_slam_weigh()
		if a == "--toast": Game.add_news("Local Angler Buys Garage-Sale Rod, Announces 'Big Plans'")
		if a == "--cast": fishing.start_cast()
		if a.begins_with("--mark="): var mv := a.substr(7).split(","); fishing.set_mark(player.position + Vector2(float(mv[0]), float(mv[1])))
		if a.begins_with("--bait="): Game.S.bait = a.substr(7)
		if a.begins_with("--bob="): # a line already out at player + (dx, dy), in "wait" or another state
			var v := a.substr(6).split(",")
			fishing.bob = player.position + Vector2(float(v[0]), float(v[1])); fishing.spot = fishing.region_at(fishing.bob)
			fishing.state = v[2] if v.size() > 2 else "wait"; fishing.quiet = true
			player.face = (fishing.bob - player.position).angle()
		if a == "--bench": bench_f = 0
		if a.begins_with("--gfx="): menu.settings.gfx = int(a.substr(6)); menu.apply_settings(false)
		if a == "--hooked": # a fish on the line, being reeled in (use after --bob)
			fishing.fish = Game.spots[fishing.spot].fish[0]; fishing.fw = 3.0; fishing.state = "bite"
			fishing.action_down(); fishing.action_up(); fishing.progress = 0.5
		if a.begins_with("--twitch="): fishing.twitch_side(int(a.substr(9)))
		if a == "--land": fishing.fish = Game.spots[1].fish[5]; fishing.fw = 44.2; fishing.spot = 1; fishing._land()
		if a.begins_with("--land-junk="): # land the junk with this name, to see its catch card
			for sid in Game.spots:
				for f in Game.spots[sid].fish:
					if f.n == a.substr(12): fishing.fish = f; fishing.fw = 1.0; fishing.spot = sid; fishing._land(); break

func _fit_zoom() -> void:
	var vs := get_viewport_rect().size
	base_zoom = clampf(minf(vs.x, vs.y) / (15.0 * TS), 1.0, 2.2)
	cam.zoom = Vector2(base_zoom, base_zoom) * zoom_k

## Follow the player. While a fish is on, ease in closer and lean toward the bobber;
## a big catch gives the screen a short shake.
func _camera(dt: float) -> void:
	var hooked := fishing.state == "bite" or fishing.state == "reel"
	zoom_k = lerpf(zoom_k, 1.3 if hooked else 1.0, 1.0 - exp(-dt * (3.0 if hooked else 2.0)))
	cam.zoom = Vector2(base_zoom, base_zoom) * zoom_k
	var focus := player.position
	if hooked and fishing.bob != null and (fishing.bob as Vector2).distance_to(player.position) < 14.0:
		var bp: Vector2 = fishing.bob
		focus = player.position.lerp(bp, 0.3 * clampf((zoom_k - 1.0) / 0.3, 0.0, 1.0))
	cam.position = focus * TS
	shake = maxf(shake - dt, 0.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_px * (shake / 0.5) if shake > 0 else Vector2.ZERO

# ---------- loop ----------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	Drawer.view = _view_tiles()
	if menu.title_open:
		# the town drifts by behind the title screen
		title_t += dt
		cam.position = Vector2(56 + 30 * sin(title_t * 0.035 + 1.2), 82 + 58 * sin(title_t * 0.021 + 1.25)) * TS
		_lighting()
		_audio(dt)
		Obstacles.player_busy = true
		hud.chips = []
		hud.refresh("")
		hud.action.visible = false; hud.hint.visible = false; hud.bar.visible = false
		_test_shot()
		return
	hud.bar.visible = true
	Obstacles.player_busy = hud.is_open() or fishing.state != "idle"
	_audio(dt)
	if not hud.is_open():
		Game.advance(dt)
		var dir := Vector2.ZERO
		if fishing.state == "idle":
			if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): dir.x -= 1
			if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): dir.x += 1
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): dir.y -= 1
			if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): dir.y += 1
			if test_dir != Vector2.ZERO: dir = test_dir
		player.step(dt if fishing.state == "idle" else 0.0, dir)
		var l := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		var r := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		fishing.turn = int(r) - int(l)
		var u := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
		var dn := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
		fishing.steer = Vector2(int(r) - int(l), int(dn) - int(u)) if fishing.state == "power" else Vector2.ZERO
		fishing.pull = int(r) - int(l)
		fishing.update(dt)
		guards.update(dt)
		if guards.plane_hint: guards.plane_hint = false; hud.flash("A jet roars overhead. Nobody's looking!")
		_doors()
		_park(dt)
		ach_t += dt
		if ach_t > 1:
			ach_t = 0
			for a in Story.check_ach(): Game.toast.emit("%s: %s +$50, +3 rep" % [a[1], a[2]], "LOU'S WALL OF FAME")
		if Town.level == 0 and player.position.y > 115 and not Game.S.visited.has("dt"): Game.S.visited.dt = 1; hud.flash("Downtown Port Mullet. The bay is at the bottom of the street.")
		if Town.level == 0: _drain_hint(); _gate_hint()
		_watch_hint()
		_boat_hint()
	near = ""
	if fishing.state == "idle":
		if player.in_boat(): near = "fish"
		elif player.position.distance_to(lou_door) < 1.3: near = "shop"
		elif player.position.distance_to(home_door) < 1.0: near = "home"
		elif player.position.distance_to(marina_door) < 1.3: near = "marina"
		elif Town.level == 0 and player.position.distance_to(Fintastic.DOOR) < 1.3: near = "fin"
		elif _buyer_near() != "": near = _buyer_near()
		elif player.position.distance_to(oldtimer_at) < 1.8: near = "oldtimer"
		elif player.position.distance_to(rosa_at) < 1.6: near = "rosa"
		elif Crafting.near(player.position) >= 0: near = "part"
		elif Story.bus_near(player.position) >= 0: near = "bus"
		elif fishing.manhole_near() >= 0: near = "manhole"
		elif fishing.near_water(): near = "fish"
	hud.boat_text = ""
	if fishing.state == "idle":
		if player.in_boat(): hud.boat_text = ("Tie up the skiff (K)" if player.boat_kind() == "skiff" else "Beach the kayak (K)") if player.beach_spot() != null else ""
		else:
			var ls = player.launch_spot()
			if ls != null: hud.boat_text = "Launch the skiff (K)" if ls[1] == "skiff" else "Launch kayak (K)"
			else:
				var fs = player.fetch_spot()
				if fs != null: hud.boat_text = "Have the %s brought here, %s (K)" % [fs[1], Game.money(fs[2])]
	hud.chips = _chips()
	_camera(dt)
	_lighting()
	Art.view_x = cam.get_screen_center_position().x / TS
	# walk behind a tower and a window opens in it around you, so you can see where you are
	for pair in sky_nodes:
		var b: Dictionary = pair[1]
		var behind: bool = Art.sky_bounds(b).grow(0.4).has_point(player.position) and player.position.y < b.y + b.h - 0.2
		b.see = move_toward(b.see, 1.0 if behind else 0.0, dt * 4)
		var m: ShaderMaterial = pair[0].get_child(0).material
		m.set_shader_parameter("strength", b.see)
		m.set_shader_parameter("hole", player.position + Vector2(0, -0.3))
		b.hole = player.position + Vector2(0, -0.3)
	_bridges(dt)
	hud.refresh(near)
	if _test_shot(): return
	save_t += dt
	if save_t > 10: save_t = 0; Game.save_game()

# ---------- music and ambience ----------
## Which tune fits: sneaking music on private ground, the reactor hum at the power station,
## swamp blues at dawn and dusk and in Sunsplash Jungle, Miami synths at night, yacht rock downtown by day.
func _want_music() -> String:
	if Sound.style != "auto": return Sound.style
	if menu.title_open: return "miami" if Game.darkness() > 0.3 else "surf"
	var z := Player.zone_of(player.position)
	if Town.level == 2:
		if z >= 30: return "prowl"
		if Game.darkness() > 0.3: return "miami"
		if Game.time_band() == "low": return "swamp"
		return "yacht" if player.position.x > 58 else "steel"
	if Town.level == 1:
		if z >= 20: return "prowl"
		if Game.wx.get("storm", false): return "swamp"
		if Game.darkness() > 0.3: return "miami"
		return "swamp" if Game.time_band() == "low" or player.position.y < 56 else "steel"
	if z == 3: return "reactor"
	if z in [1, 2, 5, 6, 7, 8, 9]: return "prowl"
	if z == 4: return "swamp"
	if Game.wx.get("storm", false): return "swamp"
	if player.position.y > 115: return "miami" if Game.darkness() > 0.3 else "yacht"
	if Game.darkness() > 0.3: return "miami"
	if Game.time_band() == "low": return "swamp"
	return "steel" if Game.hour() >= 14 and Game.hour() < 18 else "surf"

func _audio(dt: float) -> void:
	music_t -= dt
	if music_t <= 0:
		music_t = 0.5
		Sound.set_music(_want_music())
	Sound.set_ambience(clampf(Game.darkness() / 0.62, 0, 1), Game.wx.rain)
	alert_t -= dt
	if guards.detect > 0.05 and prev_detect <= 0.05 and alert_t <= 0: Sound.play("alert"); alert_t = 3.0
	prev_detect = guards.detect

## Test hook: save a screenshot after 90 frames and quit. True while a test shot is pending.
## Test hook --bench: time 60 frames after a warm-up, print the average and quit.
var bench_f := -1
var bench_t0 := 0
var bench_proc := 0.0
func _bench() -> void:
	if bench_f < 0: return
	bench_f += 1
	if bench_f == 60: bench_t0 = Time.get_ticks_usec(); bench_proc = 0.0
	elif bench_f > 60: bench_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	if bench_f == 120:
		var ms := (Time.get_ticks_usec() - bench_t0) / 60000.0
		print("BENCH frame %.2f ms, process %.2f ms, objects %d, draw calls %d" % [ms, bench_proc / 60.0 * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()

func _test_shot() -> bool:
	_bench()
	if test_shot == "": return false
	test_frames += 1
	if test_frames == test_shot_frame:
		if "--fishcount" in OS.get_cmdline_user_args():
			# test hook: how many fish shadows each spot in this town has, to check fish spawn everywhere
			var n := {}
			for s in fishing.shadows: n[s.reg] = int(n.get(s.reg, 0)) + 1
			for reg in fishing.regtiles: print("FISH spot %d (%s): %d shadows of %d" % [reg, Game.spots.get(reg, {}).get("name", "?"), int(n.get(reg, 0)), int(Fishing.SHCOUNT.get(reg, 0))])
		get_viewport().get_texture().get_image().save_png(test_shot)
		get_tree().quit()
	return true

## Walk up to the storm drain grate and it tells you what's stopping you: the gear you're missing.
## Walking into a guarded place: Lou's sneaking lesson the first time, then a line about who's watching and when.
func _watch_hint() -> void:
	var z := Player.zone_of(player.position)
	if z == watch_zone: return
	watch_zone = z
	var note := Unlocks.watch_note(z)
	if note == "": return
	if z in Unlocks.GUARDED_ZONES and not Game.S.get("sneak_lesson", false) and fishing.state == "idle" and not hud.is_open():
		Game.S.sneak_lesson = true; Game.save_game()
		hud.open(Unlocks.sneak_lesson(z, hud.close)); return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(watch_seen.get(z, -999.0)) < 90.0: return
	watch_seen[z] = now
	hud.flash(note); hud.hint_t = 7.0

## Paddling up to water your boat can't take: the kayak at the open ocean, the skiff at the warm outflow.
func _boat_hint() -> void:
	if not player.in_boat(): latch.boat = false; return
	var kind := player.boat_kind()
	var ahead := player.position + Vector2.from_angle(player.face) * 0.9
	var t := Town.t_at(floori(ahead.x), floori(ahead.y))
	var why := ""
	if t == Town.T.DEEP and kind != "skiff": why = "Past the channel markers it's open ocean, too rough for a kayak. You need a skiff. " + ("Pier 6 Bait & Tackle sells one." if Town.level == 2 else "The marina downtown sells one.")
	elif t == Town.T.WARM and kind == "skiff": why = "The outflow channel is too tight and shallow for the skiff. Bring the kayak."
	elif Town.level == 1 and Town.is_water_t(t) and Player.zone_of(ahead) == 20: why = "That's the boil under the dam gates. It would flip you in a second. Fish it from the wing walls, if the ranger isn't looking."
	if why == "": latch.boat = false; return
	var now := Time.get_ticks_msec() / 1000.0
	if latch.boat or not player.moving or now - float(watch_seen.get("boat", -999.0)) < 30.0: return
	latch.boat = true; watch_seen["boat"] = now
	hud.flash(why); hud.hint_t = 5.0

## Walking up to a gate that's shut (Heron Lakes, or Sunsplash Jungle Park after hours): say why, and how to get in.
func _gate_hint() -> void:
	if player.in_boat(): latch.gate = false; return
	var why := ""
	for g in [Guards.HOA_GATE, Guards.PARK_GATE]:
		var c := Vector2(g.x + 0.5, g.y - 0.5)
		if player.position.distance_to(c) > 1.3 or player.position.y > g.y: continue
		if player.walkable(g.x, g.y) or not player.moving or sin(player.face) < 0.3: continue
		if g == Guards.HOA_GATE: why = "The Heron Lakes gate only opens for residents. Wait for a resident's car to pull up and slip in right behind it, or paddle up the back channel."
		else: why = "Sunsplash Jungle Park is closed. The gate opens at 9 AM and shuts at 6 PM."
	if why == "": latch.gate = false; return
	if latch.gate: return
	latch.gate = true
	hud.flash(why); hud.hint_t = 6.0

func _drain_hint() -> void:
	var d := player.position.distance_to(DRAIN_GRATE)
	if d > 2.4: latch.drain = false
	if d > 1.4 or latch.drain or player.in_boat() or player.position.y > DRAIN_GRATE.y: return
	var why := Player.drain_block()
	if why == "": return
	latch.drain = true
	hud.flash(why); hud.hint_t = 6.0

func _doors() -> void:
	if player.in_boat(): return
	for k in (["shop", "home", "marina", "fin"] if Town.level == 0 else ["shop", "home", "marina"]):
		var door: Vector2 = { "shop": lou_door, "home": home_door, "marina": marina_door, "fin": Fintastic.DOOR }[k]
		var d := player.position.distance_to(door)
		if d < 0.7 and not latch[k] and fishing.state == "idle":
			latch[k] = true; player.path.clear()
			if k == "shop": Sound.play("bell"); open_shop()
			elif k == "home": Sound.play("door"); open_home()
			elif k == "fin": Sound.play("door"); open_fin()
			else: open_marina()
		if d > 1.6: latch[k] = false
	for bd in Buyers.here():
		var key := "buy:" + String(bd.id)
		var d := player.position.distance_to(Buyers.door(bd))
		if d < 0.7 and not latch.get(key, false) and fishing.state == "idle":
			latch[key] = true; player.path.clear(); Sound.play("door"); buyer_tab = "sell"; open_buyer(bd.id)
		if d > 1.6: latch[key] = false

## The restaurant or market door, or a market's price board, you're standing at: "buy:<id>", "board:<id>" or "".
func _buyer_near() -> String:
	for bd in Buyers.here():
		if player.position.distance_to(Buyers.door(bd)) < 1.3: return "buy:" + String(bd.id)
		if player.position.distance_to(Buyers.board_at(bd)) < 1.2: return "board:" + String(bd.id)
	return ""

func _lighting() -> void:
	var dk := Game.darkness()
	var h := Game.hour()
	var c := day_tint(h)
	# clouds wash the warm colors out toward grey
	c = c.lerp(Color(0.86, 0.88, 0.92) * c.v, Game.wx.cloud * 0.35 * (1.0 - dk / 0.62))
	night.color = c
	ground_mat.set_shader_parameter("sun", clampf(1.0 - dk / 0.5, 0.0, 1.0) * (1.0 - Game.wx.cloud * 0.55))
	ground_mat.set_shader_parameter("sky_col", sky_tint(h))
	ground_mat.set_shader_parameter("rain", Game.wx.rain)
	ground_mat.set_shader_parameter("quality", Game.quality)
	ground_mat.set_shader_parameter("wetness", Weather.wetness(int(Game.S.day), h) if Game.quality > 0 else 0.0)
	ground_mat.set_shader_parameter("mist", Weather.mist(int(Game.S.day), h) if Game.quality > 0 else 0.0)
	var on := dk > 0.15
	var view := Rect2(cam.get_screen_center_position() - get_viewport_rect().size / cam.zoom / 2, get_viewport_rect().size / cam.zoom).grow(6 * TS)
	for l in lamp_lights:
		l.enabled = on and view.has_point(l.position)
		l.energy = dk * 1.6

## The color of the light over the day: cool blue nights, a pink dawn, white noon, a golden
## late afternoon, an orange and pink sunset and a purple dusk.
const TINTS := [[0.0, Color(0.3, 0.35, 0.6)], [4.6, Color(0.3, 0.35, 0.61)], [5.6, Color(0.52, 0.45, 0.64)], [6.5, Color(1.0, 0.76, 0.7)],
	[7.6, Color(1.0, 0.92, 0.84)], [9.0, Color(1.0, 0.98, 0.95)], [12.0, Color(1, 1, 1)], [15.5, Color(1.0, 0.97, 0.9)], [17.0, Color(1.0, 0.88, 0.7)],
	[18.2, Color(1.0, 0.78, 0.6)], [19.0, Color(0.9, 0.63, 0.65)], [19.8, Color(0.55, 0.44, 0.66)], [20.7, Color(0.32, 0.36, 0.61)], [24.0, Color(0.3, 0.35, 0.6)]]
## The sky color the water reflects at that hour.
const SKIES := [[0.0, Color(0.1, 0.14, 0.3)], [5.6, Color(0.45, 0.4, 0.62)], [6.5, Color(1.0, 0.7, 0.62)], [8.0, Color(0.6, 0.78, 0.94)],
	[16.5, Color(0.62, 0.78, 0.92)], [18.2, Color(1.0, 0.66, 0.42)], [19.0, Color(0.95, 0.5, 0.6)], [19.8, Color(0.42, 0.34, 0.62)], [20.7, Color(0.1, 0.14, 0.3)], [24.0, Color(0.1, 0.14, 0.3)]]

static func _keyed(keys: Array, h: float) -> Color:
	for i in keys.size() - 1:
		if h < keys[i + 1][0]:
			var k: float = (h - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			return (keys[i][1] as Color).lerp(keys[i + 1][1], smoothstep(0.0, 1.0, k))
	return keys[-1][1]

static func day_tint(h: float) -> Color: return _keyed(TINTS, fposmod(h, 24.0))
static func sky_tint(h: float) -> Color: return _keyed(SKIES, fposmod(h, 24.0))

## Headlight beams and tail lights on the cars that are out.
func _draw_headlights(ci: CanvasItem, view: Rect2, a: float) -> void:
	# headlights on the security truck and the HOA resident's car
	var cars := []
	var hc = guards.hoa_car_pos()
	if hc != null: cars.append([hc[0], hc[1], 0.95])
	for w in guards.watchers:
		if w.kind == "truck" and guards.active(w): cars.append([w.pos, w.dir, 1.0])
	if traffic != null:
		for c in traffic.cars:
			if c.fade > 0.3: cars.append([c.position, c.ang, c.L * 0.5])
	for cr in cars:
		var cp: Vector2 = cr[0]
		if not view.has_point(cp): continue
		var fw := Vector2.from_angle(cr[1])
		var sd := Vector2(-fw.y, fw.x)
		var front: Vector2 = cp + fw * cr[2]
		var beam := PackedVector2Array([front + sd * 0.3, front - sd * 0.3, front + fw * 4.5 - sd * 1.6, front + fw * 4.5 + sd * 1.6])
		ci.draw_polygon(beam, PackedColorArray([Color(1, 0.95, 0.8, 0.32 * a), Color(1, 0.95, 0.8, 0.32 * a), Color(1, 0.95, 0.8, 0), Color(1, 0.95, 0.8, 0)]))
		for k in [-1, 1]: _glow(ci, front + sd * 0.3 * k, 0.35, Color(1, 0.97, 0.85, 0.7 * a))
		for k in [-1, 1]: _glow(ci, cp - fw * cr[2] + sd * 0.3 * k, 0.3, Color(1, 0.15, 0.1, 0.5 * a))

## Additive light: halos around lamps, lit windows and porch lights, and headlight beams.
func _draw_bloom(ci: CanvasItem) -> void:
	var dk := Game.darkness()
	if dk < 0.1: return
	var a := dk / 0.62
	var h := Game.hour()
	var view := _view_tiles().grow(3)
	var warm := Color(1.0, 0.72, 0.38)
	# a home-made glow lure on the line lights up the water around it
	if Game.S.bait == "glowlure" and fishing.bob != null and fishing.state in ["wait", "nibble", "bite"] and fishing.manhole < 0:
		var gp: Vector2 = fishing.bob + fishing.slide
		_glow(ci, gp, 0.9, Color(0.55, 1.0, 0.35, 0.45 * a * (0.8 + 0.2 * sin(Time.get_ticks_msec() / 400.0))))
		_glow(ci, gp, 0.3, Color(0.75, 1.0, 0.55, 0.5 * a))
	for lp in open_lamps:
		if not view.has_point(lp): continue
		var hd := Art.lamp_head(lp)
		_glow(ci, hd, 0.7, Color(warm, 0.5 * a))
		_glow(ci, lp + Vector2(0.2, 0.2), 2.6, Color(warm, 0.16 * a))
		# a wobbling streak of lamplight on water just below it
		for k in range(1, 4):
			var wp: Vector2 = lp + Vector2(0.34, k)
			if Town.is_water_t(Town.t_at(floori(wp.x), floori(wp.y))):
				var tt := Time.get_ticks_msec() / 1000.0
				for j in 4:
					var wob := sin(tt * 2.2 + j * 1.9 + lp.x) * 0.12
					ci.draw_rect(Rect2(wp.x - 0.18 + wob, wp.y - 0.4 + j * 0.25, 0.36 - j * 0.05, 0.07), Color(warm, 0.35 * a * (1.0 - j * 0.2) / k))
	_draw_headlights(ci, view, a)
	Bridges.draw_glow(ci, view, a, _glow)
	if Town.level == 2: _gannet_glow(ci, view, a)
	if Game.quality == 0: return   # low graphics: just the lamps and headlights
	# windows in houses and low buildings: lots lit in the evening, a few late at night
	var lit := 0.7 if (h >= 18 and h < 23) else 0.15 if (h >= 23 or h < 5) else 0.35
	for b in Town.buildings:
		if not view.intersects(Rect2(b.x - 1, b.y - 1, b.w + 2, b.h + 2)): continue
		var day := int(Game.S.day)
		if b.kind == "house":
			var wy: float = b.y + b.h - 0.62
			var i := 0
			for u in [0.48, 0.72]:
				if Town.hash2(int(b.x) * 3 + i, int(b.y) + day * 7) < lit:
					var r := Rect2(b.x + b.w * u, wy + 0.17, 0.4, 0.27)
					ci.draw_rect(r, Color(1.0, 0.8, 0.45, 0.55 * a))
					_glow(ci, r.get_center() + Vector2(0, 0.2), 0.9, Color(warm, 0.3 * a))
				i += 1
			if h >= 18 or h < 6: _glow(ci, Vector2(b.x + 1.06, wy + 0.2), 0.5, Color(1, 0.85, 0.55, 0.55 * a))
		elif b.kind in ["shop", "mega", "marina", "club", "office", "plant", "flat", "shack", "fishmkt", "supper", "hall"] and b.label != "PARKING":
			var open_k := 0.95 if b.kind in ["shop", "mega", "marina", "club"] and h >= 17 and h < 22 else 0.3
			if b.has("buyer"): open_k = 0.95 if Buyers.open_now(Buyers.by_id(b.buyer)) else 0.1
			var fy: float = b.y + b.h - 0.85
			var wx: float = b.x + 0.3
			var i := 0
			while wx < b.x + b.w - 0.5:
				if Town.hash2(int(b.x) + i * 5, int(b.y) * 3 + day) < open_k:
					var r := Rect2(wx, fy + 0.2, 0.55, 0.38)
					ci.draw_rect(r, Color(1.0, 0.86, 0.55, 0.5 * a))
					_glow(ci, r.get_center() + Vector2(0, 0.3), 1.0, Color(warm, 0.22 * a))
				wx += 0.9; i += 1
	# towers: a faint halo over each lit window
	var tl := 0.55 if (h >= 18 or h < 1) else 0.18 if h < 5 else 0.35
	for pair in sky_nodes:
		var b: Dictionary = pair[1]
		if not view.intersects(Art.sky_bounds(b)): continue
		var i := 0
		for r in b.wins:
			if Town.hash2(i, b.x * 7 + Game.S.day) < tl and b.see < 0.5: _glow(ci, r.get_center(), 0.45, Color(1, 0.75, 0.4, 0.22 * a))
			i += 1
	if Town.level == 0 and view.has_point(Vector2(51.4, 31.6)): _glow(ci, Vector2(51.4, 31.4), 1.4, Color(1, 0.3, 0.25, 0.4 * a))
	# the Tailrace's neon sign and the light from Bonita's serving window, while they're open
	for bd in Buyers.here():
		if not Buyers.open_now(bd): continue
		var r: Array = bd.bld
		var c := Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]))
		if not view.has_point(c): continue
		match String(bd.style):
			"supper":
				_glow(ci, c + Vector2(0, 0.95), 2.2, Color(1, 0.3, 0.25, 0.45 * a))
				_glow(ci, c + Vector2(0, 1.5), 1.0, Color(0.4, 0.9, 1.0, 0.4 * a))
			"shack": _glow(ci, Vector2(float(r[0]) + 1.7, float(r[1]) + float(r[3]) - 0.6), 1.6, Color(1, 0.8, 0.5, 0.45 * a))

func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, col)

# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F11:
		menu.toggle_fullscreen(); return
	if hud.is_open():
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE: hud.close()
		elif e is InputEventKey and e.pressed and is_instance_valid(map_view) and map_view.is_visible_in_tree():
			match e.physical_keycode:
				KEY_EQUAL, KEY_KP_ADD: map_view.zoom_by(1.5)
				KEY_MINUS, KEY_KP_SUBTRACT: map_view.zoom_by(1 / 1.5)
				KEY_M: hud.close()
		return
	if menu.title_open: return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		if fishing.state == "idle": menu.show_pause()
		else: fishing.cancel(); hud.flash("You reel in your line.")
		return
	if e is InputEventKey and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_SPACE or k == KEY_F or k == KEY_E:
			if e.pressed: _action_down()
			else: fishing.action_up()
		elif e.pressed and k == KEY_B: _cycle_bait()
		elif e.pressed and k == KEY_K: _toggle_boat()
		elif e.pressed and k == KEY_J and fishing.state == "idle": open_journal()
		elif e.pressed and k == KEY_M and fishing.state == "idle": open_map()
		elif e.pressed and fishing.state == "wait" and (k == KEY_LEFT or k == KEY_A): fishing.twitch_side(-1)
		elif e.pressed and fishing.state == "wait" and (k == KEY_RIGHT or k == KEY_D): fishing.twitch_side(1)
	elif e is InputEventMouseMotion and fishing.state == "power" and not hud.is_open():
		fishing.set_mark(get_global_mouse_position() / TS)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			fishing.action_up(); return
		var wp: Vector2 = get_global_mouse_position() / TS
		if fishing.state == "power" and fishing.is_water(wp) and wp.distance_to(player.position) <= fishing.reach() + 0.6:
			fishing.set_mark(wp)
			return
		if fishing.state != "idle": _action_down(); return
		if fishing.near_water() and fishing.is_water(wp) and wp.distance_to(player.position) <= fishing.reach() + 0.6:
			fishing.start_cast(wp); return
		player.walk_to(wp)

func _action_down() -> void:
	if hud.is_open(): return
	if fishing.state == "idle":
		if near == "shop": Sound.play("bell"); open_shop()
		elif near == "home": Sound.play("door"); open_home()
		elif near == "marina": Sound.play("door"); open_marina()
		elif near == "fin": Sound.play("door"); open_fin()
		elif near.begins_with("buy:"): Sound.play("door"); buyer_tab = "sell"; open_buyer(near.substr(4))
		elif near.begins_with("board:"): Sound.play("ui_click"); open_board(near.substr(6))
		elif near == "oldtimer": talk_oldtimer()
		elif near == "rosa": talk_rosa()
		elif near == "part":
			var pi := Crafting.near(player.position)
			if pi >= 0: Sound.play("ui_click"); hud.flash(Crafting.pick(pi))
		elif near == "bus": open_bus(Story.bus_near(player.position))
		elif near == "manhole": fishing.start_manhole(fishing.manhole_near())
		elif near == "fish": fishing.start_cast()
		return
	fishing.action_down()

func _toggle_boat() -> void:
	if fishing.state != "idle": return
	var m := player.toggle_boat()
	if m == "" and not player.in_boat() and player.fetch_spot() != null:
		m = player.fetch_boat()
		if player.in_boat(): Sound.play("ui_click")
	if m != "": hud.flash(m); Game.save_game()
	elif player.in_boat(): hud.flash("Get close to a bank to land.")
	elif Game.S.gear.has("kayak") or Game.S.gear.has("skiff"):
		var pk := Player.parked()
		var left: Array = []
		for k in ["kayak", "skiff"]:
			if Game.S.gear.has(k) and pk.has(k): left.append(k)
		var all_left := left.size() == int(Game.S.gear.has("kayak")) + int(Game.S.gear.has("skiff"))
		if all_left: hud.flash("Your %s is where you left it. It's marked on the map (M)." % " and ".join(left))
		else: hud.flash("Stand right at the edge of a canal, the river or the bay to launch.")
	else: hud.flash(["You don't have a boat. Lou sells kayaks; the marina downtown sells a skiff.", "You don't have a boat. Dot sells kayaks; skiffs are back at the marina in Port Mullet.", "You don't have a boat. Sal at Pier 6 sells kayaks and skiffs."][Town.level])

func _cycle_bait() -> void:
	var o := Game.owned_baits()
	if o.size() < 2: hud.flash("Only worms so far. %s sells shrimp, lures, hot dogs and bread%s." % [Buyers.baseline(), ", and squid" if Town.level == 2 else ""]); return
	var i := 0
	for j in o.size():
		if o[j].id == Game.S.bait: i = j
	Game.S.bait = o[(i + 1) % o.size()].id
	hud.flash("Bait: " + Game.bait_name())

# ---------- cards ----------
func _intro() -> void:
	hud.open([["h3", "Port Mullet, Florida · pop. 8,214"], ["h2", "You've got a garage-sale rod, $30, and no shame."],
		["p", "Every pond, canal and storm drain in this town has fish in it. Half of them say NO FISHING. Figure out how to get in, catch something, get out, and sell it to Lou."],
		["sub", "Walk with WASD or the arrow keys, or click where you want to go. Stand by water and press F or Space to cast: release in the green, hook it when the bobber dips, then hold to reel and keep the needle in the green. Press B to switch bait. Lou's Bait & Tackle is the red roof just north of the main road."],
		["row", [["Go fishing", func(): Game.S.started = true; Game.save_game(); hud.close(); Game.add_news("Local Angler Buys Garage-Sale Rod, Announces 'Big Plans'"), true, "hot"]]]])

func _on_landed(c: Dictionary) -> void:
	pending_catch = c
	# a big one shakes the screen; a legend shakes it harder
	if not c.junk and (c.legend or c.record or float(c.w) >= 12.0):
		shake = 0.5; shake_px = 14.0 if c.legend else 8.0
	Story.on_catch(c)
	var worn := Crafting.wear(c)
	if int(c.spot) == 15 and Game.rod_level() < 4 and c.pull > 0.75 and not Game.S.get("big_rod_hint", false):
		Game.S.big_rod_hint = true; Game.hint.emit("That nearly pulled your arms off. The marina sells a big-game rod.")
	var spot_name: String = Game.spots[c.spot].name
	var full: bool = Game.S.cooler.size() >= Game.S.cooler_cap
	var parts := [["h3", spot_name], ["h2", c.n + ("  ★ LEGEND" if c.legend else "") + ("  · new record" if c.record and not c.junk else "")], ["node", FishArt.card(c)],
		["kv", [["Weight", "%s lb" % str(c.w)], ["Value" if c.release else "Lou pays", "Priceless" if c.release else Game.money(c.value)], ["Your best", "%s lb" % str(Game.S.journal[c.n].w)]]]]
	if c.note != "": parts.append(["sub", c.note])
	if worn != "": parts.append(["sub", worn])
	if c.release:
		parts.append(["p", "You can't sell this. Let it go and the story is worth +%d rep." % c.rep])
		parts.append(["row", [["Let it go", _release, true, "hot"]]])
	else:
		parts.append(["row", [["Cooler's full" if full else "Into the cooler", _keep, not full, "hot"], ["Release it (+1 rep)", _release]]])
	hud.open(parts)
	Game.save_game()

func _keep() -> void:
	var c: Dictionary = pending_catch
	Game.S.cooler.append({ "n": c.n, "w": c.w, "value": c.value, "spot": c.spot, "legend": c.legend, "junk": c.junk, "day": c.day, "tm": c.tm })
	pending_catch = null; hud.close(); Game.save_game()

func _release() -> void:
	var c: Dictionary = pending_catch
	Game.S.rep += c.rep if c.release else 1
	if c.legend and c.release: Game.add_news(("Angler Wrestles, Releases '%s'; Storm Drain Residents Grateful" if int(c.spot) == 5 else "Angler Releases '%s' After Epic Fight; Witnesses 'Still Shaking'") % c.n)
	pending_catch = null; hud.close(); Game.save_game()

## Opens a card, turning a story card's ["into", tab] into the "Into the shop" button.
func open_card(parts: Array) -> void:
	var out := []
	for p in parts:
		if p[0] == "into":
			var tab: String = p[1]
			out.append(["row", [["Into the shop", func(): shop_tab = tab; open_shop(), true, "hot"]]])
		else: out.append(p)
	hud.open(out)

func open_shop() -> void:
	if Town.level == 1: open_outfitter(); return
	if Town.level == 2: open_pier6(); return
	var S := Game.S
	var sc := Story.scene()
	if not sc.is_empty(): open_card(sc); return
	if not S.get("bait_tip", false):
		# the first time in, Lou tells you which bait catches what
		S.bait_tip = true; Game.save_game()
		hud.open([["h3", "Lou's Bait & Tackle · since 1977"], ["h2", "\"First time? Listen up.\""],
			["p", "Lou taps the bait chart behind the counter. \"Every fish wants something different. Put the wrong thing on and you'll sit there all day.\""],
			["quote", BAIT_TIP],
			["sub", "You start with worms. Lou sells the rest in the Gear tab, and the bait chart is up there too."],
			["row", [["Into the shop", func(): open_shop(), true, "hot"]]]])
		return
	var tabs := []
	var story_on: bool = int(S.saga.ch) > 0
	if shop_tab == "note" and not story_on: shop_tab = "sell"
	for td in [["sell", "Sell"], ["order", "Today's order"], ["gear", "Gear"], ["story", "Tell a story"]] + ([["note", "Lou's note"]] if story_on else []):
		var key: String = td[0]
		tabs.append([td[1], func(): shop_tab = key; open_shop(), shop_tab == key])
	var parts := [["h3", "Lou's Bait & Tackle · since 1977"], ["h2", "\"%s\"" % ["What'd you catch?", "Wipe your feet.", "Back again?", "Don't touch the shrimp.", "Tell me it's a big one."].pick_random()], ["tabs", tabs]]
	match shop_tab:
		"sell":
			_sell_parts(parts, "Lou")
			parts.append(["sub", "Lou pays the same every day. Bonita's Fish Shack on Mullet Beach pays more for fish caught today, if they're on her menu, and the Seaside Fish Market on Bayshore Dr pays by the pound at prices that change every morning."])
			if Story.species_got() < Unlocks.SPECIES_EARLY:
				var tips := Unlocks.lou_tips(3)
				if not tips.is_empty():
					parts.append(["p", "Lou: \"Still learning? Here's what's biting on the public water. No gear, no guards.\""])
					for tp in tips: parts.append(["sub", tp])
		"order":
			var o = Game.cur_order()
			if o == null: parts.append(["sub", "No order today."])
			elif S.order.done: parts.append(["sub", "You filled today's order. Lou: \"Same time tomorrow.\""])
			else:
				var have := Game.order_matches().size()
				parts.append(["quote", "\"%s\"" % o.t])
				parts.append(["p", "Pays %s and +3 rep, today only. You have %d of %d in your cooler." % [Game.money(o.pay), mini(have, int(o.count)), int(o.count)]])
				var tip := Unlocks.order_tip(o)
				if tip != "" and o.match.get("spot", 0) != 8: parts.append(["sub", "Lou's tip: " + tip])
				parts.append(["row", [["Hand it over" if have >= o.count else "Not enough yet", _fill_order, have >= o.count, "go"]]])
		"gear":
			parts.append(_kit_part())
			parts.append(["sub", "Lou's bait chart: " + BAIT_TIP.trim_prefix("\"").trim_suffix("\"")])
			_gear_list(parts, Game.gear.filter(func(g): return not g.has("where")))
			parts.append(["sub", "Your rod: %s." % Game.rod().name + (" Boats, squid and big-game tackle are at the marina downtown." if S.visited.has("dt") else "")])
		"note":
			parts += Story.note_parts(func(n): Story.pay(n); open_shop())
		"story":
			var s: Dictionary = S.story
			if s.is_empty() or int(S.story_day) != int(S.day): parts.append(["sub", "Sell a fish today and Lou will want to hear how you caught it."])
			elif S.story_told: parts.append(["sub", "You already told Lou about the %s today. Come back tomorrow with a new one." % s.n])
			else:
				var w: float = s.w
				parts.append(["p", "Lou leans on the counter. \"So. That %s. How big was it really?\"" % s.n])
				parts.append(["sub", "It weighed %s lb.%s" % [str(w), " You have a photo, which helps." if S.gear.has("camera") else " No photo. Stretch it too far and the regulars will laugh you out."]])
				parts.append(["item", "Tell it straight", "Always believed. Small rep.", "\"%s lb\"" % str(w), func(): _tell_story(0), true])
				parts.append(["item", "Round it up", ("Usually believed" if S.gear.has("camera") else "Coin flip") + ". Double rep, or lose some.", "\"%d lb\"" % roundi(w * 1.6), func(): _tell_story(1), true])
				parts.append(["item", "Full Florida", ("Even with a photo it's a stretch" if S.gear.has("camera") else "Long shot") + ". Big rep if they buy it.", "\"%d lb\"" % roundi(w * 4), func(): _tell_story(2), true])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

## The Sell tab: everything in your cooler and the button to sell it all. who is buying (Lou, or Dot in Ironwater).
func _sell_parts(parts: Array, who: String) -> void:
	var S := Game.S
	if S.cooler.is_empty():
		parts.append(["sub", ("Sold for %s. " % Game.money(last_sale) if last_sale else "") + "Your cooler is empty. %s buys anything with fins, and some things without." % who + ""])
	else:
		var total := 0
		for c in S.cooler:
			total += int(c.value)
			var cc: Dictionary = c
			if c.junk:
				parts.append(["item", c.n, "%s lb · %s · %s pays %s, or strip it for %s" % [str(c.w), Game.spots[int(c.spot)].name, who, Game.money(c.value), Crafting.PARTS[Crafting.salvage_part(c.n)].to_lower()],
					"Strip for parts", func(): hud.flash(Crafting.salvage(cc)); open_shop(), true, func(ci, r): ItemIcons.draw_catch(ci, cc, r)])
			else:
				parts.append(["item", c.n + (" ★" if c.legend else ""), "%s lb · %s" % [str(c.w), Game.spots[int(c.spot)].name], Game.money(c.value), func(): pass, false,
					func(ci, r): ItemIcons.draw_catch(ci, cc, r)])
		parts.append(["row", [["Sell everything for " + Game.money(total), _sell_all, true, "go"]]])
	last_sale = 0

func _gear_list(parts: Array, list: Array) -> void:
	var S := Game.S
	var cmax := Game.cooler_max()
	for g in list:
		var gid: String = g.id
		var owned: bool = S.cooler_cap >= cmax if gid == "cooler" else S.gear.has(gid)
		var locked: bool = g.get("req") != null and not S.gear.has(g.get("req"))
		var price: int = g.price
		var btn := "Owned" if owned else "Needs a better rod" if locked else Game.money(price)
		parts.append(["item", g.n + (" (%d now)" % S.cooler_cap if gid == "cooler" else ""), g.ds, btn, func(): _buy(gid, price, g.has("where")), not owned and not locked and S.cash >= price,
			func(ci, r): ItemIcons.draw(ci, gid, r), locked])

## The strip of pictures at the top of the gear lists: your rod, your bait and everything you own.
func _kit_part() -> Array:
	var S := Game.S
	var rd := Game.rod()
	var kit := [[func(ci, r): _rod_icon(ci, r), rd.name]]
	for b in Game.owned_baits():
		var bid: String = b.id
		kit.append([func(ci, r): ItemIcons.draw(ci, bid, r), b.n])
	for g in Game.gear:
		var gid: String = g.id
		if gid.begins_with("rod") or Game.baits.any(func(b): return b.get("gear", "") == gid): continue
		if gid == "cooler" or not S.gear.has(gid): continue
		kit.append([func(ci, r): ItemIcons.draw(ci, gid, r), g.n])
	if S.cooler_cap > 5 and not S.gear.has("mcooler"): kit.append([func(ci, r): ItemIcons.draw(ci, "cooler", r), "Cooler (%d)" % S.cooler_cap])
	return ["kit", "Your kit", kit]

## The picture of the rod in your hands.
func _rod_icon(ci: CanvasItem, r: Rect2) -> void:
	if Game.using_home_rod(): ItemIcons.draw_homerod(ci, Game.S.homerod, r)
	else: ItemIcons.draw(ci, "rod%d" % Game.shop_rod_level(), r, Time.get_ticks_msec() / 1000.0)

func _sell_all() -> void:
	var total := 0
	for c in Game.S.cooler: total += int(c.value)
	Game.S.cash += total
	if total > 0: Sound.play("cash")
	_note_story(Game.S.cooler)
	Game.S.cooler = []
	last_sale = total
	Game.save_game()
	open_shop()

## The best fish you sold today is the one Lou wants to hear about in "Tell a story", wherever you sold it.
func _note_story(sold: Array) -> void:
	var best = null
	for c in sold:
		if not c.junk and (best == null or c.value > best.value or (c.legend and not best.legend)): best = c
	if best != null and (Game.S.story.is_empty() or int(Game.S.story_day) != int(Game.S.day) or best.value > Game.S.story.value):
		Game.S.story = best; Game.S.story_day = Game.S.day; Game.S.story_told = false

func _fill_order() -> void:
	var o = Game.cur_order()
	if o == null or Game.S.order.done: return
	var m := Game.order_matches()
	m.sort_custom(func(a, b): return a.value < b.value)
	if m.size() < o.count: return
	for c in m.slice(0, int(o.count)): Game.S.cooler.erase(c)
	Sound.play("cash")
	Game.S.cash += int(o.pay); Game.S.rep += 3; Game.S.order.done = true; Game.S.stats.orders += 1
	if randf() < 0.3: Game.add_news(["Bait Shop Owner 'Satisfied for Once,' Customers Report", "Lou's Bait & Tackle Fills Mysterious Order; Questions Remain"].pick_random())
	Game.save_game(); open_shop()
	hud.flash("Lou pays %s. \"Same time tomorrow.\"" % Game.money(o.pay))

func _tell_story(lv: int) -> void:
	var S := Game.S
	var s: Dictionary = S.story
	var photo: bool = S.gear.has("camera")
	var base: int = maxi(1, roundi(s.value / 12.0)) + (5 if s.legend else 0)
	var odds: float = [1.0, 0.85 if photo else 0.5, 0.45 if photo else 0.18][lv]
	var ok := randf() < odds
	var claim: Variant = [s.w, roundi(s.w * 1.6), roundi(s.w * 4)][lv]
	var gain: int = base * [1, 2, 5][lv] if ok else -base * [0, 1, 2][lv]
	S.rep = maxi(0, S.rep + gain); S.story_told = true
	if ok and lv == 2: S.stats.full_fl += 1; Game.add_news("Bait Shop Regulars Confirm %s-lb %s 'Totally Real'" % [str(claim), s.n])
	Game.save_game()
	hud.open([["h3", "Fish story"], ["h2", "\"It was %s pounds.\"" % str(claim)], ["quote", (STORY_LINES_OK if ok else STORY_LINES_NO).pick_random()],
		["p", ("They bought it. +%d rep." % gain) if ok else ("Nobody bought it. %d rep." % gain) if gain else "Nobody's impressed, but nobody can argue."],
		["row", [["Back outside", func(): hud.close(), true, "hot"]]]])

func _buy(gid: String, price: int, at_marina := false) -> void:
	if Game.S.cash < price: return
	Game.S.cash -= price
	if gid == "cooler": Game.S.cooler_cap = mini(Game.cooler_max(), Game.S.cooler_cap + 5)
	elif gid in ["mcooler", "megacooler"]: Game.S.gear[gid] = 1; Game.S.cooler_cap += 10
	else: Game.S.gear[gid] = 1
	for b in Game.baits:
		if b.get("gear", "") == gid: Game.S.bait = b.id
	if gid == "skiff": Game.add_news("Local Angler Buys Used Skiff; Lou Names It After a Coffee Can")
	Story.check()
	Game.save_game()
	if at_marina: open_marina()
	else: open_shop()

func open_marina() -> void:
	var S := Game.S
	var parts := [["h3", "Mullet Bay Marina · fuel, ice, squid"], ["h2", "\"%s\"" % ["Mind the dock lines.", "No running on the docks.", "Here for the Slam?", "You smell like Lou's."].pick_random()],
		["pic", StoryArt.marina, 120]]
	var tabs := []
	for td in [["boats", "Boats & gear"], ["slam", "Mullet Bay Slam"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): marina_tab = key; open_marina(), marina_tab == key])
	parts.append(["tabs", tabs])
	if marina_tab == "boats":
		parts.append(_kit_part())
		_gear_list(parts, Game.gear.filter(func(g): return g.get("where", "") == "marina"))
		parts.append(["sub", "The COFFEE CAN is tied up at the docks. Launch it from the bay or the river with K." if S.gear.has("skiff") else "Lou still buys the fish. We just sell the stuff to catch them."])
	else:
		parts += Story.slam_parts(_slam_sign, _slam_weigh)
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

## FINTASTIC! Outdoor Megastore: the aisles (Trent's flashy extras, nothing Lou sells) and Brayden at the register.
## After Act II the store is closed, and the card just shows it through the papered-over glass.
func open_fin() -> void:
	var S := Game.S
	var parts := [["h3", "FINTASTIC! Outdoor Megastore · downtown"]]
	if Fintastic.closed():
		parts += [["h2", "CLOSED FOR REBRANDING"], ["pic", FintasticArt.store, 330, true],
			["p", "The doors are chained. Through a gap in the paper over the glass you can see the cardboard Trent face down on the floor, and the robot fish on the counter, still singing to nobody."],
			["sub", "A note from Brayden is taped to the glass: \"Moved to the marina. They let me drive the forklift. Lou says hi. —B\""],
			["row", [["Back outside", func(): hud.close(), true, "hot"]]]]
		hud.open(parts, false, 820.0); return
	parts.append(["h2", "\"%s\"" % Fintastic.greeting()])
	parts.append(["pic", FintasticArt.store, 330, true])
	var tabs := []
	for td in [["aisles", "Aisles"], ["talk", "Talk to Brayden"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): fin_tab = key; open_fin(), fin_tab == key])
	parts.append(["tabs", tabs])
	if fin_tab == "aisles":
		parts.append(_kit_part())
		parts.append(["sub", "Forty aisles of camo, a wall of rods with Trent's face on them, and a robot fish that sings. None of it is Lou's stuff. It all goes on top." + (" Fin Club: 15% off." if Fintastic.club() else "")])
		for g in Fintastic.stock():
			var gid: String = g.id
			var p := Fintastic.price(int(g.price), gid)
			var owned: bool = S.gear.has(gid)
			parts.append(["item", g.n, g.ds, "Owned" if owned else Game.money(p), func(): _fin_buy(gid, p), not owned and S.cash >= p, func(ci, r): ItemIcons.draw(ci, gid, r, Time.get_ticks_msec() / 1000.0)])
		for d in Fintastic.DAY_ITEMS:
			var did: String = d[0]
			var dp := Fintastic.price(int(d[3]), did)
			var key: String = d[4]
			var on := int(S.get(key, 0)) == int(S.day)
			parts.append(["item", d[1] + (" · on today" if on else ""), d[2], ("Buzzing" if did == "energy" else "Sprayed") if on else Game.money(dp), func(): _fin_day(did, dp, key), not on and S.cash >= dp,
				func(ci, r): ItemIcons.draw(ci, did, r, Time.get_ticks_msec() / 1000.0)])
		parts.append(["item", "Trent Marlowe Signature Rod", "It's the bait-shop special from Lou's with a sticker on it. Glued to the wall.", "$999", func(): pass, false, func(ci, r): ItemIcons.draw(ci, "sigrod", r)])
		parts.append(["row", [["Press the robot fish's button", func():
			Fintastic.sing(); Sound.play("ui_click")
			hud.flash(["The robot fish sings the FINTASTIC! jingle. Brayden closes his eyes.", "\"Fin-fin-FINTASTIC!\" Brayden mouths every word without wanting to.", "The robot fish turns its head, sings, and turns back. A child somewhere cheers."].pick_random()), true]]])
	else:
		parts.append(["quote", "\"%s\"" % Fintastic.brayden_line()])
		parts.append(["sub", "Brayden, 17 · FINTASTIC! Team Member of the Month · \"Ask me about Fin Club\""])
		parts.append(["row", [["Ask him something else", func(): open_fin(), true, "go"]]])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts, false, 820.0)

func _fin_buy(gid: String, price: int) -> void:
	if Game.S.cash < price or Game.S.gear.has(gid): return
	Game.S.cash -= price
	Game.S.gear[gid] = 1
	if gid == "megacooler": Game.S.cooler_cap += 10
	Sound.play("cash")
	var news := { "turbo": "Local Angler Buys TurboReel 9000; Lou 'Not Mad, Just Disappointed'", "harness": "Angler Seen Wearing Full Fighting Harness at the Canal; Mullet Unimpressed",
		"megacooler": "MegaCooler Spotted Rolling Down Flamingo Ave, Owner Close Behind" }
	if news.has(gid): Game.add_news(news[gid])
	Story.check()
	Game.save_game()
	open_fin()
	hud.flash({ "turbo": "Brayden: \"FINTASTIC choice!\" He looks like it hurt to say.", "harness": "Brayden helps you buckle it. \"You look like Trent. Sorry. That's what they make me say.\"",
		"megacooler": "It holds 10 more fish. It also has four cupholders.", "finclub": "Brayden punches the air, very small. \"Fifteen percent off. For life.\"" }.get(gid, "Bought."))

func _fin_day(did: String, price: int, key: String) -> void:
	if Game.S.cash < price: return
	Game.S.cash -= price
	Game.S[key] = int(Game.S.day)
	Sound.play("cash")
	Game.save_game()
	open_fin()
	hud.flash("REEL DEAL ENERGY. You can hear colors. You walk faster for the rest of the day." if did == "energy" else "You spray yourself, your bait and some of Brayden. Fish come quicker for the rest of the day.")

## A restaurant or fish market (see buyers.gd): sell to the chef or the fishmonger, read today's
## menu or price board, and talk. Lou and Dot still buy everything at the same price every day.
func open_buyer(id: String) -> void:
	var bd := Buyers.by_id(id)
	if bd.is_empty(): return
	var S := Game.S
	var resto: bool = bd.kind == "restaurant"
	var is_open := Buyers.open_now(bd)
	var info_tab := "menu" if resto else "board"
	if not buyer_tab in ["sell", info_tab, "talk"]: buyer_tab = "sell"
	var parts := [["h3", "%s · %s" % [bd.name, ("open " if is_open else "closed · open ") + Buyers.hours_text(bd)]]]
	parts.append(["h2", "\"%s\"" % (Buyers.greeting(bd) if is_open else "Closed. Back at %s." % Buyers._clock(bd.hours[0]))])
	parts.append(["pic", func(ci): BuyersArt.inside(ci, bd), 300, true])
	var tabs := []
	for td in [["sell", "Sell"], [info_tab, "Today's menu" if resto else "Price board"], ["talk", "Talk to " + String(bd.who)]]:
		var key: String = td[0]
		tabs.append([td[1], func(): buyer_tab = key; open_buyer(id), buyer_tab == key])
	parts.append(["tabs", tabs])
	match buyer_tab:
		"sell":
			if not is_open:
				parts.append(["p", "%s is closed. It's open %s." % [bd.name, Buyers.hours_text(bd)]])
				parts.append(["sub", "%s buys everything, any time." % Buyers.baseline()])
			elif S.cooler.is_empty():
				parts.append(["sub", ("Sold for %s. " % Game.money(last_sale) if last_sale else "") + "Your cooler is empty. " + ("%s buys fish caught today, if they're on today's menu." % bd.who if resto else "%s buys any fish by the pound. Today's prices are on the board." % bd.who)])
			else:
				if resto:
					var left := Buyers.room(bd)
					parts.append(["sub", ("The kitchen is full for today. Come back tomorrow." if left == 0 else "%s takes %d more fish today, caught today and on the menu." % [bd.who, left]) + (" It's the Friday fish fry: everything on the menu pays %s×." % Buyers._x(float(bd.fry_fresh)) if Buyers.fry_day(bd) else "")])
				# what they'll buy first, best price first
				var rows: Array = S.cooler.map(func(c): return [c, Buyers.offer(bd, c)])
				rows.sort_custom(func(x, y): return int(x[1][0]) > int(y[1][0]))
				for row in rows:
					var c: Dictionary = row[0]
					var cc: Dictionary = c
					var o: Array = row[1]
					var pay: int = o[0]
					var ok: bool = pay > 0 and Buyers.room(bd) > 0
					var desc := "%s lb · %s pays %s · %s" % [str(c.w), Buyers.baseline(), Game.money(c.value), o[1]]
					parts.append(["item", c.n + (" ★" if c.legend else ""), desc, ("Sell for " + Game.money(pay)) if pay > 0 else "No thanks", func(): _buyer_sell(id, [cc]), ok,
						func(ci, r): ItemIcons.draw_catch(ci, cc, r), pay <= 0])
				var tk := Buyers.takes(bd)
				if not tk.is_empty():
					var tot := 0
					for x in tk: tot += int(x[1])
					var lou := 0
					for x in tk: lou += int(x[0].value)
					parts.append(["row", [["Sell all %d %s takes for %s (%s at %s's)" % [tk.size(), bd.who, Game.money(tot), Game.money(lou), Buyers.baseline()], func(): _buyer_sell(id, tk.map(func(x): return x[0])), true, "go"]]])
			last_sale = 0
		"menu":
			var fry := Buyers.fry_day(bd)
			parts.append(["sub", ("Friday fish fry! %d dishes tonight, and everything on the menu pays %s× what %s does." % [Buyers.menu(bd).size(), Buyers._x(float(bd.fry_fresh)), Buyers.baseline()]) if fry else
				"Today's menu. %s pays %s× what %s does for these, %s× for the catch of the day, and only if you caught it today." % [bd.who, Buyers._x(float(bd.fresh)), Buyers.baseline(), Buyers._x(float(bd.special))]])
			var sp := Buyers.special(bd)
			for n in Buyers.menu(bd):
				var nn: String = n
				var m := Buyers.pay_mult(bd, nn)
				var have: int = S.cooler.filter(func(c): return c.n == nn and int(c.day) == int(S.day)).size()
				parts.append(["item", String(bd.menu[nn]) + ("  · CATCH OF THE DAY" if nn == sp else ""), "%s · pays %s× · %s" % [nn, Buyers._x(m), ("%d in your cooler, caught today" % have) if have else "none in your cooler from today"],
					"%s×" % Buyers._x(m), func(): pass, false, func(ci, r): FishArt.draw(ci, nn, r.grow(-4), Time.get_ticks_msec() / 1000.0)])
			if bd.has("fry_day") and not fry: parts.append(["sub", "Fish fry is every Friday, the day before the Slam: %s." % ("tomorrow" if Buyers.days_to_fry(bd) == 1 else "in %d days" % Buyers.days_to_fry(bd))])
			parts.append(["sub", "The menu changes every day."])
		"board":
			_board_parts(parts, bd)
		"talk":
			parts.append(["quote", "\"%s\"" % Buyers.talk_line(bd)])
			parts.append(["sub", "%s, %s · %s" % [bd.who, String(bd.role).to_lower(), bd.blurb]])
			parts.append(["row", [["Ask something else", func(): open_buyer(id), true, "go"]]])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts, false, 760.0)

func _board_parts(parts: Array, bd: Dictionary) -> void:
	parts.append(["pic", func(ci): BuyersArt.board_pic(ci, bd), BuyersArt.board_height(bd)])
	var smoke := ""
	if bd.has("smoke"):
		var names := PackedStringArray()
		for n in bd.smoke: names.append(String(n).to_lower())
		smoke = " %s smokes %s, so they never go cheap." % [bd.who, ", ".join(names)]
	parts.append(["sub", "Prices a pound, new every morning. Fish that aren't on the board pay %s× what %s does, and yesterday's catch pays %s× the board.%s" % [Buyers._x(float(bd.offlist)), Buyers.baseline(), Buyers._x(float(bd.dayold)), smoke]])

## Reading a market's price board from the sidewalk.
func open_board(id: String) -> void:
	var bd := Buyers.by_id(id)
	if bd.is_empty(): return
	var parts := [["h3", "%s · %s" % [bd.name, ("open " if Buyers.open_now(bd) else "closed · open ") + Buyers.hours_text(bd)]], ["h2", "Today's prices"]]
	_board_parts(parts, bd)
	parts.append(["row", [["Go in", func(): buyer_tab = "sell"; open_buyer(id), true, "go"], ["Back", func(): hud.close(), true, "hot"]]])
	hud.open(parts, false, 760.0)

func _buyer_sell(id: String, cs: Array) -> void:
	var bd := Buyers.by_id(id)
	var sp := Buyers.special(bd) if bd.kind == "restaurant" else ""
	var got_sp := cs.any(func(c): return c.n == sp)
	var paid := Buyers.sell(bd, cs)
	if paid <= 0: return
	Sound.play("cash")
	_note_story(cs.filter(func(c): return not Game.S.cooler.has(c)))
	last_sale = paid
	if got_sp and randf() < 0.4: Game.add_news(["%s Sells Out by Seven; Chef Credits 'Some Kid With a Cooler'" % String(bd.menu[sp]), "Catch of the Day Actually Caught Today, %s Insists" % bd.name].pick_random())
	Game.save_game()
	open_buyer(id)
	hud.flash(("%s pays %s. " % [bd.who, Game.money(paid)]) + (["\"Now that's fresh.\"", "\"Tell your friends. Not too many.\"", "\"Back in the walk-in you go.\""] if bd.kind == "restaurant" else ["\"Pleasure doing business.\"", "\"On the ice, next.\"", "\"Check the board tomorrow.\""]).pick_random())

func talk_oldtimer() -> void:
	var avail := Game.tips.filter(func(tp): return Game.S.rep >= tp.rep)
	var fresh: bool = avail.size() > int(Game.S.tips_heard)
	var tip: Dictionary = avail[int(Game.S.tips_heard)] if fresh else avail.pick_random()
	if fresh: Game.S.tips_heard += 1
	var nxt = null
	for tp in Game.tips:
		if tp.rep > Game.S.rep and (nxt == null or tp.rep < nxt.rep): nxt = tp
	Game.save_game()
	hud.open([["h3", "The old-timer under the bridge"], ["h2", "\"C'mere. I'll tell you something.\"" if fresh else "\"Like I said…\""], ["quote", tip.t],
		["sub", ("He'll tell you more once you're better known around here (%d rep). Brag at Lou's to build a name." % nxt.rep) if nxt != null else "He's told you everything he knows. Probably."],
		["row", [["Thanks, old-timer", func(): hud.close(), true, "hot"]]]])

func talk_rosa() -> void:
	if Town.level == 1: talk_walt(); return
	if Town.level == 2: talk_theo(); return
	var tip: String = Game.tips2[int(Game.S.rosa) % Game.tips2.size()]
	var first: bool = int(Game.S.rosa) == 0
	Game.S.rosa += 1; Game.save_game()
	hud.open([["h3", "Rosa Delgado · end of the Municipal Pier"], ["h2", "\"Sit. You're scaring the snapper.\"" if first else "\"You again. Good.\""], ["quote", tip],
		["sub", "Rosa has fished this pier every day since 1979. She has something new each time you ask."],
		["row", [["Thanks, Rosa", func(): hud.close(), true, "hot"]]]])

func _busted(w: Dictionary) -> void:
	Sound.play("whistle", 0.0, 0.0)
	fishing.cancel(); player.path.clear()
	var z := int(w.zone)
	var off: Dictionary = Game.S.offenses
	off[str(z)] = int(off.get(str(z), 0)) + 1
	var n: int = off[str(z)]
	var fine := 10 + 10 * n
	var paid := mini(int(Game.S.cash), fine)
	Game.S.cash -= paid; Game.S.busts += 1
	Game.S.boat = false
	player.position = guards.exits.get(z, player.position)
	Game.save_game()
	var zn: String = guards.znames.get(z, "private property")
	hud.open([["h3", "Busted at " + zn], ["h2", w.who + " spotted you"], ["quote", w.caught],
		["p", ("You paid a %s fine" % Game.money(fine) if paid >= fine else "You paid what you had, %s, and got a stern look" % Game.money(paid) if paid > 0 else "You were broke, so they let you off with a warning") + " and got walked back out. Your cooler is safe."],
		["sub", "Offense #%d here. Fines go up each time. Try hiding in bushes, waiting for patrols to turn, or a disguise from %s's." % [n, Buyers.baseline()]],
		["row", [["Walk it off", func(): hud.close(), true, "hot"]]]])

const DRIVER_SHOUTS := ["\"Get out of the road!\"", "\"Sidewalk's right there, pal!\"", "\"You're gonna get yourself killed!\"", "\"Hey! I'm walkin' here! I mean, drivin'!\"", "\"Watch it, bait-for-brains!\""]

## A car you didn't get out of the way of. Most of the time it just bumps you back onto the sidewalk,
## with another honk and a shout from the driver. About 1 in 3 knocks you out: you come to on the
## sidewalk half an hour later with a small ER bill. Nobody's badly hurt and your cooler is safe.
func _knocked_down(car) -> void:
	if hud.is_open() or menu.title_open: return
	fishing.cancel(); player.path.clear()
	Game.S.boat = false
	var side := _sidewalk_near(player.position, car)
	if randf() >= 1.0 / 3.0 and not test_knockout:
		# a bump: shoved onto the sidewalk, no harm done
		Sound.play("thump", -6.0)
		Sound.play("horn", -2.0, 0.06)
		shake = 0.2; shake_px = 3.0
		player.position = side
		Game.S.bumps = int(Game.S.get("bumps", 0)) + 1
		hud.flash("The %s bumps you onto the sidewalk. %s" % [_car_colour(car.col) + (" pickup" if car.L > 2.0 else " car"), DRIVER_SHOUTS.pick_random()])
		return
	Sound.play("thump", 0.0, 0.0)
	shake = 0.4; shake_px = 6.0
	var bill := 10
	var paid := mini(int(Game.S.cash), bill)
	Game.S.cash -= paid
	Game.S.knockdowns = int(Game.S.get("knockdowns", 0)) + 1
	Game.skip_minutes(30)
	player.position = side
	Game.save_game()
	var what := "A " + _car_colour(car.col) + (" pickup" if car.L > 2.0 else " car")
	hud.open([["h3", "Knocked down in the street"], ["h2", what + " didn't stop"], ["quote", "\"I honked! You heard me honk!\""],
		["p", "You land on your backside and see stars. Half an hour later you come to on the sidewalk with a bruise the shape of a side mirror and a paramedic checking your eyes. " +
			("The bill for the ambulance visit was %s." % Game.money(bill) if paid >= bill else "The bill was %s; they took the %s you had." % [Game.money(bill), Game.money(paid)] if paid > 0 else "They let you off the bill.") + " Your cooler is safe."],
		["sub", "Cars honk when you're in their lane. Most just bump you out of the way, but some knock you flat, so when you hear a horn, step onto the sidewalk. Cars always wait while you have a line out."],
		["row", [["Ouch", func(): hud.close(), true, "hot"]]]])

## The nearest spot off the road you can stand on, away from the car that hit you.
func _sidewalk_near(p: Vector2, car) -> Vector2:
	var best := p
	var bd := INF
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if not player.walkable(x, y) or Town.t_at(x, y) == Town.T.ROAD or Town.is_water_t(Town.t_at(x, y)) or Town.in_bridge(x, y): continue
			var w := Vector2(x + 0.5, y + 0.5)
			var d := w.distance_to(p) + (0.5 if (w - car.position).dot(Vector2.from_angle(car.ang)) > 0.0 else 0.0)
			if d < bd and not player.collides(w) and player.sink(w, 0.0) == 0.0: bd = d; best = w
	return best

static func _car_colour(c: Color) -> String:
	if c.s < 0.2: return "white" if c.v > 0.8 else "silver" if c.v > 0.5 else "black"
	var h := c.h * 360.0
	return "red" if h < 20 or h >= 330 else "orange" if h < 45 else "yellow" if h < 70 else "green" if h < 160 else "teal" if h < 195 else "blue" if h < 260 else "purple"

## A marina boat rolled your kayak or skiff. You come up spluttering, swim it to the nearest bank and
## pull it out there. The last fish you caught slips out of the cooler, and drying off takes a while.
func _capsized(b) -> void:
	if hud.is_open() or menu.title_open or not player.in_boat(): return
	Sound.play("splash", 2.0, 0.0)
	fishing.cancel(); player.path.clear()
	shake = 0.35; shake_px = 5.0
	var kind := player.boat_kind()
	var start := player.position
	# the nearest water you could land this boat from
	var best := Vector2(-1, -1)
	var bd := INF
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var x := floori(start.x) + dx
			var y := floori(start.y) + dy
			if not Player.boatable(x, y, kind) or Town.in_bridge(x, y): continue
			var w := Vector2(x + 0.5, y + 0.5)
			var dd := w.distance_squared_to(start)
			if dd >= bd: continue
			player.position = w
			if player.beach_spot() != null: bd = dd; best = w
	player.position = best if best.x >= 0 else start
	if best.x >= 0: player.toggle_boat()
	var lost := ""
	for i in range(Game.S.cooler.size() - 1, -1, -1):
		var c: Dictionary = Game.S.cooler[i]
		if not c.get("legend", false):
			lost = c.n
			Game.S.cooler.remove_at(i)
			break
	Game.S.capsizes = int(Game.S.get("capsizes", 0)) + 1
	Game.skip_minutes(45)
	Game.save_game()
	var boat_name := "skiff" if kind == "skiff" else "kayak"
	hud.open([["h3", ["Capsized in Mullet Bay", "Capsized on the Calder River", "Capsized in Gannet Harbor"][Town.level]], ["h2", "The " + b.what + " didn't stop"], ["quote", "\"Didn't you hear the horn?\" somebody yells from the deck."],
		["p", "Your %s rolls over and you come up spluttering. You swim it to the nearest bank and drag it out, and it takes the best part of an hour to dry off. " % boat_name +
			("Your %s slipped out of the cooler and swam away." % lost if lost != "" else "Your cooler was empty, so nothing got away.")],
		["sub", "Boats leaving or coming back to the marina blow their horn when you're in their way. Paddle out of their path when you hear it. They wait for you while they ease in and out of their slips."],
		["row", [["Wring out your hat", func(): hud.close(), true, "hot"]]]])

func _on_new_day() -> void:
	Game.new_order()
	if Game.tide_day(): hud.flash("King tide today: Low Street floods from 10 AM to 2 PM.")
	for w in guards.watchers: w.alert = 0.0

## Sunsplash Jungle: $8 admission from 9 to 6, and staff sweep the park at closing. The restroom is a good place to wait.
func _park(_dt: float) -> void:
	var z := Player.zone_of(player.position)
	var h := Game.hour()
	if z == 5 and prev_zone != 5 and not player.in_boat() and h >= 9 and h < 18 and int(Game.S.park_day) != int(Game.S.day):
		if Game.S.cash >= 8: Game.S.cash -= 8; Game.S.park_day = Game.S.day; hud.flash("Paid $8 admission. The park closes at 6 PM.")
		else: player.position = prev_pos; player.path.clear(); hud.flash("Admission is $8. Come back with cash.")
	if h >= 18 and h < 18.4 and z == 5 and int(Game.S.swept_day) != int(Game.S.day):
		var on_hide := Town.t_at(floori(player.position.x), floori(player.position.y)) == Town.T.HIDE
		if on_hide: Game.S.swept_day = Game.S.day; hud.flash("Footsteps outside the restroom… then the lights go off.")
		else:
			Game.S.swept_day = Game.S.day; fishing.cancel(); Game.S.boat = false
			player.position = guards.exits[5]; player.path.clear()
			hud.open([["h3", "Sunsplash Jungle Park · 6:00 PM"], ["h2", "\"The park is now closed!\""], ["quote", "A cheerful teen in a safari hat walks you to the exit and wishes you a jungle-tastic evening."],
				["sub", "Staff sweep the whole park at closing. They don't check the restroom."], ["row", [["Rats", func(): hud.close(), true, "hot"]]]])
	prev_zone = Player.zone_of(player.position); prev_pos = player.position

func _chips() -> Array:
	var out := []
	var g := Story.goal_text()
	if g != "": out.append([g, "coral"])
	var o = Game.cur_order()
	if o != null and Town.level == 0:   # Lou's order can only be handed over at Lou's, back home
		out.append(["Lou's order: done ✓" if Game.S.order.done else "Lou wants: %s (%d/%d)" % [o.s, mini(Game.order_matches().size(), int(o.count)), int(o.count)], "paper"])
	if Town.level != 0: pass
	elif Game.tide_day():
		out.append(["King tide! Low Street is flooded" if Game.flooded() else "King tide today, 10 AM to 2 PM" if Game.hour() < 10 else "King tide is over for today", "sea"])
	else:
		var d := 3 - int(Game.S.day) % 4
		out.append(["Next king tide: " + ("in %d days" % (4 + d) if d <= 0 else "tomorrow" if d == 1 else "in %d days" % d), "sea"])
	out.append(["Weather: " + Weather.label(), "ink"])
	var tc := Story.tour_chip()
	if tc != "": out.append([tc, "paper"])
	var today := []
	if Fintastic.buzzing(): today.append("REEL DEAL buzz")
	if Fintastic.scented(): today.append("Fish Magnet")
	if not today.is_empty(): out.append(["Today: " + " + ".join(today), "ink"])
	return out

func _draw_flood(ci: CanvasItem) -> void:
	var fl := Game.flood_level()
	if fl <= 0: return
	ci.draw_rect(Rect2(0, 62, 37, 4), Color(0.29, 0.65, 0.77, 0.93 * clampf(fl * 1.4, 0, 1)))
	var t := Time.get_ticks_msec() / 1000.0
	for k in 30:
		var x := fmod(k * 7.3 + t * 0.4, 37.0)
		ci.draw_rect(Rect2(x, 62.3 + fmod(k * 1.37, 3.4), 0.5, 0.05), Color(1, 1, 1, 0.3 * fl))

func open_home() -> void:
	if Town.level != 0: open_motel(); return
	var rest := func(h: float):
		hud.close()
		menu.fade(func(): Game.skip_to(h); hud.flash("You rest until %s." % Game.clock_text()); Game.save_game(), 0.4, 0.7)
	var tabs := []
	for td in [["rest", "Rest"], ["bench", "Make lures"], ["rod", "Build a rod"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): home_tab = key; open_home(), home_tab == key])
	var parts := [["h3", "Home sweet home" if home_tab == "rest" else "The workbench"], ["h2", _home_line() if home_tab == "rest" else "\"Measure twice.\"" if home_tab == "rod" else "\"Mind the hooks.\""], ["tabs", tabs]]
	if home_tab == "rest":
		parts.append(["pic", HomeArt.room, 380, true])
		var m := HomeArt.mounts()
		if m.is_empty(): parts.append(["sub", "The wall above the couch is waiting for your first legend. Every one you land gets mounted here."])
		else: parts.append(["sub", "On the wall: " + ", ".join(m.slice(0, 6).map(func(x): return "%s (%s lb)" % [x.n, str(snappedf(x.w, 0.1))])) + (" and %d more" % (m.size() - 6) if m.size() > 6 else "") + "."])
		parts.append(["row", [["Pet Chum", func():
			Sound.play("ui_click")
			var k := HomeArt.pet()
			hud.flash([["Chum stretches, yawns, and goes right back to sleep.", "Chum does a big stretch. Every toe."], ["Chum rolls over. It's a trap.", "Chum shows you the belly. Don't fall for it."], ["Chum purrs like an outboard motor.", "Chum sniffs your hands. Bait. Approved."]][k].pick_random()), true]]])
		parts += [["p", "Kick back until…"],
			["item", "Dawn", "The Lunker of the 7th bites at dawn.", "Rest until 6:00 AM", func(): rest.call(6.0), true],
			["item", "Noon", "Business hours. Lanyard time at the koi pond.", "Rest until 12:00 PM", func(): rest.call(12.0), true],
			["item", "Dusk", "The golf groundskeeper knocks off at 7.", "Rest until 5:30 PM", func(): rest.call(17.5), true],
			["item", "Night", "Old Whiskers and the Bridge Troll come out.", "Rest until 9:00 PM", func(): rest.call(21.0), true]]
	elif home_tab == "rod":
		_parts_kit(parts)
		_rod_bench(parts)
	else:
		_parts_kit(parts)
		for l in Crafting.LURES:
			var lid: String = l.id
			var need := []
			for p in l.needs: need.append("%s %d/%d" % [Crafting.PARTS[p].to_lower(), mini(Crafting.count(p), int(l.needs[p])), int(l.needs[p])])
			var lft := Crafting.left(lid)
			var ln: String = l.n
			parts.append(["item", l.n + (" · %d catches left" % lft if lft > 0 else ""), l.ds + " Lasts %d catches. Needs %s." % [int(l.uses), ", ".join(need)], "Make it",
				func(): Crafting.make(lid); Sound.play("ui_click"); hud.flash("You made a %s. It's on your line now." % ln.to_lower()); open_home(),
				Crafting.can_make(l), func(ci, r): ItemIcons.draw(ci, lid, r), not Crafting.can_make(l)])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts, false, 820.0 if home_tab == "rest" else 0.0)

## The big line on the home card: something about the room as it is right now.
func _home_line() -> String:
	var S := Game.S
	var lines := ["The AC is on.", "It smells like bait in here.", "Home. Feet up.", "Chum is asleep on the couch again."]
	var m := HomeArt.mounts()
	if not m.is_empty(): lines += ["%s stares at you from the wall." % m[0].n, "%d legends on the wall." % m.size() if m.size() > 1 else "One legend on the wall. Room for more."]
	if S.gear.has("bigtank"): lines.append("The tank is bubbling away.")
	if Game.darkness() > 0.4: lines += ["The lamp's on. The street's quiet.", "Crickets outside."]
	if float(Game.wx.rain) > 0.3: lines.append("Rain on the window.")
	if S.trophies.any(func(x): return int(x.place) == 1): lines.append("The Slam cup catches the light.")
	if not S.homerod.is_empty(): lines.append("Your own rod is in the rack.")
	return lines.pick_random()

func _parts_kit(parts: Array) -> void:
	var have := []
	for p in Crafting.PARTS:
		var pid: String = p
		if Crafting.count(pid) > 0: have.append([func(ci, r): ItemIcons.draw(ci, pid, r), Crafting.PARTS[pid], str(Crafting.count(pid))])
	if have.is_empty(): parts.append(["sub", "No parts yet. Look for something shiny on the ground by the water around town, or strip the junk you catch at Lou's."])
	else: parts.append(["kit", "Your parts", have])

## The "Build a rod" tab: your home-built rod, then a blank, a reel and a grip to pick, then Build.
func _rod_bench(parts: Array) -> void:
	var S := Game.S
	if not S.homerod.is_empty():
		var hr: Dictionary = S.homerod
		var using := Game.using_home_rod()
		parts.append(["item", hr.name + (" · in your hands" if using else ""), Crafting.stat_text(hr), "Use the shop rod" if using else "Use it",
			func(): S.use_home = not using; Game.save_game(); hud.flash("You pick up your %s." % Game.rod().name.to_lower()); open_home(), true,
			func(ci, r): ItemIcons.draw_homerod(ci, hr, r)])
	else:
		parts.append(["sub", "Find a blank and a reel around town (the canals, the golf lake, the bay, the river) and build a rod of your own. A good one fishes like the rods Lou sells for hundreds."])
	var st := Crafting.rod_stats(rod_pick)
	var ok := Crafting.can_build(rod_pick)
	parts.append(["item", "Build: " + st.name, Crafting.stat_text(st) + (". Building a new one replaces the old one." if not S.homerod.is_empty() else ".") + ("" if ok else " Pick parts you have."),
		"Build it", func(): Crafting.build_rod(rod_pick); Sound.play("ui_click"); hud.flash("You build a %s. It's in your hands." % st.name.to_lower()); open_home(), ok,
		func(ci, r): ItemIcons.draw_homerod(ci, st, r), not ok])
	for i in 3:
		var slot: Array = Crafting.ROD_SLOTS[i]
		parts.append(["head", slot[1]])
		for o in slot[2]:
			var oid: String = o.id
			var si := i
			var picked: bool = rod_pick[i] == oid
			var have := Crafting.has_opt(o)
			var need := "" if oid == "" else " Needs %s (you have %d)." % [("%d wine corks" % Crafting.opt_need(o)) if oid == "p_cork" else Crafting._a(Crafting.PARTS[oid]), Crafting.count(oid)]
			parts.append(["item", o.n, o.ds + need, "Picked" if picked else "Pick", func(): rod_pick[si] = oid; open_home(), have and not picked,
				func(ci, r): ItemIcons.draw(ci, oid if oid != "" else "p_tape", r), not have])

# ---------- static drawings ----------
func _draw_statics(ci: CanvasItem, reg: Rect2) -> void:
	# driveways from the houses to the street, some with a car in them
	for dw in Town.driveways:
		var r: Rect2 = dw.r
		if not reg.has_point(r.position): continue
		var d: Vector2i = dw.d
		var vert := d.y != 0
		# a flared apron where it meets the street
		var ap := Rect2(r.position.x - 0.25, r.end.y - 0.6, r.size.x + 0.5, 0.6) if d.y == 1 else \
			Rect2(r.position.x - 0.25, r.position.y, r.size.x + 0.5, 0.6) if d.y == -1 else \
			Rect2(r.position.x, r.position.y - 0.25, 0.6, r.size.y + 0.5) if d.x == -1 else Rect2(r.end.x - 0.6, r.position.y - 0.25, 0.6, r.size.y + 0.5)
		ci.draw_rect(r.grow(0.05), Color(0.2, 0.25, 0.15, 0.25))
		ci.draw_rect(ap, Color("#c9c3b5"))
		ci.draw_rect(r, Color("#d3cdbf"))
		# expansion joints, a darker middle where the tires go, and an oil spot
		var L := r.size.y if vert else r.size.x
		var k := 1.0
		while k < L:
			if vert: ci.draw_line(Vector2(r.position.x, r.position.y + k), Vector2(r.end.x, r.position.y + k), Color(0, 0, 0, 0.12), 0.03)
			else: ci.draw_line(Vector2(r.position.x + k, r.position.y), Vector2(r.position.x + k, r.end.y), Color(0, 0, 0, 0.12), 0.03)
			k += 1.0
		for o in [0.28, 0.72]:
			if vert: ci.draw_rect(Rect2(r.position.x + r.size.x * o - 0.09, r.position.y, 0.18, r.size.y), Color(0, 0, 0, 0.05))
			else: ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * o - 0.09, r.size.x, 0.18), Color(0, 0, 0, 0.05))
		var oc := r.get_center() + Vector2(0.1, 0.15)
		Art.ellipse(ci, oc, 0.22, 0.14, Color(0.1, 0.1, 0.12, 0.14))
		if vert:
			ci.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.25), 0.04)
			ci.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(0, 0, 0, 0.12), 0.04)
		else:
			ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.25), 0.04)
			ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0, 0, 0, 0.12), 0.04)
		if dw.car:
			var col := Color(Art.CAR_COLORS[int(Town.hash2(int(r.position.x), int(r.position.y) * 3) * Art.CAR_COLORS.size())])
			var pc := Obstacles.driveway_car(dw)
			Art.car(ci, pc[0], pc[1], col, 1.6, 0.78)
	# parked cars in the lots (the same places Obstacles uses, so you bump into what you see)
	for d in Town.decor:
		if d.k != "parking": continue
		for pc in Obstacles.lot_cars(d):
			var x: int = pc[2]
			if not reg.has_point(Vector2(x, d.y0)): continue
			var col := Color(Art.CAR_COLORS[int(Town.hash2(x, d.y0 * 3) * Art.CAR_COLORS.size())])
			Art.car(ci, pc[0], pc[1], col, 1.65, 0.8)
	# fences, walls and gates
	for y in range(int(reg.position.y), mini(int(reg.end.y), Town.MH)):
		for x in range(int(reg.position.x), mini(int(reg.end.x), Town.MW)):
			var t: int = Town.tile[Town.idx(x, y)]
			match t:
				Town.T.FENCE:
					_draw_fence(ci, x, y)
				Town.T.GATE:
					var hor := Town.t_at(x - 1, y) == Town.T.FENCE or Town.t_at(x + 1, y) == Town.T.FENCE
					ci.draw_rect(Rect2(x, y + 0.38, 0.16, 0.24) if hor else Rect2(x + 0.38, y, 0.24, 0.16), Color("#8b9196"))
					ci.draw_rect(Rect2(x + 0.84, y + 0.38, 0.16, 0.24) if hor else Rect2(x + 0.38, y + 0.84, 0.24, 0.16), Color("#8b9196"))
				Town.T.GAP:
					_draw_fence_hole(ci, x, y)
				Town.T.HWALL:
					var hor2 := Town.t_at(x - 1, y) in [Town.T.HWALL, Town.T.HGATE] or Town.t_at(x + 1, y) in [Town.T.HWALL, Town.T.HGATE]
					ci.draw_rect(Rect2(x + 0.1, y + 0.1, 1, 1), Color(0, 0, 0, 0.12))
					ci.draw_rect(Rect2(x, y, 1, 1), Color("#efe3cc"))
					ci.draw_rect(Rect2(x, y + 0.36, 1, 0.28) if hor2 else Rect2(x + 0.36, y, 0.28, 1), Color("#c96f4a"))
				Town.T.GRATE:
					ci.draw_rect(Rect2(x + 0.1, y + 0.1, 0.8, 0.8), Color("#151614"))
					for k in 4: ci.draw_rect(Rect2(x + 0.15 + k * 0.2, y + 0.1, 0.07, 0.8), Color("#6b6f6a"))
				Town.T.HIDE:
					ci.draw_rect(Rect2(x + 0.2, y, 0.6, 0.75), Color("#24363a"))

## One fence tile. A straight run spans the whole tile, as before; a corner or a T joins its
## rails at the middle of the tile under a corner post, so the fence closes up with no gap.
func _draw_fence(ci: CanvasItem, x: int, y: int) -> void:
	var joins := [Town.T.FENCE, Town.T.GATE, Town.T.GAP]
	var l: bool = Town.t_at(x - 1, y) in joins
	var r: bool = Town.t_at(x + 1, y) in joins
	var u: bool = Town.t_at(x, y - 1) in joins
	var d: bool = Town.t_at(x, y + 1) in joins
	var rail := Color("#c9ced2")
	var post := Color("#8b9196")
	var shadow := Color(0, 0, 0, 0.18)
	var sh := Vector2(0.06, 0.08)
	var c := Vector2(x + 0.5, y + 0.5)
	var segs: Array = []
	if (l or r) and (u or d):
		for pair in [[l, Vector2(-0.5, 0)], [r, Vector2(0.5, 0)], [u, Vector2(0, -0.5)], [d, Vector2(0, 0.5)]]:
			if pair[0]: segs.append([c, c + pair[1]])
	elif l or r: segs.append([Vector2(x, y + 0.5), Vector2(x + 1, y + 0.5)])
	else: segs.append([Vector2(x + 0.5, y), Vector2(x + 0.5, y + 1)])
	for sg in segs: ci.draw_line(sg[0] + sh, sg[1] + sh, shadow, 0.08)
	for sg in segs: ci.draw_line(sg[0], sg[1], rail, 0.08)
	if (l or r) and (u or d): ci.draw_rect(Rect2(c - Vector2(0.11, 0.11), Vector2(0.22, 0.22)), post)
	elif l or r: ci.draw_rect(Rect2(x, y + 0.42, 0.14, 0.16), post)
	else: ci.draw_rect(Rect2(x + 0.42, y, 0.16, 0.14), post)

## A squeeze-through hole: the fence is cut and its ends peeled back, so it reads as a way in.
func _draw_fence_hole(ci: CanvasItem, x: int, y: int) -> void:
	var hor := Town.t_at(x - 1, y) == Town.T.FENCE or Town.t_at(x + 1, y) == Town.T.FENCE
	var rail := Color("#c9ced2")
	var shadow := Color(0, 0, 0, 0.18)
	var sh := Vector2(0.06, 0.08)
	var along := Vector2(1, 0) if hor else Vector2(0, 1)
	var side := Vector2(0, 1) if hor else Vector2(1, 0)
	var a := Vector2(x, y + 0.5) if hor else Vector2(x + 0.5, y)
	var b := a + along
	# each cut end runs a little way in, then curls off to one side
	var ends := [[a, along, side], [b, -along, -side]]
	for e in ends:
		var p0: Vector2 = e[0]
		var p1: Vector2 = p0 + e[1] * 0.2
		var p2: Vector2 = p1 + e[1] * 0.1 + e[2] * 0.2
		for col_off in [[shadow, sh], [rail, Vector2.ZERO]]:
			ci.draw_line(p0 + col_off[1], p1 + col_off[1], col_off[0], 0.07)
			ci.draw_line(p1 + col_off[1], p2 + col_off[1], col_off[0], 0.06)
	# a few snapped wires hanging in the opening
	for k in 3:
		var t := 0.36 + k * 0.14
		var q := a + along * t
		ci.draw_line(q - side * 0.08, q + side * (0.04 + 0.04 * k), Color(rail, 0.75), 0.03)

func _draw_labels(ci: CanvasItem) -> void:
	var ink := Color("#22313a")
	var paper := Color(0.98, 0.95, 0.89, 0.9)
	for g in Town.signs:
		ci.draw_rect(Rect2(g.x - 0.04, g.y - 0.1, 0.08, 0.5), Color("#6b5034"))
		ci.draw_rect(Rect2(g.x - 0.62, g.y - 0.55, 1.24, 0.5), Color("#c93b2a"))
		Art.text(ci, Vector2(g.x, g.y - 0.2), "NO FISHING", 0.2, Color.WHITE)
	var dt := get_process_delta_time()
	for l in Town.labels:
		var pos := Vector2(l.x, l.y)
		var a := _label_alpha(l.t, pos, dt)
		if a > 0: Art.text(ci, pos, l.t, 0.5, Color(ink, a), Color(paper, paper.a * a))
	for b in Town.buildings:
		if b.label == "" or b.kind == "shop": continue
		var pos := Vector2(b.x + b.w / 2.0, b.y - 0.35)
		if b.kind == "sky":
			var g := Art.sky_geom(b)
			pos = Vector2(b.x + g.y + b.w / 2.0, b.y - g.x - 0.35)
		var a := _label_alpha(b.label + str(pos), pos, dt)
		if a > 0: Art.text(ci, pos, b.label, 0.4, Color(ink, a), Color(paper, paper.a * a))

## Place names on the ground fade out LABEL_SECS after they come on screen, and come back
## once you've walked far enough away that they're off screen again.
func _label_alpha(key: String, pos: Vector2, dt: float) -> float:
	var v := Drawer.view
	if v.grow(-1.0).has_point(pos): label_seen[key] = float(label_seen.get(key, 0.0)) + dt
	elif not v.grow(3.0).has_point(pos): label_seen.erase(key)
	var t: float = label_seen.get(key, 0.0)
	return clampf((LABEL_SECS - t) / 0.8, 0.0, 1.0)

func _draw_night_glow(ci: CanvasItem) -> void:
	var dk := Game.darkness()
	if dk < 0.15: return
	var h := Game.hour()
	var lit := 0.55 if (h >= 18 or h < 1) else 0.18 if h < 5 else 0.35
	var view := Rect2(cam.get_screen_center_position() / TS - get_viewport_rect().size / cam.zoom / TS / 2, get_viewport_rect().size / cam.zoom / TS).grow(4)
	var t := Time.get_ticks_msec() / 1000.0
	for pair in sky_nodes:
		var b: Dictionary = pair[1]
		var g := Art.sky_geom(b)
		if not view.intersects(Art.sky_bounds(b)): continue
		var col := Color(1, 0.84, 0.51, 0.75 * dk / 0.62)
		var i := 0
		for r in b.wins:
			if Town.hash2(i, b.x * 7 + Game.S.day) < lit:
				var dd: float = r.get_center().distance_to(player.position + Vector2(0, -0.3))
				var cut: float = b.see * (1.0 - smoothstep(1.4, 2.6, dd)) * 0.85
				ci.draw_rect(r, Color(col.r, col.g, col.b, col.a * (1.0 - cut)))
			i += 1
		if b.get("ant", false) and int(t * 1.2 + b.x) % 2 == 0:
			ci.draw_circle(Vector2(b.x + g.y + b.w * 0.75, b.y - g.x + b.h * 0.4 - 1.1), 0.14, Color(1, 0.3, 0.23))
	if open_lamps.is_empty():
		for lp in Town.lamps:
			var hidden := Town.is_water_t(Town.t_at(floori(lp.x), floori(lp.y)))
			for b in Town.buildings:
				if b.kind != "sky": continue
				var g := Art.sky_geom(b)
				if Rect2(b.x - g.x * 0.4 - 0.2, b.y - g.x, b.w + g.x * 0.8 + 0.4, b.h + g.x).has_point(Art.lamp_head(lp)) and lp.y < b.y + b.h: hidden = true
			if not hidden: open_lamps.append(lp)
	for lp in open_lamps:
		if not view.has_point(lp): continue
		var hd := Art.lamp_head(lp)
		var a := dk / 0.62
		ci.draw_circle(hd, 0.42, Color(1, 0.85, 0.55, 0.12 * a))
		ci.draw_circle(hd, 0.22, Color(1, 0.88, 0.6, 0.3 * a))
		ellipse_glow(ci, hd + Vector2(0, 0.02), a)
	if Town.level == 0 and view.has_point(Vector2(51.4, 31.6)): Art.text(ci, Vector2(51.4, 31.6), "OPEN", 0.4, Color(1, 0.4, 0.33, 0.9))

## Gulls wheeling over the water by day.
const GULL_SPOTS2 := [Vector2(30, 10), Vector2(75, 8), Vector2(56, 36), Vector2(56, 70), Vector2(56, 130), Vector2(26, 72), Vector2(56, 165)]
const GULL_SPOTS3 := [Vector2(76, 39), Vector2(84, 34), Vector2(70, 46), Vector2(74, 68), Vector2(63, 20), Vector2(63, 124), Vector2(58, 150), Vector2(66, 150), Vector2(90, 120), Vector2(55, 178), Vector2(104, 112), Vector2(86, 108)]
const GULL_SPOTS := [Vector2(95, 162), Vector2(20, 163), Vector2(32, 52), Vector2(52, 170), Vector2(30, 166), Vector2(79, 128), Vector2(61, 101), Vector2(88, 14), Vector2(70, 52), Vector2(105, 79), Vector2(60, 176)]

func _draw_gulls(ci: CanvasItem) -> void:
	var h := Game.hour()
	if h < 6.3 or h > 19.6 or Game.wx.rain > 0.5: return
	var view := _view_tiles().grow(3)
	var t := Time.get_ticks_msec() / 1000.0
	var birds := []
	var gs: Array = [GULL_SPOTS, GULL_SPOTS2, GULL_SPOTS3][Town.level]
	for i in gs.size():
		var c: Vector2 = gs[i]
		if c.distance_to(view.get_center()) > view.size.length() / 2 + 8: continue
		for k in 2 + i % 2:
			var r := 3.0 + Town.hash2(i, k) * 4.0
			var sp := (0.12 + Town.hash2(k, i) * 0.08) * (1.0 if (i + k) % 2 else -1.0)
			var a := t * sp + Town.hash2(i * 3, k * 5) * TAU
			var p := c + Vector2(cos(a) * r, sin(a) * r * 0.7)
			var flap := sin(t * 7.0 + i + k * 2.0)
			if fmod(t * 0.3 + k + i, 3.0) > 1.4: flap = 0.25    # gliding
			var alt := 2.2 + Town.hash2(k, i * 7) * 1.0
			birds.append([p, a + (PI / 2 if sp > 0 else -PI / 2), flap, alt])
	# no shadows on purpose: on the water they read as fish
	for bd in birds:
		var p: Vector2 = bd[0] - Vector2(bd[3] * 0.55, bd[3] * 0.8)
		if view.has_point(p): Art.gull(ci, p, bd[1], bd[2], 0.85)

func ellipse_glow(ci: CanvasItem, p: Vector2, a: float) -> void:
	Art.ellipse(ci, p, 0.12, 0.05, Color(1, 0.97, 0.85, 0.95 * a))

func _view_tiles() -> Rect2:
	return Rect2(cam.get_screen_center_position() / TS - get_viewport_rect().size / cam.zoom / TS / 2, get_viewport_rect().size / cam.zoom / TS).grow(2)

## Paddle under a bridge and you go under its deck: the deck fades so you can still see yourself,
## dimmed in the shade. The first time, a tip about fishing the shade.
func _bridges(dt: float) -> void:
	var boat := player.in_boat()
	var half := 1.2 if player.boat_kind() == "skiff" else 0.95
	var under := boat and Bridges.hull_under(player.position, player.face, half)
	player.z_index = -5 if under else 0
	var high := Bridges.high_at(player.position + Vector2(0, -0.2))
	var over := Bridges.covered(player.position + Vector2(0, 0.1)) if boat else high
	for i in Bridges.list.size():
		var e: Dictionary = Bridges.list[i]
		e.see = move_toward(e.see, 1.0 if i == over else 0.0, dt * 3.0)
	var sh := Bridges.shade_at(player.position) if boat else (1.0 if high >= 0 else 0.0)
	player.modulate = Color.WHITE.lerp(Color(0.58, 0.62, 0.72), sh * (0.6 + 0.4 * (Bridges.list[over].see if over >= 0 else 0.0)))
	if over >= 0 and not Game.S.get("bridge_tip", false):
		Game.S.bridge_tip = true
		Game.toast.emit("Fish love the shade under a bridge. Cast along the shadow line. At night, " + (["snook wait under the bridge lights.", "walleye wait under the viaduct lights.", "big stripers wait in the bridge lights."][Town.level]), "UNDER THE BRIDGE")

# ---------- the Mullet Bay Slam ----------
func _slam_sign() -> void:
	if Story.sign_up():
		open_marina(); hud.flash("You're in the Slam. Only fish caught from now on count.")

func _slam_weigh() -> void:
	var r := Story.weigh_in()
	if r.is_empty(): return
	r.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(r)

# ---------- the journal: spots, Lou's Wall of Fame, and the Gazette ----------
func open_journal() -> void:
	var S := Game.S
	var tabs := []
	for td in [["spots", "Fishing spots"], ["fame", "Wall of Fame"], ["news", "Gazette"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): journal_tab = key; open_journal(), journal_tab == key])
	var parts := [["h3", "Fishing journal"]]
	match journal_tab:
		"fame":
			parts.append(["h2", "Lou's Wall of Fame"]); parts.append(["tabs", tabs])
			var st: Dictionary = S.stats
			parts.append(["kv", [["Legends", "%d/%d" % [Story.legends_got(), Story.legends_all()]], ["Species", str(Story.species_got())], ["Junk found", str(Story.junk_got())],
				["Fish landed", str(st.catches)], ["Busted", str(int(S.busts))], ["Orders filled", str(st.orders)]]])
			var got := Story.ACH.filter(func(a): return S.ach.has(a[0])).size()
			parts.append(["head", "Plaques: %d of %d" % [got, Story.ACH.size()]])
			parts.append(["grid", Story.ACH.map(func(a): return [a[1], a[2] + (" Day %d." % int(S.ach[a[0]]) if S.ach.has(a[0]) else ""), S.ach.has(a[0])])])
			parts.append(["head", "Slam trophies"])
			if S.trophies.is_empty(): parts.append(["sub", "No Slam finishes yet. The marina runs one every seventh day."])
			else:
				var tr: Array = S.trophies.slice(-8); tr.reverse()
				parts.append(["lb", tr.map(func(t): return ["Day %d · %s" % [int(t.day), Story.TFMT[t.fmt][0]], "%s · %s" % [Story.ordinal(int(t.place)), Story.fmt_score(t.fmt, t.v)], int(t.place) == 1])])
		"news":
			parts.append(["h2", "The Port Mullet Gazette"]); parts.append(["tabs", tabs])
			if S.news.is_empty(): parts.append(["sub", "Nothing newsworthy yet. Give it time."])
			for n in S.news: parts.append(["item", n.text, "Day %d" % int(n.day), "", func(): pass, false])
		_:
			parts.append(["h2", "%d of %d legends" % [Story.legends_got(), Story.legends_all()]]); parts.append(["tabs", tabs])
			parts.append(["sub", "Each fish shows the bait it bites best on. You have %s on (B to switch)." % Game.bait_name().to_lower()])
			var keys := Game.spots.keys(); keys.sort()
			for k in keys:
				var s: Dictionary = Game.spots[k]
				var visited: bool = S.visited.has(str(k)) or s.fish.any(func(f): return S.journal.has(f.n) and int(S.journal[f.n].spot) == int(k))
				parts.append(["head", s.name, "Visited" if visited else "Not visited yet"])
				parts.append(["chips", s.fish.map(func(f):
					var j: Variant = S.journal.get(f.n)
					var leg: bool = f.get("legend", false)
					var txt: String = (f.n if j != null or not leg else "???") + (" · %s lb" % str(j.w) if j != null else "") + journal_bait(f)
					return [txt, "got" if j != null else "leg" if leg else ""])])
	parts.append(["row", [["Close", func(): hud.close(), true, "hot"], ["Map (M)", open_map]]])
	hud.open(parts)

## The bait a fish bites best on, for its journal tag: " · on bread", " · on worms or bread".
## Shown for every fish, legends too, so new players know what to put on before they go.
const JOURNAL_BAIT := { "worms": "worms", "shrimp": "shrimp", "lure": "lure", "hotdog": "hot dogs", "bread": "bread", "squid": "squid" }
func journal_bait(f: Dictionary) -> String:
	var pref: Variant = Game.baitpref.get(f.n)
	if f.get("junk", false) or pref == null or pref.is_empty(): return ""
	return " · on " + " or ".join(pref.map(func(b): return JOURNAL_BAIT.get(b, b)))

# ---------- the map ----------
var map_view: MapView
func open_map() -> void:
	map_view = MapView.new(self)
	map_view.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 250)
	var subs := ["Zoom in for street names and how many of each spot's fish you've caught. Lou's is on US-1; downtown and the bay are way down south. Every place is open from day one. The red-striped places are private and watched, so go when the guards are away, or bring a disguise.",
		"Zoom in for street names and how many of each spot's fish you've caught. The dam and the spillway are at the top, the I-90 viaduct crosses the middle, and the coach station is at the bottom on the west bank. The red-striped places are private and watched, so go when the guards are away, or bring a disguise.",
		"Zoom in for street names and how many of each spot's fish you've caught. The city is on the west side and the harbor on the east. The fish market wharf and the ferry slip are off the Harbor Walk, the Narrows Bridge crosses the middle, and the container port and Union Station are at the bottom. The red-striped places are private and watched, so go when the guards are away, or bring a disguise."]
	hud.open([["h3", Town.NAMES[Town.level] + " · drag to move, scroll or + and − to zoom"], ["node", map_view],
		["sub", subs[Town.level]],
		["row", [["Close", func(): hud.close(), true, "hot"], ["Journal (J)", open_journal]]]], true)

# ---------- the bus (the Harbor Line subway in Gannet Harbor) and the coaches between towns ----------
func open_bus(i: int) -> void:
	var stops := Story.bus_list()
	var lv := Town.level
	var heads := ["Route 1 bus · ", "Calder Line bus · ", "Harbor Line subway · "]
	var hellos := ["\"Exact change, pal.\"", "\"Hop on, hon.\"", "\"Stand clear of the closing doors.\""]
	var rides := ["Two dollars to anywhere on the line. The ride takes about 25 minutes, and the driver doesn't want to hear about your fish.",
		"Two dollars to anywhere on the line. The ride takes about 25 minutes, and the driver wants to hear all about your fish.",
		"Two dollars to anywhere on the line. The train takes about 25 minutes, and nobody on it looks twice at a guy with a rod and a cooler."]
	var parts := [["h3", heads[lv] + stops[i][0]], ["h2", hellos[lv]], ["p", rides[lv]]]
	for j in stops.size():
		if j == i: continue
		var jj := j
		parts.append(["item", stops[j][0], stops[j][2], "Ride ($2)", func(): _ride_bus(jj), Game.S.cash >= 2])
	# the coaches to the other towns
	for to in [0, 1, 2]:
		if to == lv: continue
		var c: Array = COACHES["%d-%d" % [lv, to]]
		var fare: int = c[0]
		var why := _coach_locked(to)
		var desc := _coach_desc(lv, to, int(c[1])) if why == "" else why
		var tt: int = to
		parts.append(["item", ("Coach home to " if to == 0 else "Coach to ") + Town.NAMES[to], desc, "Ride (%s)" % Game.money(fare), func(): _take_coach(tt),
			why == "" and Game.S.cash >= fare, _coach_icon, why != ""])
	parts.append(["row", [["Walk instead", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

## Why the coach to town `to` isn't running for you yet, or "".
func _coach_locked(to: int) -> String:
	if to == 1:
		var have := _species_in(0)
		if have < COACH_SPECIES and int(Game.S.level) == 0: return "Lou: \"Ironwater? Catch %d kinds of fish around here first.\" You've caught %d." % [COACH_SPECIES, have]
	if to == 2:
		var have := _species_in(1)
		if have < COACH_SPECIES_GH:
			return "Dot told you about Gannet Harbor: \"Big city. Catch %d kinds up here first, so they don't laugh at you.\" You've caught %d in Ironwater." % [COACH_SPECIES_GH, have] if int(Game.S.get("trips", 0)) > 0 or Game.S.get("iw_seen", false) else \
				"Gannet Harbor is a long way up the coast. Get to Ironwater first and catch %d kinds of fish there." % COACH_SPECIES_GH
	return ""

func _coach_desc(from: int, to: int, hours: int) -> String:
	match to:
		0: return "%d hours back down the interstate to Lou's. Your boats ride on the roof rack." % hours
		1: return "%d hours to Ironwater, a river city with a big dam and a bigger bridge. Your boats ride on the roof rack." % hours
		_: return "%d hours up the coast to Gannet Harbor: a fish market, a container port and a suspension bridge you fish under. Stripers and bluefish. Your boats ride on the roof rack." % hours

## A little coach, side on, for the coach's row on the bus card.
func _coach_icon(ci: CanvasItem, r: Rect2) -> void:
	var b := Rect2(r.position + Vector2(r.size.x * 0.06, r.size.y * 0.28), Vector2(r.size.x * 0.88, r.size.y * 0.42))
	ci.draw_rect(b, Color("#2b7ea6"))
	ci.draw_rect(Rect2(b.position + Vector2(0, b.size.y * 0.62), Vector2(b.size.x, b.size.y * 0.12)), Color("#f2b134"))
	for i in 5: ci.draw_rect(Rect2(b.position + Vector2(b.size.x * (0.06 + i * 0.18), b.size.y * 0.14), Vector2(b.size.x * 0.13, b.size.y * 0.34)), Color("#cfe8f4"))
	ci.draw_rect(Rect2(b.position + Vector2(b.size.x * 0.1, -b.size.y * 0.22), Vector2(b.size.x * 0.55, b.size.y * 0.16)), Color("#c9603a"))   # a kayak on the roof rack
	for wx in [0.22, 0.8]: ci.draw_circle(b.position + Vector2(b.size.x * wx, b.size.y), b.size.y * 0.2, Color("#22313a"))

## Kinds of fish (not junk) you've caught in town lv's water, for the coaches.
func _species_in(lv: int) -> int:
	var n := 0
	var seen := {}
	for sid in Game.spots:
		if Town.spot_town(int(sid)) != lv: continue
		for f in Game.spots[sid].fish:
			if f.get("junk", false) or seen.has(f.n): continue
			seen[f.n] = true
			var j: Variant = Game.S.journal.get(f.n)
			# a fish that swims in more than one town counts where you caught it
			if j != null and (lv == 0 or Town.spot_town(int(j.get("spot", sid))) == lv): n += 1
	return n

func _ride_bus(i: int) -> void:
	if Game.S.cash < 2: return
	hud.close()
	menu.fade(func(): _arrive_bus(i), 0.35, 0.6)

func _arrive_bus(i: int) -> void:
	Sound.play("bus")
	Game.S.cash -= 2
	Game.skip_minutes(25)
	Game.S.boat = false
	var stops := Story.bus_list()
	player.position = stops[i][1]; player.path.clear()
	cam.position = player.position * TS; cam.reset_smoothing()
	for w in guards.watchers: w.alert = 0.0
	hud.close(); hud.flash(("The train pulls in: %s." if Town.level == 2 else "The bus wheezes to a stop: %s.") % stops[i][0]); Game.save_game()

## The coach to another town: you get off at its first stop (Lou's, Ironwater Station or Union Station).
## The map changes, so the save is written and the scene reloaded in the new town.
func _take_coach(to: int) -> void:
	var c: Array = COACHES.get("%d-%d" % [Town.level, to], [COACH_FARE, 6])
	var fare: int = c[0]
	if Game.S.cash < fare: return
	hud.close()
	menu.fade(func():
		Game.S.cash -= fare
		Game.skip_minutes(int(c[1]) * 60)
		Game.S.boat = false
		Game.S.parked = {}           # your kayak and skiff came with you, on the roof rack
		Game.S.level = to
		var p: Vector2 = Story.bus_list(to)[0][1]
		Game.S.x = p.x; Game.S.y = p.y; Game.S.face = PI / 2
		Game.S.coach_in = true
		Game.S.trips = int(Game.S.get("trips", 0)) + 1
		Game.save_game()
		Game.skip_title = true
		get_tree().reload_current_scene(), 0.6, 0.0)

## Just off the coach: the first time in a new town, a card about it; after that a line.
func _coach_arrival() -> void:
	if not Game.S.get("coach_in", false): return
	Game.S.coach_in = false
	Game.save_game()   # so quitting right away doesn't greet you off the coach again next time
	Sound.play("bus")
	if Town.level == 0:
		hud.flash("The coach pulls in at Lou's. Port Mullet smells like low tide. It's good to be home."); return
	if Town.level == 2:
		if Game.S.get("gh_seen", false):
			hud.flash("The coach pulls into Union Station. Gulls, diesel and low tide. Gannet Harbor."); return
		Game.S.gh_seen = true; Game.save_game()
		hud.open([["h3", "Gannet Harbor · pop. 680,000 · on Gannet Bay"], ["h2", "\"Mind the gulls. They'll take a sandwich right out of your hand.\""],
			["p", "A long way up the coast, Gannet Harbor is an old fishing city that never stopped: a fish market on a wharf, ferries crossing the inner harbor, a container port, and the Gannet Narrows Bridge hung high over the tide rip."],
			["sub", "The Harbor Walk runs the whole waterfront, with piers by the subway stations, and it's all public. Stripers and bluefish are everywhere. Fish under the bridge at night, where the big stripers wait in the lights. The fish market wharf is busy 3 to 11 AM, and the container port, the bridge tower yard and the rooftop garden all have someone watching."],
			["sub", "Pier 6 Bait & Tackle by the fish market buys your catch and sells everything, squid and boats included. Next door, the Gannet Fish Exchange posts new prices every morning, and the Pilot St Chowder House pays most for today's catch. The Seamen's Hostel has bunks. The Harbor Line subway runs along the waterfront, and the coaches leave from Union Station."],
			["row", [["Let's fish", func(): hud.close(), true, "hot"]]]])
		return
	if Game.S.get("iw_seen", false):
		hud.flash("The coach hisses to a stop at Ironwater Station. You can hear the dam from here."); return
	Game.S.iw_seen = true; Game.save_game()
	hud.open([["h3", "Ironwater · pop. 41,300 · on the Calder River"], ["h2", "\"You can hear the dam from the station.\""],
		["p", "Six hours north of Port Mullet, the Calder River comes over the Ironwater Dam and roars down the spillway, then runs straight through an old mill town under three street bridges and the high I-90 viaduct."],
		["sub", "Fish the tailwater pier and the river walks for free. The big flatheads live in the boil right under the gates, but the wing walls are restricted. Walleye wait under the viaduct lights at night. The old mill race, the brewery pond and the ballpark splash pool all have someone watching."],
		["sub", "Calder River Outfitters on River St buys your fish and sells the same gear as Lou. The Tailrace Supper Club and the Ironwater Public Market, across the river on Bank St, pay more for the right fish. The Riverview Motor Inn has rooms. Take the coach home from any bus stop."],
		["row", [["Let's fish", func(): hud.close(), true, "hot"]]]])

## Where things are in the town you're in. Port Mullet keeps its constants.
func _place_town() -> void:
	if Town.level == 1:
		lou_door = Vector2(33.5, 88.4); home_door = Vector2(32.5, 115.4); marina_door = Vector2(-99, -99)
		oldtimer_at = Vector2(-99, -99); rosa_at = WALT
	elif Town.level == 2:
		lou_door = Vector2(47.5, 51.4); home_door = Vector2(24.5, 68.4); marina_door = Vector2(-99, -99)
		oldtimer_at = Vector2(-99, -99); rosa_at = THEO

## Ironwater's things that stand up: the waterwheel at the mill.
func _ironwater_props() -> void:
	var wp := Vector2(27.0, 43.0)
	ents.add_child(Drawer.make(func(ci): Ironwater.draw_wheel(ci, wp, Time.get_ticks_msec() / 1000.0), wp.y + 1.4, true, Rect2(wp - Vector2(2, 2.5), Vector2(4, 5))))
	var ground := Drawer.make(func(ci): Ironwater.draw_ground(ci), 0, false)
	ground.z_index = -8
	world.add_child(ground)
	var dam := Drawer.make(func(ci): Ironwater.draw_dam(ci, _view_tiles().grow(2), Time.get_ticks_msec() / 1000.0), 0, true)
	dam.z_index = -7
	world.add_child(dam)

## Gannet Harbor's things that stand up: the quay cranes, the lighthouse and the ferry.
func _gannet_props() -> void:
	for d in Town.decor:
		var p := Vector2(d.get("x", 0.0), d.get("y", 0.0))
		if d.k == "crane": ents.add_child(Drawer.make(func(ci): Gannet.draw_crane(ci, p, Time.get_ticks_msec() / 1000.0), p.y + 0.9, true, Rect2(p - Vector2(3, 9), Vector2(14, 11))))
		elif d.k == "lighthouse": ents.add_child(Drawer.make(func(ci): Gannet.draw_lighthouse(ci, p, Time.get_ticks_msec() / 1000.0), p.y + 0.9, true, Rect2(p - Vector2(2, 6), Vector2(4, 7))))
	var ground := Drawer.make(func(ci): Gannet.draw_ground(ci), 0, false)
	ground.z_index = -8
	world.add_child(ground)
	var ferry := Drawer.make(func(ci): Gannet.draw_ferry(ci, Time.get_ticks_msec() / 1000.0), 0, true)
	ferry.z_index = -4
	world.add_child(ferry)

## Calder River Outfitters: Dot buys your catch and sells the same gear as Lou.
func open_outfitter() -> void:
	var S := Game.S
	if shop_tab != "sell" and shop_tab != "gear": shop_tab = "sell"
	var tabs := []
	for td in [["sell", "Sell"], ["gear", "Gear"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): shop_tab = key; open_outfitter(), shop_tab == key])
	var parts := [["h3", "Calder River Outfitters · bait, tackle, licenses"], ["h2", "\"%s\"" % ["Port Mullet? Long way to come for a walleye.", "Dot. Nice to meet you. What've you got?", "You fish the boil yet? Don't tell me.", "Wipe your boots, it's muddy out."].pick_random()], ["tabs", tabs]]
	if shop_tab == "sell":
		_sell_parts(parts, "Dot")
		parts.append(["sub", "Dot pays the same as Lou. She'll even take your Florida fish, \"for the novelty.\" Marge at the Tailrace Supper Club pays more for today's catch, and Gus at the Ironwater Public Market posts new prices every morning. Both are on Bank St, south of the viaduct."])
	else:
		parts.append(_kit_part())
		parts.append(["sub", "Dot's bait chart: worms for perch, crappie, sauger and trout. Bread for carp. Lures for smallmouth, walleye and muskie. Hot dogs for the big catfish below the dam."])
		_gear_list(parts, Game.gear.filter(func(g): return not g.has("where")))
		parts.append(["sub", "Your rod: %s. Boats and big-game tackle are back at the marina in Port Mullet." % Game.rod().name])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

## The Riverview Motor Inn: a room to rest in while you're in Ironwater, $10 a stay.
## In Gannet Harbor it's a bunk at the Seamen's Hostel.
func open_motel() -> void:
	if Town.level == 2: open_hostel(); return
	var rest := func(h: float):
		if Game.S.cash < 10: return
		Game.S.cash -= 10
		hud.close()
		menu.fade(func(): Game.skip_to(h); hud.flash("You rest until %s. The ice machine never stops." % Game.clock_text()); Game.save_game(), 0.4, 0.7)
	var can: bool = Game.S.cash >= 10
	hud.open([["h3", "Riverview Motor Inn · rooms by the night"], ["h2", "\"%s\"" % ["Checkout's at eleven. Ish.", "No cleaning fish in the room.", "Ice machine's down the hall."].pick_random()],
		["p", "A room is $10 a stay, cash. The workbench, the trophy wall and Chum are back home in Port Mullet."],
		["item", "Dawn", "Walleye and sauger bite at first light.", "Rest until 6:00 AM ($10)", func(): rest.call(6.0), can],
		["item", "Noon", "Brewery tour hours: a lanyard gets you to the cooling pond.", "Rest until 12:00 PM ($10)", func(): rest.call(12.0), can],
		["item", "Dusk", "The mill foreman and the groundskeeper knock off at 5.", "Rest until 5:30 PM ($10)", func(): rest.call(17.5), can],
		["item", "Night", "Old Rivet and the Viaduct Ghost come out.", "Rest until 9:00 PM ($10)", func(): rest.call(21.0), can],
		["row", [["Back outside", func(): hud.close(), true, "hot"]]]])

## The Seamen's Hostel on Ferry St: a bunk for $12, among deckhands and fish cutters.
func open_hostel() -> void:
	var rest := func(h: float):
		if Game.S.cash < 12: return
		Game.S.cash -= 12
		hud.close()
		menu.fade(func(): Game.skip_to(h); hud.flash("You rest until %s. Somebody in the next bunk snores like a foghorn." % Game.clock_text()); Game.save_game(), 0.4, 0.7)
	var can: bool = Game.S.cash >= 12
	hud.open([["h3", "Seamen's Hostel · since 1888"], ["h2", "\"%s\"" % ["Boots off upstairs.", "Bunk nine's free. Don't ask about bunk eight.", "Market crews get up at two. Sorry in advance."].pick_random()],
		["p", "A bunk is $12 a stay, cash. The workbench, the trophy wall and Chum are back home in Port Mullet."],
		["item", "Before the market", "The fish market wharf opens at 3 AM. The scraps bring the fish in.", "Rest until 3:00 AM ($12)", func(): rest.call(3.0), can],
		["item", "Dawn", "Stripers and blues blitz on the falling tide at first light.", "Rest until 6:00 AM ($12)", func(): rest.call(6.0), can],
		["item", "Noon", "The market's closed and the wharf is anybody's.", "Rest until 12:00 PM ($12)", func(): rest.call(12.0), can],
		["item", "Night", "The bridge lights come on, and the Harbormaster comes out.", "Rest until 9:00 PM ($12)", func(): rest.call(21.0), can],
		["row", [["Back outside", func(): hud.close(), true, "hot"]]]])

## Pier 6 Bait & Tackle, by the fish market: Sal buys your catch and sells everything Lou and the marina do.
func open_pier6() -> void:
	var S := Game.S
	if shop_tab != "sell" and shop_tab != "gear": shop_tab = "sell"
	var tabs := []
	for td in [["sell", "Sell"], ["gear", "Gear"]]:
		var key: String = td[0]
		tabs.append([td[1], func(): shop_tab = key; open_pier6(), shop_tab == key])
	var parts := [["h3", "Pier 6 Bait & Tackle · open 4 AM, every day"], ["h2", "\"%s\"" % ["Florida? You're lost, pal. Good. What've you got?", "Sal. Don't touch the eels.", "Stripers are in. You can smell it.", "Close the door, the gulls get in."].pick_random()], ["tabs", tabs]]
	if shop_tab == "sell":
		_sell_parts(parts, "Sal")
		parts.append(["sub", "Sal pays the same every day, like Lou. The Fish Exchange next door pays more for whatever is HOT on its board, and Nora at the Chowder House pays most for today's catch."])
	else:
		parts.append(_kit_part())
		parts.append(["sub", "Sal's bait chart: squid or a lure for stripers and blues, squid for sea bass, cod and the big tuna, shrimp for tautog and cunner, worms for flounder and scup, hot dogs for the eels by the outfall, bread for the rooftop koi."])
		_gear_list(parts, Game.gear.filter(func(g): return not g.has("where") or g.where == "marina"))
		parts.append(["sub", "Your rod: %s. Sal carries the marina's gear too: squid, the skiff, the big-game rod." % Game.rod().name])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

const THEO_TIPS := [
	"\"Under the bridge at night. The stripers sit right on the shadow line in the lights, nose into the tide. Squid or a lure, and let it swing.\"",
	"\"The market opens at three. They hose the cutting tables off the end of the wharf and every fish in the harbor knows it. The dockmaster runs you off unless you look like a buyer. A lanyard does it.\"",
	"\"Blues'll bite through anything. Use a lure and don't put your thumb near that mouth.\"",
	"\"Tautog live on the rocks under the towers and the ferry piers. Shrimp. Set the hook hard, they grab and run for a hole.\"",
	"\"That outfall by the pump house? Eels love it. Hot dogs. And something big lives in the pipe. Nobody's landed it.\"",
	"\"The container port's got bonito and albies chasing bait around the ship. Port cops drive the quay all day and all night. There's a cut in the fence on Commercial St, behind the bushes.\"",
	"\"Take a skiff out past the buoys at the harbor mouth. Cod on the ledge at night, and once in a while a bluefin comes in. Bring the big rod.\"",
	"\"Rooftop garden on Kestrel Ave has a koi pond, nine floors up. Wear a suit and the attendant thinks you work there. Security does rounds after ten.\"",
]

## Theo, retired ferry deckhand, on his cooler at the end of the Narrows Park pier.
func talk_theo() -> void:
	var n := int(Game.S.get("theo", 0))
	var first := n == 0
	Game.S.theo = n + 1; Game.save_game()
	hud.open([["h3", "Theo · end of the Narrows Park pier"], ["h2", "\"Sit down, you're blocking my light.\"" if first else "\"Back again. Good.\""], ["quote", THEO_TIPS[n % THEO_TIPS.size()]],
		["sub", "Theo worked the harbor ferries for thirty-one years and has fished under the bridge every night since he retired."],
		["row", [["Thanks, Theo", func(): hud.close(), true, "hot"]]]])

const WALT_TIPS := [
	"\"The boil under the gates is where the big flatheads live. Old Rivet too. The ranger walks the west wing wall till nine at night. After that it's just the cameras. Watch which way they're pointing.\"",
	"\"Walleye come up under the viaduct lights after dark. Worms or a lure, right on the shadow line. Paddle under there if you've got a boat.\"",
	"\"Skipjack are no good to eat, but drop a hot dog where they're busting bait and something big comes looking.\"",
	"\"The Mayor's a muskie. Lures only, dawn or dusk, out on the reservoir. Bring a better rod than that.\"",
	"\"The old mill race runs cold right out of the reservoir. Trout. The foreman goes home at five and the watchman's dog comes on at nine. Do the math.\"",
	"\"That brewery pond? The carp eat the spent grain. Bread. Go in tour hours with a lanyard round your neck and security thinks you're on the tour.\"",
	"\"The ballpark's got a splash pool past center field. Groundskeeper leaves at five, security starts at ten. In between, everybody's watching the game.\"",
	"\"Hook a sturgeon, you let it go. Everybody in this town will hear about it if you don't. The Ghost under the viaduct most of all.\"",
]

func talk_walt() -> void:
	var n := int(Game.S.get("walt", 0))
	var first := n == 0
	Game.S.walt = n + 1; Game.save_game()
	hud.open([["h3", "Walt · end of the tailwater pier"], ["h2", "\"Pull up a bucket.\"" if first else "\"Back again. Good.\""], ["quote", WALT_TIPS[n % WALT_TIPS.size()]],
		["sub", "Walt worked forty years at the woolen mill and has fished below the dam every day since it closed."],
		["row", [["Thanks, Walt", func(): hud.close(), true, "hot"]]]])

## Gannet Harbor's lights after dark: the lighthouse beam turning, the necklace lights on the bridge
## cables, the floodlit cranes and the ferry's cabin windows.
func _gannet_glow(ci: CanvasItem, view: Rect2, a: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if view.grow(20).has_point(Vector2(105, 85)): Gannet.draw_beam(ci, Vector2(105, 85), t, a)
	var by: float = Gannet.BR_Y0
	for e in Bridges.list:
		if not e.get("susp", false): continue
		var x := maxf(Bridges.SUSP_ANCHOR[0], floorf(view.position.x / 2.0) * 2.0)
		while x < minf(Bridges.SUSP_ANCHOR[1], view.end.x):
			for dy in [by + 0.1, Gannet.BR_Y1 + 0.75]:
				_glow(ci, Vector2(x, dy - maxf(0.0, Bridges._cable_h(x))), 0.35, Color(1.0, 0.9, 0.6, 0.35 * a))
			x += 2.0
	for d in Town.decor:
		if d.k == "crane" and view.has_point(Vector2(d.x, d.y)): _glow(ci, Vector2(d.x + 2.0, d.y - 5.4), 2.4, Color(1.0, 0.9, 0.7, 0.2 * a))
	var f := Gannet.ferry_at(t)
	if view.has_point(f.p): _glow(ci, f.p, 1.6, Color(1.0, 0.85, 0.55, 0.3 * a))

static func draw_bus_stop(ci: CanvasItem, p: Vector2) -> void:
	if Town.level == 2: _subway_entrance(ci, p); return
	p = p - Vector2(0, 0.5)
	ci.draw_rect(Rect2(p.x - 0.5, p.y - 0.1, 1.25, 0.42), Color(0, 0, 0, 0.2))
	ci.draw_rect(Rect2(p.x - 0.6, p.y - 0.3, 1.2, 0.36), Color("#2b7ea6"))
	ci.draw_rect(Rect2(p.x - 0.52, p.y - 0.24, 1.04, 0.12), Color("#9fd3f0"))
	ci.draw_rect(Rect2(p.x - 0.45, p.y + 0.04, 0.9, 0.1), Color("#8a5a35"))
	ci.draw_rect(Rect2(p.x + 0.66, p.y - 0.5, 0.05, 0.7), Color("#6b5034"))
	ci.draw_circle(Vector2(p.x + 0.685, p.y - 0.55), 0.18, Color("#2b7ea6"))
	Art.text(ci, Vector2(p.x + 0.685, p.y - 0.51), "BUS", 0.13, Color.WHITE)

## A Harbor Line subway entrance: a green railing round the stairs going down, and the round sign on its post.
static func _subway_entrance(ci: CanvasItem, p: Vector2) -> void:
	p = p - Vector2(0, 0.45)
	var green := Color("#2f6a4a")
	ci.draw_rect(Rect2(p.x - 0.55, p.y - 0.25, 1.15, 0.7), Color(0, 0, 0, 0.18))
	ci.draw_rect(Rect2(p.x - 0.5, p.y - 0.3, 1.0, 0.62), Color("#3a3d42"))
	for k in 5: ci.draw_rect(Rect2(p.x - 0.42, p.y - 0.24 + k * 0.11, 0.84, 0.05), Color("#6c7178"))   # the stairs going down
	for sx in [-0.52, 0.47]: ci.draw_rect(Rect2(p.x + sx, p.y - 0.34, 0.05, 0.7), green)
	ci.draw_rect(Rect2(p.x - 0.52, p.y - 0.34, 1.04, 0.05), green)
	ci.draw_rect(Rect2(p.x + 0.66, p.y - 0.62, 0.05, 0.9), Color("#3a3d42"))
	ci.draw_circle(Vector2(p.x + 0.685, p.y - 0.68), 0.2, Color.WHITE)
	ci.draw_circle(Vector2(p.x + 0.685, p.y - 0.68), 0.16, green)
	Art.text(ci, Vector2(p.x + 0.685, p.y - 0.64), "H", 0.17, Color.WHITE)
