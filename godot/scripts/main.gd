extends Node2D
## Builds Port Mullet and runs the game loop: walking, fishing, the clock, night lights, Lou's and home.

const TS := Game.TS
const LOU_DOOR := Vector2(48.5, 32.4)
const HOME_DOOR := Vector2(8.75, 10.5)
const MARINA_DOOR := Vector2(88.5, 145.3)
const OLDTIMER := Vector2(37.4, 49.4)
const ROSA := Vector2(34.4, 165.6)
const STORY_LINES_OK := ["Lou whistles. The regulars nod.", "Somebody buys you a soda.", "Lou writes it on the whiteboard."]
const STORY_LINES_NO := ["Lou laughs so hard he has to sit down.", "A regular holds his hands two inches apart.", "\"Sure it was, buddy.\""]
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
var latch := { "shop": false, "home": false, "marina": false }
var guards: Guards
var prev_zone := 0
var prev_pos := Vector2.ZERO
var last_sale := 0
var pending_catch = null
var shop_tab := "sell"
var home_tab := "rest"
var rod_pick := ["p_glass", "p_reel", ""]   # the blank, reel and grip picked at the workbench
var marina_tab := "boats"
var journal_tab := "spots"
var weather: Weather
var ground_tex: Texture2D
var ground_mat: ShaderMaterial
var water_fx: WaterFx
var traffic: Traffic
var town_life: TownLife
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

func _ready() -> void:
	# the test hooks that put you somewhere or deep in the story start with the whole town open
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at=") or a.begins_with("--story=") or a.begins_with("--act2=") or a.begins_with("--boat="): Game.S.unlock = Unlocks.LAST
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var v := a.substr(5).split(",")
			Game.S.x = float(v[0]); Game.S.y = float(v[1]); Game.S.min = float(v[2]) * 60.0; Game.S.started = true
		if a.begins_with("--shot="): test_shot = a.substr(7)
		if a.begins_with("--boat="): Game.S.boat = true; Game.S.boat_kind = a.substr(7); Game.S.gear.kayak = 1; Game.S.gear.skiff = 1
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
		if a == "--cooler=sample":
			for f in [[1, 2], [1, 4], [1, 5], [4, 1], [14, 4], [15, 0], [2, 7], [16, 7]]:
				var fd: Dictionary = Game.spots[f[0]].fish[f[1]]
				Game.S.cooler.append({ "n": fd.n, "w": fd.w[0], "value": 20 + f[1] * 7, "spot": f[0], "legend": fd.get("legend", false), "junk": fd.get("junk", false), "day": 1, "tm": 0 })
		if a.begins_with("--unlock="): Game.S.unlock = int(a.substr(9)); Game.S.started = true
		if a.begins_with("--act2="): Game.S.saga.finished = true; Game.S.saga.ch = 7; Game.S.act2.ch = int(a.substr(7)) - 1; Game.S.act2.done = int(a.substr(7)) > 1; Game.S.day = maxi(int(Game.S.day), 9)
	Game.wx = Weather.compute(int(Game.S.day), Game.hour())
	RenderingServer.set_default_clear_color(Color("#0b1a3a"))
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
	for a in [[Vector2(3.6, 18.4), 0.2], [Vector2(16.5, 22.6), 3.4], [Vector2(29.6, 162.5), PI], [Vector2(31.4, 160.2), 0.0], [Vector2(37.4, 49.4), -0.3]]:
		var p: Vector2 = a[0]
		var d: float = a[1]
		ents.add_child(Drawer.make(func(ci): Art.person(ci, p, d, Color("#f2b134"), Color("#c9a574"), true), p.y))
	ents.add_child(Drawer.make(func(ci):
		if Game.hour() >= 7 and Game.hour() < 19: Art.person(ci, Vector2(50.6, 32.55), 0.4, Color("#13807b"), Color("#e2583e")), 32.55, true))
	player = Player.new()
	ents.add_child(player)
	for k in ["kayak", "skiff"]: ents.add_child(ParkedBoat.new(k))
	fishing.player = player
	water_fx = WaterFx.new()
	water_fx.z_index = -4
	water_fx.player = player
	water_fx.fishing = fishing
	world.add_child(water_fx)
	refl.player = player
	refl.fishing = fishing
	ents.add_child(Drawer.make(func(ci):
		ci.draw_rect(Rect2(ROSA.x + 0.25, ROSA.y - 0.05, 0.36, 0.3), Color("#e9e4d8"))
		Art.person(ci, ROSA, PI / 2 + 0.35, Color("#e2583e"), Color("#fbf3e2"), true)
		ci.draw_circle(ROSA + Vector2(-0.42, 0.1), 0.14, Color("#9aa6ad")), ROSA.y))
	ents.add_child(Drawer.make(func(ci): ci.draw_rect(Rect2(OLDTIMER.x - 0.5, OLDTIMER.y + 0.15, 0.3, 0.3), Color("#2c5f8a")), OLDTIMER.y + 0.01))
	# boats tied up at the marina
	for mb in [[93.5, "#2b7ea6", false], [103.5, "#e2583e", true], [108.5, "#13807b", false]]:
		var mp := Vector2(mb[0], 160.4)
		var mc := Color(mb[1])
		var ms: bool = mb[2]
		ents.add_child(Drawer.make(func(ci): Art.moored_boat(ci, mp, Time.get_ticks_msec() / 1000.0, mc, ms), mp.y + 1.2, true, Rect2(mp - Vector2(2, 3), Vector2(4, 6))))
	for lp in Town.lamps:
		var t := Town.t_at(floori(lp.x), floori(lp.y))
		if Town.is_water_t(t) or t == Town.T.BLD: continue
		var lpp: Vector2 = lp
		ents.add_child(Drawer.make(func(ci): Art.lamp_post(ci, lpp), lp.y))
	for bs in Story.BUS:
		var bp: Vector2 = bs[1]
		ents.add_child(Drawer.make(func(ci): draw_bus_stop(ci, bp), bp.y - 0.2))
	guards = Guards.new()
	guards.player = player
	guards.fishing = fishing
	guards.z_index = -4
	world.add_child(guards)
	guards.setup(ents)
	traffic = Traffic.new()
	traffic.player = player
	add_child(traffic)
	traffic.setup(ents)
	town_life = TownLife.new()
	town_life.player = player
	add_child(town_life)
	town_life.setup(ents)
	for fl in FLAGS:
		var fp: Vector2 = fl[0]
		var fs: String = fl[1]
		ents.add_child(Drawer.make(func(ci): TownLife.flag(ci, fp, fs, Time.get_ticks_msec() / 1000.0 + fp.x), fp.y, true, Rect2(fp - Vector2(1, 3.5), Vector2(4, 5))))
	for fo in FOUNTAINS:
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
	elif Unlocks.step() == 1 and not Game.S.order.done and not Game.order_easy(Game.cur_order()): Game.new_order()
	var line := Drawer.make(fishing.draw_line_layer, 0, true)
	line.z_index = 5
	world.add_child(line)
	var bars := Drawer.make(func(ci): Unlocks.draw_barriers(ci, _view_tiles()), 0, true)
	bars.z_index = 3
	world.add_child(bars)
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
		if a == "--rosa": talk_rosa()
		if a == "--open=marina-slam": marina_tab = "slam"; open_marina()
		if a == "--open=note": shop_tab = "note"; open_shop()
		if a == "--open=journal": open_journal()
		if a == "--open=fame": journal_tab = "fame"; open_journal()
		if a == "--open=news": journal_tab = "news"; open_journal()
		if a == "--beach": _toggle_boat()
		if a == "--open=map": open_map()
		if a == "--open=icons": # every item picture, big, for checking the art
			var ids := ["p_spoon", "p_caps", "p_beads", "p_feather", "p_wire", "p_glow", "p_glass", "p_graphite", "p_reel", "p_bigreel", "p_cork", "p_foam", "p_tape", "spoon", "popper", "jig", "glowlure", "rod0", "rod1", "rod2", "rod3", "rod4", "worms", "bait", "lure", "hotdog", "bread", "squid", "cooler", "mcooler", "camera", "polo", "lanyard", "flashlight", "waders", "geiger", "prybar", "kayak", "bigtank", "suit", "skiff", "shades", "junk"]
			var sheet := Control.new(); sheet.custom_minimum_size = Vector2(1180, 600)
			sheet.draw.connect(func():
				for i in ids.size():
					var r := Rect2(Vector2((i % 12) * 98 + 4, (i / 12) * 104 + 4), Vector2(88, 88))
					sheet.draw_rect(r, Color("#fff8ea"))
					ItemIcons.draw(sheet, ids[i], r.grow(-8))
					sheet.draw_string(Game.font_bold, r.position + Vector2(2, 100), ids[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#22313a")))
			hud.open([["node", sheet]], true)
		if a == "--open=bus": open_bus(0)
		if a == "--weigh":
			Story.sign_up()
			Game.S.cooler.append({ "n": "Snook", "w": 31.4, "value": 90, "spot": 14, "legend": false, "junk": false, "day": Game.S.day, "tm": Game.S.min + 5 })
			_slam_weigh()
		if a == "--toast": Game.add_news("Local Angler Buys Garage-Sale Rod, Announces 'Big Plans'")
		if a == "--cast": fishing.start_cast()
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
		hud.chips = []
		hud.refresh("")
		hud.action.visible = false; hud.hint.visible = false; hud.bar.visible = false
		_test_shot()
		return
	hud.bar.visible = true
	_audio(dt)
	if not hud.is_open():
		Game.advance(dt)
		var dir := Vector2.ZERO
		if fishing.state == "idle":
			if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): dir.x -= 1
			if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): dir.x += 1
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): dir.y -= 1
			if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): dir.y += 1
		player.step(dt if fishing.state == "idle" else 0.0, dir)
		var l := Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		var r := Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		fishing.turn = int(r) - int(l)
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
			if fishing.state == "idle" and Game.S.started and Unlocks.ready():
				Sound.play("plaque"); hud.open(Unlocks.advance(hud.close)); player.rebuild_grids()
		if player.position.y > 115 and not Game.S.visited.has("dt"): Game.S.visited.dt = 1; hud.flash("Downtown Port Mullet. The bay is at the bottom of the street.")
	near = ""
	if fishing.state == "idle":
		if player.in_boat(): near = "fish"
		elif player.position.distance_to(LOU_DOOR) < 1.3: near = "shop"
		elif player.position.distance_to(HOME_DOOR) < 1.0: near = "home"
		elif player.position.distance_to(MARINA_DOOR) < 1.3: near = "marina"
		elif player.position.distance_to(OLDTIMER) < 1.8: near = "oldtimer"
		elif player.position.distance_to(ROSA) < 1.6: near = "rosa"
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
	if z == 3: return "reactor"
	if z in [1, 2, 5, 6, 7, 8, 9]: return "prowl"
	if z == 4: return "swamp"
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
	Sound.set_reeling(fishing.state == "reel" and fishing.holding and not hud.is_open())
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
	if test_frames == 90:
		get_viewport().get_texture().get_image().save_png(test_shot)
		get_tree().quit()
	return true

func _doors() -> void:
	if player.in_boat(): return
	for k in ["shop", "home", "marina"]:
		var door: Vector2 = { "shop": LOU_DOOR, "home": HOME_DOOR, "marina": MARINA_DOOR }[k]
		var d := player.position.distance_to(door)
		if d < 0.7 and not latch[k] and fishing.state == "idle":
			latch[k] = true; player.path.clear()
			if k == "shop": Sound.play("bell"); open_shop()
			elif k == "home": Sound.play("door"); open_home()
			else: open_marina()
		if d > 1.6: latch[k] = false

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
		elif b.kind in ["shop", "mega", "marina", "club", "office", "plant", "flat"] and b.label != "PARKING":
			var open_k := 0.95 if b.kind in ["shop", "mega", "marina", "club"] and h >= 17 and h < 22 else 0.3
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
	if view.has_point(Vector2(51.4, 31.6)): _glow(ci, Vector2(51.4, 31.4), 1.4, Color(1, 0.3, 0.25, 0.4 * a))

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
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			fishing.action_up(); return
		var wp: Vector2 = get_global_mouse_position() / TS
		if fishing.state == "power" and fishing.is_water(wp) and wp.distance_to(player.position) <= Fishing.MAXR + 0.6:
			var pw := fishing.power
			var tt := fishing.t
			fishing.start_cast(wp); fishing.power = pw; fishing.t = tt
			return
		if fishing.state != "idle": _action_down(); return
		if not Unlocks.open_p(wp): hud.flash("Road closed for now. " + Unlocks.goal() + ". Press M for the map.")
		if fishing.near_water() and fishing.is_water(wp) and wp.distance_to(player.position) <= Fishing.MAXR + 0.6:
			fishing.start_cast(wp); return
		player.walk_to(wp)

func _action_down() -> void:
	if hud.is_open(): return
	if fishing.state == "idle":
		if near == "shop": Sound.play("bell"); open_shop()
		elif near == "home": Sound.play("door"); open_home()
		elif near == "marina": Sound.play("door"); open_marina()
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
	else: hud.flash("You don't have a boat. Lou sells kayaks; the marina downtown sells a skiff.")

func _cycle_bait() -> void:
	var o := Game.owned_baits()
	if o.size() < 2: hud.flash("Only worms so far. Lou sells shrimp, lures, hot dogs and bread."); return
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
	Unlocks.on_catch(c)
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
	var S := Game.S
	var sc := Story.scene()
	if not sc.is_empty(): open_card(sc); return
	var tabs := []
	var story_on: bool = int(S.saga.ch) > 0
	if shop_tab == "note" and not story_on: shop_tab = "sell"
	for td in [["sell", "Sell"], ["order", "Today's order"], ["gear", "Gear"], ["story", "Tell a story"]] + ([["note", "Lou's note"]] if story_on else []):
		var key: String = td[0]
		tabs.append([td[1], func(): shop_tab = key; open_shop(), shop_tab == key])
	var parts := [["h3", "Lou's Bait & Tackle · since 1977"], ["h2", "\"%s\"" % ["What'd you catch?", "Wipe your feet.", "Back again?", "Don't touch the shrimp.", "Tell me it's a big one."].pick_random()], ["tabs", tabs]]
	match shop_tab:
		"sell":
			if S.cooler.is_empty():
				parts.append(["sub", ("Sold for %s. " % Game.money(last_sale) if last_sale else "") + "Your cooler is empty. Lou buys anything with fins, and some things without."])
			else:
				var total := 0
				for c in S.cooler:
					total += int(c.value)
					var cc: Dictionary = c
					if c.junk:
						parts.append(["item", c.n, "%s lb · %s · Lou pays %s, or strip it for %s" % [str(c.w), Game.spots[int(c.spot)].name, Game.money(c.value), Crafting.PARTS[Crafting.salvage_part(c.n)].to_lower()],
							"Strip for parts", func(): hud.flash(Crafting.salvage(cc)); open_shop(), true, func(ci, r): ItemIcons.draw_catch(ci, cc, r)])
					else:
						parts.append(["item", c.n + (" ★" if c.legend else ""), "%s lb · %s" % [str(c.w), Game.spots[int(c.spot)].name], Game.money(c.value), func(): pass, false,
							func(ci, r): ItemIcons.draw_catch(ci, cc, r)])
				parts.append(["row", [["Sell everything for " + Game.money(total), _sell_all, true, "go"]]])
			last_sale = 0
			if Unlocks.step() == 1 and Story.species_got() < Unlocks.SPECIES_2:
				var tips := Unlocks.lou_tips(3)
				if not tips.is_empty():
					parts.append(["p", "Lou: \"You need more kinds of fish to get out of this neighborhood. Here's what's biting around here.\""])
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

func _gear_list(parts: Array, list: Array) -> void:
	var S := Game.S
	var cmax := 20 + (10 if S.gear.has("mcooler") else 0)
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
	var best = null
	for c in Game.S.cooler:
		total += int(c.value)
		if not c.junk and (best == null or c.value > best.value or (c.legend and not best.legend)): best = c
	Game.S.cash += total
	if total > 0: Sound.play("cash")
	if best != null and (Game.S.story.is_empty() or int(Game.S.story_day) != int(Game.S.day) or best.value > Game.S.story.value):
		Game.S.story = best; Game.S.story_day = Game.S.day; Game.S.story_told = false
	Game.S.cooler = []
	last_sale = total
	Game.save_game()
	open_shop()

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
	if gid == "cooler": Game.S.cooler_cap = mini(20 + (10 if Game.S.gear.has("mcooler") else 0), Game.S.cooler_cap + 5)
	elif gid == "mcooler": Game.S.gear.mcooler = 1; Game.S.cooler_cap += 10
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
		["sub", "Offense #%d here. Fines go up each time. Try hiding in bushes, waiting for patrols to turn, or a disguise from Lou's." % n],
		["row", [["Walk it off", func(): hud.close(), true, "hot"]]]])

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
	var u := Unlocks.chip()
	if u != "": out.append([u, "sea"])
	var o = Game.cur_order()
	if o != null:
		out.append(["Lou's order: done ✓" if Game.S.order.done else "Lou wants: %s (%d/%d)" % [o.s, mini(Game.order_matches().size(), int(o.count)), int(o.count)], "paper"])
	if Game.tide_day():
		out.append(["King tide! Low Street is flooded" if Game.flooded() else "King tide today, 10 AM to 2 PM" if Game.hour() < 10 else "King tide is over for today", "sea"])
	else:
		var d := 3 - int(Game.S.day) % 4
		out.append(["Next king tide: " + ("in %d days" % (4 + d) if d <= 0 else "tomorrow" if d == 1 else "in %d days" % d), "sea"])
	out.append(["Weather: " + Weather.label(), "ink"])
	var tc := Story.tour_chip()
	if tc != "": out.append([tc, "paper"])
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
	# bridges
	for b in Town.bridges:
		if not reg.has_point(Vector2(b.x0, b.y0)): continue
		var w: float = b.x1 - b.x0 + 1
		if b.get("h", false):
			if b.get("foot", false): ci.draw_rect(Rect2(b.x0, b.y0, w, b.y1 - b.y0 + 1), Color("#d8d1c1"))
			elif b.get("road", false): ci.draw_rect(Rect2(b.x0, b.y0, w, b.y1 - b.y0 + 1), Color("#4b5058"))
			else:
				ci.draw_rect(Rect2(b.x0, b.y0, w, 1), Color("#d8d1c1")); ci.draw_rect(Rect2(b.x0, b.y1, w, 1), Color("#d8d1c1"))
				ci.draw_rect(Rect2(b.x0, b.y0 + 1, w, b.y1 - b.y0 - 1), Color("#4b5058"))
			ci.draw_rect(Rect2(b.x0, b.y0, w, 0.12), Color("#8b8f96")); ci.draw_rect(Rect2(b.x0, b.y1 + 0.88, w, 0.12), Color("#8b8f96"))
			ci.draw_rect(Rect2(b.x0, b.y1 + 1, w, 0.3), Color(0, 0, 0, 0.25))
			continue
		var hh: float = b.y1 - b.y0 + 1
		ci.draw_rect(Rect2(b.x0 + 1, b.y0, b.x1 - b.x0 - 1, hh), Color("#4b5058"))
		ci.draw_rect(Rect2(b.x0, b.y0, 1, hh), Color("#d8d2c4")); ci.draw_rect(Rect2(b.x1, b.y0, 1, hh), Color("#d8d2c4"))
		ci.draw_rect(Rect2(b.x0, b.y0, 0.14, hh), Color("#8b8f96")); ci.draw_rect(Rect2(b.x1 + 0.86, b.y0, 0.14, hh), Color("#8b8f96"))
		ci.draw_rect(Rect2(b.x1 + 1, b.y0, 0.35, hh), Color(0, 0, 0, 0.25))
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
			var near_house := r.position + (Vector2(r.size.x / 2, 1.0) if d.y == 1 else Vector2(r.size.x / 2, r.size.y - 1.0) if d.y == -1 else Vector2(r.size.x - 1.0, r.size.y / 2) if d.x == -1 else Vector2(1.0, r.size.y / 2))
			Art.car(ci, near_house, (Vector2(d) * -1.0).angle() if Town.hash2(int(r.position.y), 5) > 0.5 else Vector2(d).angle(), col, 1.6, 0.78)
	# parked cars in the lots
	for d in Town.decor:
		if d.k != "parking": continue
		for x in range(d.x0, d.x1 + 1):
			if not reg.has_point(Vector2(x, d.y0)): continue
			var hh := Town.hash2(x * 17, d.y0 * 5)
			if hh > 0.55: continue
			var col := Color(Art.CAR_COLORS[int(Town.hash2(x, d.y0 * 3) * Art.CAR_COLORS.size())])
			var cyy: float = d.y0 + 1.15 + (0.12 if hh > 0.3 else 0.0)
			Art.car(ci, Vector2(x + 0.53, cyy), PI / 2 if hh > 0.2 else -PI / 2, col, 1.65, 0.8)
	# fences, walls and gates
	for y in range(int(reg.position.y), mini(int(reg.end.y), Town.MH)):
		for x in range(int(reg.position.x), mini(int(reg.end.x), Town.MW)):
			var t: int = Town.tile[Town.idx(x, y)]
			match t:
				Town.T.FENCE, Town.T.GATE, Town.T.GAP:
					var hor := Town.t_at(x - 1, y) == Town.T.FENCE or Town.t_at(x + 1, y) == Town.T.FENCE
					var a := Vector2(x, y + 0.5) if hor else Vector2(x + 0.5, y)
					var b2 := Vector2(x + 1, y + 0.5) if hor else Vector2(x + 0.5, y + 1)
					if t == Town.T.FENCE:
						ci.draw_line(a + Vector2(0.06, 0.08), b2 + Vector2(0.06, 0.08), Color(0, 0, 0, 0.18), 0.08)
						ci.draw_line(a, b2, Color("#c9ced2"), 0.08)
						ci.draw_rect(Rect2(x, y + 0.42, 0.14, 0.16) if hor else Rect2(x + 0.42, y, 0.16, 0.14), Color("#8b9196"))
					elif t == Town.T.GATE:
						ci.draw_rect(Rect2(x, y + 0.38, 0.16, 0.24) if hor else Rect2(x + 0.38, y, 0.24, 0.16), Color("#8b9196"))
						ci.draw_rect(Rect2(x + 0.84, y + 0.38, 0.16, 0.24) if hor else Rect2(x + 0.38, y + 0.84, 0.24, 0.16), Color("#8b9196"))
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

func _draw_labels(ci: CanvasItem) -> void:
	var ink := Color("#22313a")
	var paper := Color(0.98, 0.95, 0.89, 0.9)
	for g in Town.signs:
		ci.draw_rect(Rect2(g.x - 0.04, g.y - 0.1, 0.08, 0.5), Color("#6b5034"))
		ci.draw_rect(Rect2(g.x - 0.62, g.y - 0.55, 1.24, 0.5), Color("#c93b2a"))
		Art.text(ci, Vector2(g.x, g.y - 0.2), "NO FISHING", 0.2, Color.WHITE)
	for l in Town.labels: Art.text(ci, Vector2(l.x, l.y), l.t, 0.5, ink, paper)
	for b in Town.buildings:
		if b.label == "" or b.kind == "shop": continue
		var pos := Vector2(b.x + b.w / 2.0, b.y - 0.35)
		if b.kind == "sky":
			var g := Art.sky_geom(b)
			pos = Vector2(b.x + g.y + b.w / 2.0, b.y - g.x - 0.35)
		Art.text(ci, pos, b.label, 0.4, ink, paper)

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
	if view.has_point(Vector2(51.4, 31.6)): Art.text(ci, Vector2(51.4, 31.6), "OPEN", 0.4, Color(1, 0.4, 0.33, 0.9))

## Gulls wheeling over the water by day.
const GULL_SPOTS := [Vector2(95, 162), Vector2(20, 163), Vector2(32, 52), Vector2(52, 170), Vector2(30, 166), Vector2(79, 128), Vector2(61, 101), Vector2(88, 14), Vector2(70, 52), Vector2(105, 79), Vector2(60, 176)]

func _draw_gulls(ci: CanvasItem) -> void:
	var h := Game.hour()
	if h < 6.3 or h > 19.6 or Game.wx.rain > 0.5: return
	var view := _view_tiles().grow(3)
	var t := Time.get_ticks_msec() / 1000.0
	var birds := []
	for i in GULL_SPOTS.size():
		var c: Vector2 = GULL_SPOTS[i]
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
			var keys := Game.spots.keys(); keys.sort()
			for k in keys:
				var s: Dictionary = Game.spots[k]
				var visited: bool = S.visited.has(str(k)) or s.fish.any(func(f): return S.journal.has(f.n) and int(S.journal[f.n].spot) == int(k))
				parts.append(["head", s.name, "Visited" if visited else "Not visited yet"])
				parts.append(["chips", s.fish.map(func(f):
					var j: Variant = S.journal.get(f.n)
					var leg: bool = f.get("legend", false)
					var txt: String = (f.n if j != null or not leg else "???") + (" · %s lb" % str(j.w) if j != null else "")
					return [txt, "got" if j != null else "leg" if leg else ""])])
	parts.append(["row", [["Close", func(): hud.close(), true, "hot"], ["Map (M)", open_map]]])
	hud.open(parts)

# ---------- the map ----------
var map_view: MapView
func open_map() -> void:
	map_view = MapView.new(self)
	map_view.locked = Unlocks.map_overlay() if Unlocks.step() < Unlocks.LAST else null
	map_view.custom_minimum_size = Vector2(0, get_viewport_rect().size.y - 250)
	hud.open([["h3", "Port Mullet · drag to move, scroll or + and − to zoom"], ["node", map_view],
		["sub", "Zoom in for street names and how many of each spot's fish you've caught. Lou's is on US-1; downtown and the bay are way down south." + ("" if Unlocks.step() >= Unlocks.LAST else " Grey: closed for now. " + Unlocks.goal() + ".")],
		["row", [["Close", func(): hud.close(), true, "hot"], ["Journal (J)", open_journal]]]], true)

# ---------- the Route 1 bus ----------
func open_bus(i: int) -> void:
	var parts := [["h3", "Route 1 bus · " + Story.BUS[i][0]], ["h2", "\"Exact change, pal.\""],
		["p", "Two dollars to anywhere on the line. The ride takes about 25 minutes, and the driver doesn't want to hear about your fish."]]
	for j in Story.BUS.size():
		if j == i: continue
		var jj := j
		var open := Unlocks.open_p(Story.BUS[j][1])
		parts.append(["item", Story.BUS[j][0], Story.BUS[j][2] if open else "Road closed for now. " + Unlocks.goal() + ".", "Ride ($2)" if open else "Closed", func(): _ride_bus(jj), Game.S.cash >= 2 and open])
	parts.append(["row", [["Walk instead", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

func _ride_bus(i: int) -> void:
	if Game.S.cash < 2: return
	hud.close()
	menu.fade(func(): _arrive_bus(i), 0.35, 0.6)

func _arrive_bus(i: int) -> void:
	Sound.play("bus")
	Game.S.cash -= 2
	Game.skip_minutes(25)
	Game.S.boat = false
	player.position = Story.BUS[i][1]; player.path.clear()
	cam.position = player.position * TS; cam.reset_smoothing()
	for w in guards.watchers: w.alert = 0.0
	hud.close(); hud.flash("The bus wheezes to a stop: %s." % Story.BUS[i][0]); Game.save_game()

static func draw_bus_stop(ci: CanvasItem, p: Vector2) -> void:
	p = p - Vector2(0, 0.5)
	ci.draw_rect(Rect2(p.x - 0.5, p.y - 0.1, 1.25, 0.42), Color(0, 0, 0, 0.2))
	ci.draw_rect(Rect2(p.x - 0.6, p.y - 0.3, 1.2, 0.36), Color("#2b7ea6"))
	ci.draw_rect(Rect2(p.x - 0.52, p.y - 0.24, 1.04, 0.12), Color("#9fd3f0"))
	ci.draw_rect(Rect2(p.x - 0.45, p.y + 0.04, 0.9, 0.1), Color("#8a5a35"))
	ci.draw_rect(Rect2(p.x + 0.66, p.y - 0.5, 0.05, 0.7), Color("#6b5034"))
	ci.draw_circle(Vector2(p.x + 0.685, p.y - 0.55), 0.18, Color("#2b7ea6"))
	Art.text(ci, Vector2(p.x + 0.685, p.y - 0.51), "BUS", 0.13, Color.WHITE)
