class_name Menu
extends CanvasLayer
## The title screen, the pause menu, the controls and settings cards, and screen fades.
## The title sits under the HUD layer, so the controls and settings cards open on top of it.

signal title_closed

const PAPER := Color("#fbf3e2")
const INK := Color("#22313a")
const CORAL := Color("#e2583e")
const SUN := Color("#f2b134")
const SETTINGS_PATH := "user://settings.cfg"
## Music styles, with the names the browser version's music picker used.
const STYLES := [["auto", "Auto"], ["surf", "Surf"], ["steel", "Steel drum"], ["prowl", "Night prowl"],
	["miami", "Miami nights"], ["swamp", "Swamp blues"], ["reactor", "Meltdown"], ["yacht", "Yacht rock"]]
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

const CONTROLS := [
	["WASD / arrows", "Walk. Or click where you want to go"],
	["F / Space", "Cast, hook the fish, hold to reel"],
	["◀ ▶ (A / D)", "Aim a cast, twitch the lure left or right, pull against a running fish"],
	["Click the water", "Cast right at that spot"],
	["E", "Talk, go through doors, ride the bus"],
	["B", "Switch bait"],
	["K", "Launch or land a kayak or skiff"],
	["J", "Journal: spots, Lou's Wall of Fame, the Gazette"],
	["M", "Map. Scroll or + and − to zoom, drag to move it"],
	["Esc", "Pause menu. Closes any card"],
	["F11", "Full screen on or off"],
]

var hud: Hud
var title: Control
var title_open := false
var fade_rect: ColorRect
var fade_layer: CanvasLayer
var settings := { "fullscreen": false, "size": 0, "vsync": true, "flashes": true, "gfx": 2, "master": 8, "music": 6, "sfx": 8, "ambience": 6, "style": "auto" }

func _ready() -> void:
	layer = 5
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.04, 0.08, 0.16, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	load_settings()

# ---------- fades ----------
## Fades to dark, runs fn, then fades back in.
func fade(fn: Callable, out_time := 0.3, in_time := 0.45) -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, out_time)
	tw.tween_callback(fn)
	tw.tween_interval(0.08)
	tw.tween_property(fade_rect, "color:a", 0.0, in_time)
	tw.tween_callback(func(): fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func fade_in(t := 0.8) -> void:
	fade_rect.color.a = 1.0
	create_tween().tween_property(fade_rect, "color:a", 0.0, t)

# ---------- title screen ----------
func show_title() -> void:
	title_open = true
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.theme = hud.theme_
	add_child(title)
	# a dusky wash over the town drifting by behind
	var wash := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.width = 64; gt.height = 64
	gt.fill_from = Vector2(0, 0.5); gt.fill_to = Vector2(1, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.1, 0.2, 0.86), Color(0.05, 0.1, 0.2, 0.6), Color(0.05, 0.1, 0.2, 0.08)])
	gt.gradient = g
	wash.texture = gt
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(wash)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 90; box.offset_top = -270; box.offset_right = 700; box.offset_bottom = 250
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	title.add_child(box)
	var kicker := Label.new()
	kicker.text = "PORT MULLET, FLORIDA"
	kicker.add_theme_font_override("font", Game.font_bold)
	kicker.add_theme_font_size_override("font_size", 15)
	kicker.add_theme_color_override("font_color", SUN)
	box.add_child(kicker)
	var logo := Label.new()
	logo.text = "Urban Fishing"
	logo.add_theme_font_override("font", Game.font_display)
	logo.add_theme_font_size_override("font_size", 86)
	logo.add_theme_color_override("font_color", PAPER)
	logo.add_theme_color_override("font_shadow_color", CORAL)
	logo.add_theme_constant_override("shadow_offset_x", 5)
	logo.add_theme_constant_override("shadow_offset_y", 6)
	box.add_child(logo)
	var tag := Label.new()
	tag.text = "Every pond in town has fish in it.\nHalf of them say NO FISHING."
	tag.add_theme_font_size_override("font_size", 19)
	tag.add_theme_color_override("font_color", Color(PAPER, 0.85))
	box.add_child(tag)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 8); box.add_child(gap)
	var has_save := false
	for n in range(1, Game.SLOTS + 1): if not Game.peek_slot(n).is_empty(): has_save = true
	if has_save:
		var cb := _title_button("Continue", "hot", func(): show_slots("load"))
		box.add_child(cb)
		var info := Label.new()
		info.text = "Last played: slot %d · %s" % [Game.slot, _slot_line(Game.S) if Game.S.started else "empty"]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(PAPER, 0.7))
		box.add_child(info)
	box.add_child(_title_button("New game", "" if has_save else "hot", func(): show_slots("new") if has_save else _start_fresh(Game.slot)))
	box.add_child(_title_button("Controls", "", func(): show_controls()))
	box.add_child(_title_button("Settings", "", func(): show_settings()))
	box.add_child(_title_button("Quit", "", func(): get_tree().quit()))
	var foot := Label.new()
	foot.text = "v" + Game.version + " · Esc for the menu any time · Fonts: Lilita One and Atkinson Hyperlegible (SIL OFL)"
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 90; foot.offset_top = -40
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(PAPER, 0.5))
	title.add_child(foot)
	# slide the menu in
	box.modulate.a = 0
	box.position.x -= 30
	var tw := create_tween().set_parallel()
	tw.tween_property(box, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tw.tween_property(box, "position:x", box.position.x + 30, 0.6).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(box.get_child(4) as Button).grab_focus.call_deferred()

func _title_button(text: String, style: String, cb: Callable) -> Button:
	var b := hud._button(text, cb, true, style)
	b.custom_minimum_size = Vector2(300, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func _continue() -> void:
	fade(func():
		title.queue_free(); title = null; title_open = false
		title_closed.emit())

## One line about a saved game: day, time, cash and rep.
func _slot_line(d: Dictionary) -> String:
	var m := float(d.get("min", 0.0))
	var h := int(fmod(m / 60.0, 24.0))
	return "Day %d · %d:%02d %s · %s · %d rep" % [int(d.get("day", 1)), 12 if h % 12 == 0 else h % 12, int(fmod(m, 60.0)), "AM" if h < 12 else "PM",
		Game.money(float(d.get("cash", 0))), int(d.get("rep", 0))]

## The save slot picker. mode "load" plays a slot, mode "new" starts a new game in one.
func show_slots(mode: String) -> void:
	var parts: Array = [["h3", "Save slots"], ["h2", "Pick a game" if mode == "load" else "New game: pick a slot"]]
	for n in range(1, Game.SLOTS + 1):
		var d := Game.peek_slot(n)
		var nn := n
		var label := "Slot %d%s" % [n, "  ·  last played" if n == Game.slot and not d.is_empty() else ""]
		if mode == "load":
			parts.append(["item", label, _slot_line(d) if not d.is_empty() else "Empty", "Play", func(): hud.close(); _play_slot(nn), not d.is_empty()])
		elif d.is_empty():
			parts.append(["item", label, "Empty", "Start here", func(): hud.close(); _start_fresh(nn), true])
		else:
			parts.append(["item", label, _slot_line(d), "Start over", func(): _confirm_overwrite(nn, d), true])
	parts.append(["sub", "Each slot is its own game. Playing one never touches the others."])
	parts.append(["row", [["Back", func(): hud.close(), true, "hot"]]])
	hud.open(parts)

func _confirm_overwrite(n: int, d: Dictionary) -> void:
	hud.open([["h3", "New game in slot %d" % n], ["h2", "Start over?"], ["p", "The game in slot %d (%s) will be erased. Your other slots stay as they are." % [n, _slot_line(d)]],
		["row", [["Keep it", func(): show_slots("new"), true, "hot"], ["Erase and start", func(): hud.close(); _start_fresh(n), true, "go"]]]])

func _play_slot(n: int) -> void:
	if n == Game.slot: _continue(); return
	fade(func():
		Game.use_slot(n)
		Game.skip_title = true
		get_tree().reload_current_scene(), 0.4)

func _start_fresh(n: int) -> void:
	fade(func():
		Game.use_slot(n)
		Game.reset()
		Game.skip_title = true
		get_tree().reload_current_scene(), 0.4)

func quit_to_title() -> void:
	Game.save_game()
	fade(func():
		Game.skip_title = false
		get_tree().reload_current_scene(), 0.4)

# ---------- pause menu ----------
func show_pause() -> void:
	hud.open([["h3", "Paused · Slot %d · Day %d · %s · v%s" % [Game.slot, int(Game.S.day), Game.clock_text(), Game.version]], ["h2", "Gone fishin'"],
		["row", [["Resume", func(): hud.close(), true, "hot"]]],
		["row", [["Controls", func(): show_controls(true)], ["Settings", func(): show_settings(true)]]],
		["row", [["Journal", func(): hud.close(); get_parent().open_journal()], ["Map", func(): hud.close(); get_parent().open_map()]]],
		["sub", "The game saves itself every few seconds and whenever you buy, sell or rest."],
		["row", [["Save and quit to title", func(): hud.close(); quit_to_title()], ["Quit game", func(): Game.save_game(); get_tree().quit(), true, "go"]]]])

# ---------- controls ----------
func show_controls(from_pause := false) -> void:
	hud.open([["h3", "How to play"], ["h2", "Controls"], ["keys", CONTROLS],
		["sub", "Fishing: release the cast in the green to land right on a fish. When the bobber dips, hook it fast. Then hold to reel, keep the tension needle in the green, and pull against the fish when it runs."],
		["row", [["Back", func(): show_pause() if from_pause else hud.close(), true, "hot"]]]])

# ---------- settings ----------
func show_settings(from_pause := false) -> void:
	var back := func(): show_settings(from_pause)
	var sizes := []
	for i in SIZES.size():
		var ii := i
		sizes.append(["%d × %d" % [SIZES[i].x, SIZES[i].y], func(): settings.size = ii; apply_settings(); back.call(), settings.size == ii])
	var styles := [[], []]
	for i in STYLES.size():
		var st: String = STYLES[i][0]
		styles[i / 4].append([STYLES[i][1], func(): settings.style = st; apply_settings(); back.call(), settings.style == st])
	var vol := func(k: String, label: String) -> Array:
		return ["vol", label, int(settings[k]), func(v): settings[k] = clampi(v, 0, 10); apply_settings(); back.call()]
	hud.open([["h3", "Settings"], ["h2", "Settings"],
		["head", "Graphics quality", "lower it if the game runs slowly"],
		["tabs", [["Low", func(): settings.gfx = 0; apply_settings(); back.call(), int(settings.gfx) == 0], ["Medium", func(): settings.gfx = 1; apply_settings(); back.call(), int(settings.gfx) == 1], ["High", func(): settings.gfx = 2; apply_settings(); back.call(), int(settings.gfx) == 2]]],
		["sub", ["Low: simpler water, no reflections, mist or puddles, still trees, fewer cars and people.", "Medium: most of the effects, a little simpler water, a few fewer cars and people.", "High: everything on."][clampi(int(settings.gfx), 0, 2)]],
		["head", "Sound"],
		vol.call("master", "Master"), vol.call("music", "Music"), vol.call("sfx", "Effects"), vol.call("ambience", "Ambience"),
		["head", "Music style", "Auto picks a tune for where you are"],
		["tabs", styles[0]], ["tabs", styles[1]],
		["head", "Display"],
		["tabs", [["Windowed", func(): settings.fullscreen = false; apply_settings(); back.call(), not settings.fullscreen], ["Full screen", func(): settings.fullscreen = true; apply_settings(); back.call(), settings.fullscreen]]],
		["head", "Window size", "used when windowed"],
		["tabs", sizes],
		["head", "VSync", "smooth frames, less tearing"],
		["tabs", [["On", func(): settings.vsync = true; apply_settings(); back.call(), settings.vsync], ["Off", func(): settings.vsync = false; apply_settings(); back.call(), not settings.vsync]]],
		["head", "Lightning flashes"],
		["tabs", [["On", func(): settings.flashes = true; apply_settings(); back.call(), settings.flashes], ["Off", func(): settings.flashes = false; apply_settings(); back.call(), not settings.flashes]]],
		["row", [["Back", func(): show_pause() if from_pause else hud.close(), true, "hot"]]]])

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings: settings[k] = cf.get_value("settings", k, settings[k])
	apply_settings(false)

func apply_settings(save := true) -> void:
	Game.flashes = settings.flashes
	Game.quality = clampi(int(settings.gfx), 0, 2)
	Drawer.still = Game.quality == 0
	Sound.style = settings.style if STYLES.any(func(x): return x[0] == settings.style) else "auto"
	Sound.set_volume("Master", settings.master / 10.0)
	Sound.set_volume("Music", settings.music / 10.0)
	Sound.set_volume("SFX", settings.sfx / 10.0)
	Sound.set_volume("Ambience", settings.ambience / 10.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	# the test hooks run at a fixed size; leave the window alone then
	if not OS.get_cmdline_user_args().is_empty(): return
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var sz: Vector2i = SIZES[clampi(int(settings.size), 0, SIZES.size() - 1)]
		var screen := DisplayServer.screen_get_usable_rect()
		sz = Vector2i(mini(sz.x, screen.size.x), mini(sz.y, screen.size.y))
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(screen.position + (screen.size - sz) / 2)
	if save:
		var cf := ConfigFile.new()
		for k in settings: cf.set_value("settings", k, settings[k])
		cf.save(SETTINGS_PATH)

func toggle_fullscreen() -> void:
	settings.fullscreen = not settings.fullscreen
	apply_settings()
