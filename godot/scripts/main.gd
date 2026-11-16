extends Node2D
## Builds Port Mullet and runs the game loop: walking, fishing, the clock, night lights, Lou's and home.

const TS := Game.TS
const LOU_DOOR := Vector2(48.5, 32.4)
const HOME_DOOR := Vector2(8.75, 10.5)
const WATER_SHADER := """
shader_type canvas_item;
uniform sampler2D water_mask : filter_linear;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(water_mask, UV).r;
	if (m > 0.02) {
		vec2 p = UV * vec2(112.0, 184.0);
		float w = sin(p.x * 2.3 + TIME * 1.1 + sin(p.y * 1.7 + TIME * 0.8)) * sin(p.y * 2.9 - TIME * 0.9 + sin(p.x * 1.3 - TIME * 0.5));
		float caustic = smoothstep(0.55, 1.0, w);
		float glint = smoothstep(0.985, 1.0, sin(p.x * 7.0 + TIME * 2.0) * sin(p.y * 5.0 - TIME * 1.6));
		c.rgb += (caustic * 0.10 + glint * 0.35) * m;
	}
	COLOR = c;
}
"""

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
var latch := { "shop": false, "home": false }
var pending_catch = null
var shop_tab := "sell"
# test hook: godot --path . -- --at=x,y,hour --shot=out.png [--open=shop]
var test_shot := ""
var test_frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			var v := a.substr(5).split(",")
			Game.S.x = float(v[0]); Game.S.y = float(v[1]); Game.S.min = float(v[2]) * 60.0; Game.S.started = true
		if a.begins_with("--shot="): test_shot = a.substr(7)
	RenderingServer.set_default_clear_color(Color("#0b1a3a"))
	world = Node2D.new()
	world.scale = Vector2(TS, TS)
	add_child(world)
	# ground
	var ground := Sprite2D.new()
	ground.texture = Ground.make_texture()
	ground.centered = false
	ground.scale = Vector2.ONE / Ground.PX
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	var sh := Shader.new(); sh.code = WATER_SHADER; mat.shader = sh
	mat.set_shader_parameter("water_mask", Ground.make_water_mask())
	ground.material = mat
	ground.z_index = -10
	world.add_child(ground)
	for cy in ceili(Town.MH / 8.0):
		for cx in ceili(Town.MW / 8.0):
			var ch := GroundChunk.new(cx, cy)
			ch.z_index = -9
			world.add_child(ch)
	var statics := Drawer.make(_draw_statics)
	statics.z_index = -8
	world.add_child(statics)
	fishing = Fishing.new()
	fishing.z_index = -5
	world.add_child(fishing)
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
			"sky": n = Drawer.make(func(ci): Art.sky(ci, bb), bb.y + bb.h - 0.05)
			"house": n = Drawer.make(func(ci): Art.house(ci, bb), bb.y + bb.h - 0.05)
			"tower": n = Drawer.make(func(ci): Art.cooling_tower(ci, bb, Time.get_ticks_msec() / 1000.0), bb.y + bb.h - 0.05, true)
			"volcano": n = Drawer.make(func(ci): Art.volcano(ci, bb, Time.get_ticks_msec() / 1000.0), bb.y + bb.h - 0.05, true)
			_: n = Drawer.make(func(ci): Art.flat(ci, bb), bb.y + bb.h - 0.05)
		ents.add_child(n)
		if bb.kind == "sky":
			sky_nodes.append([n, bb])
			n.get_child(0).light_mask = 2    # street lamps light the street, not the rooftops
	for y in Town.MH:
		for x in Town.MW:
			var t: int = Town.tile[Town.idx(x, y)]
			var xx := x
			var yy := y
			if t == Town.T.TREE: ents.add_child(Drawer.make(func(ci): Art.tree(ci, xx, yy, Time.get_ticks_msec() / 1000.0), y + 0.9, true))
			elif t == Town.T.BUSH: ents.add_child(Drawer.make(func(ci): Art.bush(ci, xx, yy), y + 0.85))
	for a in [[Vector2(5.2, 18.2), 0.3], [Vector2(15.6, 22.8), 3.5], [Vector2(29.6, 162.5), PI], [Vector2(31.4, 160.2), 0.0], [Vector2(37.4, 49.4), -0.3]]:
		var p: Vector2 = a[0]
		var d: float = a[1]
		ents.add_child(Drawer.make(func(ci): Art.person(ci, p, d, Color("#f2b134"), Color("#c9a574"), true), p.y))
	ents.add_child(Drawer.make(func(ci):
		if Game.hour() >= 7 and Game.hour() < 19: Art.person(ci, Vector2(50.6, 32.55), 0.4, Color("#13807b"), Color("#e2583e")), 32.55, true))
	player = Player.new()
	ents.add_child(player)
	fishing.player = player
	var line := Drawer.make(fishing.draw_line_layer, 0, true)
	line.z_index = 5
	world.add_child(line)
	var labels := Drawer.make(_draw_labels)
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
	hud = Hud.new()
	hud.fishing = fishing
	add_child(hud)
	hud.action_pressed.connect(_action_down)
	hud.action_released.connect(func(): fishing.action_up())
	fishing.message.connect(hud.flash)
	fishing.landed.connect(_on_landed)
	get_viewport().size_changed.connect(_fit_zoom)
	_fit_zoom()
	if not Game.S.started: _intro()
	for a in OS.get_cmdline_user_args():
		if a == "--open=shop": open_shop()
		if a == "--open=gear": shop_tab = "gear"; open_shop()
		if a == "--cast": fishing.start_cast()
		if a == "--land": fishing.fish = Game.spots[1].fish[5]; fishing.fw = 44.2; fishing.spot = 1; fishing._land()

func _fit_zoom() -> void:
	var vs := get_viewport_rect().size
	var z := clampf(minf(vs.x, vs.y) / (15.0 * TS), 1.0, 2.2)
	cam.zoom = Vector2(z, z)

# ---------- loop ----------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
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
		_doors()
	near = ""
	if fishing.state == "idle":
		if player.position.distance_to(LOU_DOOR) < 1.3: near = "shop"
		elif player.position.distance_to(HOME_DOOR) < 1.0: near = "home"
		elif fishing.near_water(): near = "fish"
	cam.position = player.position * TS
	_lighting()
	for pair in sky_nodes:
		var b: Dictionary = pair[1]
		var g := Art.sky_geom(b)
		var behind: bool = player.position.x > b.x - 0.4 and player.position.x < b.x + b.w + g.y + 0.4 and player.position.y > b.y - g.x - 0.5 and player.position.y < b.y + b.h - 0.2
		pair[0].modulate.a = move_toward(pair[0].modulate.a, 0.36 if behind else 1.0, dt * 4)
	hud.refresh(near)
	if test_shot != "":
		test_frames += 1
		if test_frames == 90:
			get_viewport().get_texture().get_image().save_png(test_shot)
			get_tree().quit()
		return
	save_t += dt
	if save_t > 10: save_t = 0; Game.save_game()

func _doors() -> void:
	for k in ["shop", "home"]:
		var door: Vector2 = LOU_DOOR if k == "shop" else HOME_DOOR
		var d := player.position.distance_to(door)
		if d < 0.7 and not latch[k] and fishing.state == "idle":
			latch[k] = true; player.path.clear()
			if k == "shop": open_shop()
			else: open_home()
		if d > 1.6: latch[k] = false

func _lighting() -> void:
	var dk := Game.darkness()
	var h := Game.hour()
	var c := Color.WHITE.lerp(Color(0.3, 0.36, 0.6), dk / 0.62)
	var dusk := 0.0
	if h >= 16.5 and h < 19.5: dusk = sin((h - 16.5) / 3.0 * PI) * 0.18
	elif h >= 5.5 and h < 8: dusk = sin((h - 5.5) / 2.5 * PI) * 0.12
	c = c.lerp(Color(1, 0.72, 0.55), dusk)
	night.color = c
	var on := dk > 0.15
	var view := Rect2(cam.get_screen_center_position() - get_viewport_rect().size / cam.zoom / 2, get_viewport_rect().size / cam.zoom).grow(6 * TS)
	for l in lamp_lights:
		l.enabled = on and view.has_point(l.position)
		l.energy = dk * 1.6

# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if hud.is_open():
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE: hud.close()
		return
	if e is InputEventKey and not e.echo:
		var k: int = e.physical_keycode
		if k == KEY_SPACE or k == KEY_F or k == KEY_E:
			if e.pressed: _action_down()
			else: fishing.action_up()
		elif e.pressed and k == KEY_B: _cycle_bait()
		elif e.pressed and fishing.state == "wait" and (k == KEY_LEFT or k == KEY_A or k == KEY_RIGHT or k == KEY_D): fishing.action_down(); fishing.action_up()
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
		if fishing.near_water() and fishing.is_water(wp) and wp.distance_to(player.position) <= Fishing.MAXR + 0.6:
			fishing.start_cast(wp); return
		player.walk_to(wp)

func _action_down() -> void:
	if hud.is_open(): return
	if fishing.state == "idle":
		if near == "shop": open_shop()
		elif near == "home": open_home()
		elif near == "fish": fishing.start_cast()
		return
	fishing.action_down()

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
		["row", [["Go fishing", func(): Game.S.started = true; Game.save_game(); hud.close(), true, "hot"]]]])

func _on_landed(c: Dictionary) -> void:
	pending_catch = c
	var spot_name: String = Game.spots[c.spot].name
	var full: bool = Game.S.cooler.size() >= Game.S.cooler_cap
	var parts := [["h3", spot_name], ["h2", c.n + ("  ★ LEGEND" if c.legend else "") + ("  · new record" if c.record and not c.junk else "")],
		["kv", [["Weight", "%s lb" % str(c.w)], ["Value" if c.release else "Lou pays", "Priceless" if c.release else Game.money(c.value)], ["Your best", "%s lb" % str(Game.S.journal[c.n].w)]]]]
	if c.note != "": parts.append(["sub", c.note])
	if c.release:
		parts.append(["p", "You can't sell this. Let it go and the story is worth +%d rep." % c.rep])
		parts.append(["row", [["Let it go", _release, true, "hot"]]])
	else:
		parts.append(["row", [["Cooler's full" if full else "Into the cooler", _keep, not full, "hot"], ["Release it (+1 rep)", _release]]])
	hud.open(parts)
	Game.save_game()

func _keep() -> void:
	var c: Dictionary = pending_catch
	Game.S.cooler.append({ "n": c.n, "w": c.w, "value": c.value, "spot": c.spot, "legend": c.legend, "junk": c.junk })
	pending_catch = null; hud.close(); Game.save_game()

func _release() -> void:
	var c: Dictionary = pending_catch
	Game.S.rep += c.rep if c.release else 1
	pending_catch = null; hud.close(); Game.save_game()

func open_shop() -> void:
	var S := Game.S
	var tabs := [["Sell", func(): shop_tab = "sell"; open_shop(), shop_tab == "sell"], ["Gear", func(): shop_tab = "gear"; open_shop(), shop_tab == "gear"]]
	var parts := [["h3", "Lou's Bait & Tackle · since 1977"], ["h2", "\"%s\"" % ["What'd you catch?", "Wipe your feet.", "Back again?", "Don't touch the shrimp.", "Tell me it's a big one."].pick_random()], ["tabs", tabs]]
	if shop_tab == "sell":
		if S.cooler.is_empty():
			parts.append(["sub", "Your cooler is empty. Lou buys anything with fins, and some things without."])
		else:
			var total := 0
			for c in S.cooler:
				total += int(c.value)
				parts.append(["item", c.n + (" ★" if c.legend else ""), "%s lb · %s" % [str(c.w), Game.spots[int(c.spot)].name], Game.money(c.value), func(): pass, false])
			parts.append(["row", [["Sell everything for " + Game.money(total), _sell_all, true, "go"]]])
	else:
		for g in Game.gear:
			if g.has("where"): continue
			var gid: String = g.id
			var owned: bool = S.cooler_cap >= 20 if gid == "cooler" else S.gear.has(gid)
			var locked: bool = g.get("req") != null and not S.gear.has(g.get("req"))
			var price: int = g.price
			var btn := "Owned" if owned else "Needs the last rod" if locked else Game.money(price)
			parts.append(["item", g.n + (" (%d now)" % S.cooler_cap if gid == "cooler" else ""), g.ds, btn, func(): _buy(gid, price), not owned and not locked and S.cash >= price])
		parts.append(["sub", "Your rod: %s." % Game.rods[Game.rod_level()].name])
	parts.append(["kv", [["Cash", Game.money(S.cash)], ["Rep", str(int(S.rep))], ["Cooler", "%d/%d" % [S.cooler.size(), S.cooler_cap]]]])
	parts.append(["row", [["Back outside", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

func _sell_all() -> void:
	var total := 0
	for c in Game.S.cooler: total += int(c.value)
	Game.S.cash += total
	Game.S.cooler = []
	Game.save_game()
	open_shop()
	hud.flash("Lou counts it out: " + Game.money(total))

func _buy(gid: String, price: int) -> void:
	if Game.S.cash < price: return
	Game.S.cash -= price
	if gid == "cooler": Game.S.cooler_cap = mini(20, Game.S.cooler_cap + 5)
	else: Game.S.gear[gid] = 1
	for b in Game.baits:
		if b.get("gear", "") == gid: Game.S.bait = b.id
	Game.save_game()
	open_shop()

func open_home() -> void:
	var rest := func(h: float):
		var cur := floorf(Game.S.min / 1440.0)
		var target := cur * 1440.0 + h * 60.0
		if target <= Game.S.min + 1: target += 1440.0
		if floorf(target / 1440.0) != cur: Game.S.day += int(floorf(target / 1440.0) - cur)
		Game.S.min = target
		hud.close(); hud.flash("You rest until %s." % Game.clock_text()); Game.save_game()
	hud.open([["h3", "Home sweet home"], ["h2", ["The AC is on.", "Somebody left the TV on.", "It smells like bait in here.", "Home. Feet up."].pick_random()],
		["p", "Kick back until…"],
		["item", "Dawn", "The Lunker of the 7th bites at dawn.", "Rest until 6:00 AM", func(): rest.call(6.0), true],
		["item", "Noon", "Business hours. Lanyard time at the koi pond.", "Rest until 12:00 PM", func(): rest.call(12.0), true],
		["item", "Dusk", "The golf groundskeeper knocks off at 7.", "Rest until 5:30 PM", func(): rest.call(17.5), true],
		["item", "Night", "Old Whiskers and the Bridge Troll come out.", "Rest until 9:00 PM", func(): rest.call(21.0), true],
		["row", [["Back outside", func(): hud.close(), true, "hot"]]]])

# ---------- static drawings ----------
func _draw_statics(ci: CanvasItem) -> void:
	# bridges
	for b in Town.bridges:
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
	# fences, walls and gates
	for y in Town.MH:
		for x in Town.MW:
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
		if not view.intersects(Rect2(b.x, b.y - g.x, b.w + g.y, b.h + g.x)): continue
		var col := Color(1, 0.84, 0.51, 0.75 * dk / 0.62 * pair[0].modulate.a)
		var i := 0
		for r in b.wins:
			if Town.hash2(i, b.x * 7 + Game.S.day) < lit: ci.draw_rect(r, col)
			i += 1
		if b.get("ant", false) and int(t * 1.2 + b.x) % 2 == 0:
			ci.draw_circle(Vector2(b.x + g.y + b.w * 0.75, b.y - g.x + b.h * 0.4 - 1.1), 0.14, Color(1, 0.3, 0.23))
	for lp in Town.lamps:
		if view.has_point(lp): ci.draw_circle(lp, 0.16, Color(1, 0.9, 0.62, 0.8 * dk / 0.62))
	if view.has_point(Vector2(51.4, 31.6)): Art.text(ci, Vector2(51.4, 31.6), "OPEN", 0.4, Color(1, 0.4, 0.33, 0.9))
