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
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

const CONTROLS := [
	["WASD / arrows", "Walk. Or click where you want to go"],
	["F / Space", "Cast, hook the fish, hold to reel"],
	["◀ ▶ (A / D)", "Aim a cast, twitch the lure, pull against a running fish"],
	["Click the water", "Cast right at that spot"],
	["E", "Talk, go through doors, ride the bus"],
	["B", "Switch bait"],
	["K", "Launch or land a kayak or skiff"],
	["J", "Journal: spots, Lou's Wall of Fame, the Gazette"],
	["M", "Map"],
	["Esc", "Pause menu. Closes any card"],
	["F11", "Full screen on or off"],
]

var hud: Hud
var title: Control
var title_open := false
var fade_rect: ColorRect
var fade_layer: CanvasLayer
var settings := { "fullscreen": false, "size": 0, "vsync": true, "flashes": true }

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
	var has_save: bool = Game.S.started
	if has_save:
		var cb := _title_button("Continue", "hot", func(): _continue())
		box.add_child(cb)
		var info := Label.new()
		info.text = "Day %d · %s · %s · %s" % [int(Game.S.day), Game.clock_text(), Game.money(Game.S.cash), Game.rep_title()]
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(PAPER, 0.7))
		box.add_child(info)
	box.add_child(_title_button("New game", "" if has_save else "hot", func(): new_game()))
	box.add_child(_title_button("Controls", "", func(): show_controls()))
	box.add_child(_title_button("Settings", "", func(): show_settings()))
	box.add_child(_title_button("Quit", "", func(): get_tree().quit()))
	var foot := Label.new()
	foot.text = "Esc for the menu any time · Fonts: Lilita One and Atkinson Hyperlegible (SIL OFL)"
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

func new_game() -> void:
	if Game.S.started:
		hud.open([["h3", "New game"], ["h2", "Start over?"], ["p", "Your current game (day %d, %s) will be erased." % [int(Game.S.day), Game.money(Game.S.cash)]],
			["row", [["Start over", func(): hud.close(); _start_fresh(), true, "go"], ["Keep my game", func(): hud.close(), true, "hot"]]]])
		return
	_start_fresh()

func _start_fresh() -> void:
	fade(func():
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
	hud.open([["h3", "Paused · Day %d · %s" % [int(Game.S.day), Game.clock_text()]], ["h2", "Gone fishin'"],
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
	hud.open([["h3", "Settings"], ["h2", "Settings"],
		["head", "Display"],
		["tabs", [["Windowed", func(): settings.fullscreen = false; apply_settings(); back.call(), not settings.fullscreen], ["Full screen", func(): settings.fullscreen = true; apply_settings(); back.call(), settings.fullscreen]]],
		["head", "Window size", "used when windowed"],
		["tabs", sizes],
		["head", "VSync", "smooth frames, less tearing"],
		["tabs", [["On", func(): settings.vsync = true; apply_settings(); back.call(), settings.vsync], ["Off", func(): settings.vsync = false; apply_settings(); back.call(), not settings.vsync]]],
		["head", "Lightning flashes"],
		["tabs", [["On", func(): settings.flashes = true; apply_settings(); back.call(), settings.flashes], ["Off", func(): settings.flashes = false; apply_settings(); back.call(), not settings.flashes]]],
		["sub", "There's no music or sound yet, so there's no volume setting yet."],
		["row", [["Back", func(): show_pause() if from_pause else hud.close(), true, "hot"]]]])

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings: settings[k] = cf.get_value("settings", k, settings[k])
	apply_settings(false)

func apply_settings(save := true) -> void:
	Game.flashes = settings.flashes
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
