class_name Hud
extends CanvasLayer
## Screen UI: the sun-bleached top bar, hints, the action button, the cast and reel meters,
## and the laminated pop-up cards (Lou's shop, catches, the intro).

signal action_pressed
signal action_released
signal boat_pressed

const PAPER := Color("#fbf3e2")
const PAPER2 := Color("#f3e6c9")
const INK := Color("#22313a")
const MUTED := Color("#5f6f75")
const CORAL := Color("#e2583e")
const SUN := Color("#f2b134")
const TEAL := Color("#13807b")
const LINE := Color("#dcc9a3")

var theme_ := Theme.new()
var top_labels := {}
var hint: Label
var action: Button
var meters: Control
var modal: Control
var card_box: VBoxContainer
var fishing: Fishing
var hint_t := 0.0
## Place-name prompts (Lou's, home, the marina, the bus stop) fade out after PLACE_SECS.
const PLACES := ["shop", "home", "marina", "fin", "bus"]
const PLACE_SECS := 5.0
var place_near := ""
var place_t := 0.0
var boat_text := ""
var chips: Array = []
var boat_btn: Button
var chip_box: VBoxContainer
var toast_panel: PanelContainer
var toast_mast: Label
var toast_head: Label
var toast_q: Array = []
var toast_t := 0.0
var saved_label: Label
var bar: PanelContainer
var bait_icon: Control

func _ready() -> void:
	layer = 10
	_build_theme()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_
	add_child(root)
	# top bar
	bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(PAPER, INK, 0, 0, Vector4(0, 0, 0, 4), CORAL))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	bar.add_child(hb)
	var brand := Label.new()
	brand.text = "Urban Fishing"
	brand.add_theme_font_size_override("font_size", 28)
	brand.add_theme_font_override("font", Game.font_display)
	brand.add_theme_color_override("font_color", CORAL)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(brand)
	for k in ["day", "cash", "rep", "cooler", "bait"]:
		if k == "bait":
			bait_icon = Control.new()
			bait_icon.custom_minimum_size = Vector2(34, 34)
			bait_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bait_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bait_icon.draw.connect(func(): ItemIcons.draw(bait_icon, Game.S.bait, Rect2(Vector2.ZERO, bait_icon.size)))
			hb.add_child(bait_icon)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		var a := Label.new(); a.add_theme_font_size_override("font_size", 11); a.add_theme_color_override("font_color", MUTED)
		var b := Label.new(); b.add_theme_font_size_override("font_size", 17); b.add_theme_font_override("font", Game.font_bold)
		v.add_child(a); v.add_child(b); hb.add_child(v)
		top_labels[k] = [a, b]
	# bottom dock
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.offset_left = -230; dock.offset_right = 230; dock.offset_top = -230; dock.offset_bottom = -18
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 10)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)
	chip_box = VBoxContainer.new()
	chip_box.position = Vector2(16, 66)
	chip_box.add_theme_constant_override("separation", 6)
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chip_box)
	boat_btn = Button.new()
	boat_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boat_btn.focus_mode = Control.FOCUS_NONE
	boat_btn.add_theme_font_size_override("font_size", 14)
	var tb: StyleBoxFlat = theme_.get_stylebox("normal", "Button").duplicate()
	tb.bg_color = TEAL
	boat_btn.add_theme_stylebox_override("normal", tb); boat_btn.add_theme_stylebox_override("hover", tb)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]: boat_btn.add_theme_color_override(k, Color.WHITE)
	boat_btn.pressed.connect(func(): boat_pressed.emit())
	meters = Control.new()
	meters.custom_minimum_size = Vector2(460, 112)
	meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meters.draw.connect(_draw_meters)
	dock.add_child(meters)
	dock.add_child(boat_btn)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_stylebox_override("normal", _box(Color(INK, 0.82), Color(0, 0, 0, 0), 999, 0, Vector4.ZERO, Color.TRANSPARENT, 10, 5))
	hint.add_theme_font_size_override("font_size", 14)
	dock.add_child(hint)
	action = Button.new()
	action.custom_minimum_size = Vector2(230, 54)
	action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", 21)
	action.button_down.connect(func(): action_pressed.emit())
	action.button_up.connect(func(): action_released.emit())
	action.focus_mode = Control.FOCUS_NONE
	dock.add_child(action)
	# the Gazette / Wall of Fame pop-up, top right
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _box(PAPER, INK, 6, 2, Vector4.ZERO, Color.TRANSPARENT, 14, 10, 4))
	toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left = -376; toast_panel.offset_right = -16; toast_panel.offset_top = 66
	toast_panel.custom_minimum_size = Vector2(360, 0)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 4)
	toast_mast = _label("", 11, CORAL); toast_mast.add_theme_font_override("font", Game.font_bold)
	var rule := ColorRect.new(); rule.color = INK; rule.custom_minimum_size = Vector2(0, 2)
	toast_head = _label("", 19, INK); toast_head.add_theme_font_override("font", Game.font_display)
	tv.add_child(toast_mast); tv.add_child(rule); tv.add_child(toast_head)
	toast_panel.add_child(tv)
	root.add_child(toast_panel)
	# the autosave indicator, bottom right
	saved_label = Label.new()
	saved_label.text = "✓ Saved"
	saved_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	saved_label.offset_left = -120; saved_label.offset_top = -46; saved_label.offset_right = -16; saved_label.offset_bottom = -16
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved_label.add_theme_font_override("font", Game.font_bold)
	saved_label.add_theme_font_size_override("font_size", 13)
	saved_label.add_theme_color_override("font_color", Color.WHITE)
	saved_label.add_theme_stylebox_override("normal", _box(Color(INK, 0.8), Color(0, 0, 0, 0), 999, 0, Vector4.ZERO, Color.TRANSPARENT, 10, 4))
	saved_label.modulate.a = 0
	root.add_child(saved_label)
	# modal card
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	root.add_child(modal)
	var dim := ColorRect.new(); dim.color = Color(0.04, 0.1, 0.23, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, INK, 16, 3, Vector4.ZERO, Color.TRANSPARENT, 22, 18, 6))
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	card_box = VBoxContainer.new()
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.add_theme_constant_override("separation", 12)
	scroll.add_child(card_box)
	scroll.resized.connect(func(): scroll.custom_minimum_size.y = minf(card_box.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 120))
	card_box.resized.connect(func(): scroll.custom_minimum_size.y = minf(card_box.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 120))

func _box(bg: Color, border: Color, radius: int, bw: int, sides := Vector4.ZERO, side_col := Color.TRANSPARENT, px := 16, py := 8, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	if sides != Vector4.ZERO:
		s.border_color = side_col
		s.border_width_left = int(sides.x); s.border_width_top = int(sides.y); s.border_width_right = int(sides.z); s.border_width_bottom = int(sides.w)
	s.content_margin_left = px; s.content_margin_right = px; s.content_margin_top = py; s.content_margin_bottom = py
	if shadow:
		s.shadow_color = INK; s.shadow_size = 0; s.shadow_offset = Vector2(0, shadow)
	return s

func _build_theme() -> void:
	theme_.default_font = Game.font_body
	theme_.set_font("font", "Button", Game.font_display)
	theme_.set_color("font_color", "Label", INK)
	theme_.set_font_size("font_size", "Label", 16)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg := PAPER
		if st == "hover": bg = Color.WHITE
		if st == "pressed": bg = SUN
		var b := _box(bg, INK, 10, 2, Vector4.ZERO, Color.TRANSPARENT, 14, 8)
		if st != "pressed": b.shadow_color = INK; b.shadow_offset = Vector2(0, 3)
		if st == "disabled": b.bg_color = Color(PAPER, 0.5); b.border_color = Color(INK, 0.35); b.shadow_color = Color(INK, 0.3)
		if st == "focus": b.bg_color = Color(0, 0, 0, 0); b.border_color = Color("#2b7ea6"); b.set_border_width_all(3); b.shadow_color = Color(0, 0, 0, 0)
		theme_.set_stylebox(st, "Button", b)
	theme_.set_color("font_color", "Button", INK)
	theme_.set_color("font_hover_color", "Button", INK)
	theme_.set_color("font_focus_color", "Button", INK)
	theme_.set_color("font_hover_pressed_color", "Button", INK)
	theme_.set_color("font_pressed_color", "Button", INK)
	theme_.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	theme_.set_font_size("font_size", "Button", 16)

# ---------- per-frame ----------
func refresh(near: String) -> void:
	var S := Game.S
	var band := Game.time_band()
	var h := Game.hour()
	top_labels.day[0].text = "DAY %d · %s" % [S.day, ("DAWN" if h < 12 else "DUSK") if band == "low" else band.to_upper()]
	top_labels.day[1].text = Game.clock_text()
	top_labels.cash[0].text = "CASH"; top_labels.cash[1].text = Game.money(S.cash)
	top_labels.rep[0].text = Game.rep_title().to_upper(); top_labels.rep[1].text = "%d rep" % S.rep
	top_labels.cooler[0].text = "COOLER"; top_labels.cooler[1].text = "%d / %d" % [S.cooler.size(), S.cooler_cap]
	top_labels.bait[0].text = "BAIT (B)"; top_labels.bait[1].text = Game.bait_name()
	if bait_icon.get_meta("id", "") != Game.S.bait: bait_icon.set_meta("id", Game.S.bait); bait_icon.queue_redraw()
	var st := fishing.state
	action.visible = st != "idle" or near != ""
	var label := ""
	var col := SUN
	match st:
		"idle":
			label = { "fish": "Cast", "shop": "Go in" if Town.level == 1 else "Enter Lou's", "home": "Go inside", "marina": "Enter the marina", "fin": "Peek inside" if Fintastic.closed() else "Enter FINTASTIC!", "oldtimer": "Talk to the old-timer", "rosa": "Talk to Walt" if Town.level == 1 else "Talk to Rosa", "bus": "Ride the bus", "part": "Pick it up",
				"manhole": "Fish the manhole" if S.gear.has("prybar") else "Lift the cover" }.get(near, "")
			if near.begins_with("buy:"):
				var bd := Buyers.by_id(near.substr(4))
				label = ("Go in" if Buyers.open_now(bd) else "Closed: look in") if not bd.is_empty() else ""
			elif near.begins_with("board:"): label = "Read the price board"; col = TEAL
			if near in ["oldtimer", "rosa", "marina", "bus", "part"]: col = TEAL
		"power": label = "Release!"
		"wait": label = ("Pulling up…" if fishing.holding else "Jig the line") if fishing.manhole >= 0 else "Retrieving…" if fishing.holding else "Twitch the lure"; col = PAPER
		"nibble": label = "Wait for it…"; col = PAPER
		"bite": label = "HOOK IT!"; col = CORAL
		"reel": label = "Reeling…" if fishing.holding else "Hold to reel"; col = CORAL if fishing.holding else SUN
	action.text = label
	var bs: StyleBoxFlat = theme_.get_stylebox("normal", "Button").duplicate()
	bs.bg_color = col
	action.add_theme_stylebox_override("normal", bs)
	action.add_theme_stylebox_override("hover", bs)
	action.add_theme_color_override("font_color", Color.WHITE if col == CORAL else INK)
	action.add_theme_color_override("font_hover_color", Color.WHITE if col == CORAL else INK)
	action.add_theme_color_override("font_pressed_color", Color.WHITE if col == CORAL else INK)
	var dt := get_process_delta_time()
	if st == "idle" and (near in PLACES or near.begins_with("buy:") or near.begins_with("board:")):
		if near != place_near: place_near = near; place_t = 0.0
		place_t += dt
	else: place_near = ""; place_t = 0.0
	hint.modulate.a = 1.0
	if hint_t > 0: hint_t -= dt
	else:
		var m := ""
		match st:
			"idle": m = { "fish": "Cooler's full. Sell at Lou's." if S.cooler.size() >= S.cooler_cap else "Press F or Space to cast. B switches bait.", "shop": "Calder River Outfitters. Press E or F to go in." if Town.level == 1 else "Lou's Bait & Tackle. Press E or F to go in.", "home": "Riverview Motor Inn. Press E or F to get a room." if Town.level == 1 else "Home. Press E or F to go inside.", "marina": "Mullet Bay Marina. Press E to go in.", "fin": "FINTASTIC! is closed for rebranding. Press E to look in." if Fintastic.closed() else "FINTASTIC! Outdoor Megastore. Press E to go in.", "oldtimer": "Press E to talk.", "rosa": "Press E to talk.", "bus": ("Calder Line bus stop. Press E to ride, or take the coach home." if Town.level == 1 else "Route 1 bus stop. Press E to ride.") + " M for the map, J for the journal.", "part": "Something shiny on the ground. Press E to pick it up.",
				"manhole": ("Cooler's full. Sell at Lou's." if S.cooler.size() >= S.cooler_cap else "A manhole. Press F to drop a line down it.") if S.gear.has("prybar") else "A manhole. The cover's too heavy. Lou sells a pry bar." }.get(near, "")
			"power": m = "Release in the green to land right on the marker. Arrows or the mouse move it." if fishing.over != null else "Move the marker onto a fish with the arrows or the mouse, then release in the green."
			"wait": m = "Tap to jig the line. Hold to pull it back up." if fishing.manhole >= 0 else "Something's coming over…" if fishing.target != null else "Tap to twitch the lure toward you, ◀ ▶ to twitch it in, left or right. Hold to reel it back in."
			"nibble": m = "It's nibbling… wait for the big dip."
			"bite": m = "NOW!"
			"reel": m = "Hold to reel. Keep the needle in the green. Pull ◀ ▶ against the fish."
		if st == "idle" and (near.begins_with("buy:") or near.begins_with("board:")):
			var bd := Buyers.by_id(near.get_slice(":", 1))
			if not bd.is_empty():
				if near.begins_with("board:"): m = "%s's price board. Press E to read today's prices." % bd.name
				else: m = "%s. %s %s. Press E to go in." % [bd.name, "Open" if Buyers.open_now(bd) else "Closed. Open", Buyers.hours_text(bd)]
		if place_near != "":
			if place_t >= PLACE_SECS: m = ""
			else: hint.modulate.a = clampf((PLACE_SECS - place_t) / 0.6, 0.0, 1.0)
		hint.text = m
	hint.visible = hint.text != ""
	meters.visible = st == "power" or st == "reel"
	boat_btn.visible = boat_text != ""
	boat_btn.text = boat_text
	_update_chips()
	_update_toast()
	meters.queue_redraw()

func show_saved() -> void:
	var tw := create_tween()
	tw.tween_property(saved_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.2)
	tw.tween_property(saved_label, "modulate:a", 0.0, 0.6)

func toast(text: String, mast: String) -> void:
	toast_q.append([text, mast])

func _update_toast() -> void:
	var dt := get_process_delta_time()
	if toast_t > 0:
		toast_t -= dt
		toast_panel.modulate.a = clampf(minf(toast_t, 5.0 - toast_t) * 3.0, 0, 1)
		if toast_t <= 0: toast_panel.visible = false
		return
	if toast_q.is_empty() or is_open(): return
	var t: Array = toast_q.pop_front()
	toast_head.text = t[0]; toast_mast.text = t[1]
	Sound.play("plaque" if t[1].begins_with("LOU'S WALL") else "paper")
	toast_panel.visible = true; toast_t = 5.0

func _update_chips() -> void:
	while chip_box.get_child_count() < chips.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_font_override("font", Game.font_bold)
		chip_box.add_child(l)
	for i in chip_box.get_child_count():
		var l: Label = chip_box.get_child(i)
		l.visible = i < chips.size()
		if not l.visible: continue
		var c: Array = chips[i]
		if l.text != c[0] or l.get_meta("style", "") != c[1]:
			l.text = c[0]; l.set_meta("style", c[1])
			var bg: Color = { "paper": PAPER, "sea": Color("#2b7ea6"), "ink": INK, "coral": CORAL }[c[1]]
			l.add_theme_stylebox_override("normal", _box(bg, INK, 8, 2, Vector4.ZERO, Color.TRANSPARENT, 10, 5))
			l.add_theme_color_override("font_color", INK if c[1] == "paper" else Color.WHITE)

func flash(text: String) -> void:
	hint.text = text; hint.visible = true; hint_t = 2.6

func _draw_meters() -> void:
	var f := fishing
	if f == null or not (f.state == "power" or (f.state == "reel" and f.fish != null)): return
	var W := meters.size.x
	var font: Font = Game.font_bold
	meters.draw_style_box(_box(PAPER, INK, 14, 2, Vector4.ZERO, Color.TRANSPARENT, 0, 0, 4), Rect2(Vector2.ZERO, meters.size))
	if f.state == "power":
		meters.draw_string(font, Vector2(16, 30), "CAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		var r := Rect2(16, 44, W - 32, 22)
		meters.draw_rect(r, Color("#e9dcc0")); meters.draw_rect(r, INK, false, 2)
		var g0 := clampf(f.green - Fishing.SWEET, 0, 1)
		var g1 := clampf(f.green + Fishing.SWEET, 0, 1)
		meters.draw_rect(Rect2(r.position.x + r.size.x * g0, r.position.y + 2, r.size.x * (g1 - g0), r.size.y - 4), Color("#8fd19e") if f.tgt != null else Color("#cfe8d4"))
		meters.draw_rect(Rect2(r.position.x + r.size.x * f.power - 2, r.position.y - 5, 4, r.size.y + 10), INK)
		meters.draw_string(font, Vector2(16, 88), "near", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		meters.draw_string(font, Vector2(W - 40, 88), "far", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		return
	var title := "Something HUGE is on!" if f.fish.pull > 0.85 else "Something big is on!" if f.fish.pull > 0.55 else "Fish on!"
	meters.draw_string(font, Vector2(0, 22), title, HORIZONTAL_ALIGNMENT_CENTER, W, 16, INK)
	var rows := [["TENSION", 34], ["REELED IN", 58], ["FISH RUN", 82]]
	for row in rows:
		meters.draw_string(font, Vector2(14, row[1] + 12), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		var r := Rect2(100, row[1], W - 116, 16)
		meters.draw_rect(r, Color("#e9dcc0"))
		match row[0]:
			"TENSION":
				meters.draw_rect(Rect2(r.position.x + r.size.x * Fishing.BAND[0], r.position.y, r.size.x * (Fishing.BAND[1] - Fishing.BAND[0]), r.size.y), Color("#8fd19e"))
				meters.draw_rect(Rect2(r.position.x + r.size.x * clampf(f.tension, 0, 1) - 2, r.position.y - 3, 4, r.size.y + 6), CORAL if f.tension > Fishing.BAND[1] else INK)
			"REELED IN": meters.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f.progress, 0, 1), r.size.y)), Color("#2b7ea6"))
			"FISH RUN":
				meters.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.22, r.size.y)), Color("#f3b7a8"))
				meters.draw_rect(Rect2(r.position.x + r.size.x * 0.78, r.position.y, r.size.x * 0.22, r.size.y), Color("#f3b7a8"))
				meters.draw_rect(Rect2(r.position.x + r.size.x / 2 - 1, r.position.y, 2, r.size.y), Color(INK, 0.4))
				var fx := r.position.x + r.size.x * (0.5 + clampf(f.ang, -1, 1) * 0.5)
				meters.draw_circle(Vector2(fx, r.position.y + r.size.y / 2), 7, CORAL if absf(f.ang) > 0.55 else Color("#2b7ea6"))
		meters.draw_rect(r, INK, false, 2)

# ---------- cards ----------
func is_open() -> bool: return modal.visible

func close() -> void:
	if modal.visible: Sound.play("ui_close", -4.0)
	modal.visible = false

## Opens a card. parts: [["h3", text], ["h2", text], ["p", text], ["sub", text], ["quote", text],
## ["kv", [[k, v], ...]], ["row", [[label, callable, enabled, style], ...]], ["item", name, desc, button, callable, enabled]]
## wide: the card fills most of the window (the map uses this). ["node", control] adds a ready-made control.
## width: a card wider than the usual 620 (capped to the window), for one with a big picture.
func open(parts: Array, wide := false, width := 0.0) -> void:
	for c in card_box.get_children(): c.queue_free()
	var scroll: Control = card_box.get_parent()
	var cardc: Control = scroll.get_parent()
	var vs := get_viewport().get_visible_rect().size
	var cw := minf(width, vs.x - 80) if width > 0 else 620.0
	cardc.custom_minimum_size.x = vs.x - 80 if wide else cw
	scroll.custom_minimum_size.x = vs.x - 124 if wide else cw - 20
	var first_btn: Button = null
	for p in parts:
		match p[0]:
			"h3":
				var h3 := _label(p[1].to_upper(), 12, MUTED); h3.add_theme_font_override("font", Game.font_bold); card_box.add_child(h3)
			"h2":
				var h2 := _label(p[1], 32, INK); h2.add_theme_font_override("font", Game.font_display); card_box.add_child(h2)
			"p": card_box.add_child(_label(p[1], 16, INK))
			"sub": card_box.add_child(_label(p[1], 14, MUTED))
			"quote":
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), SUN, 0, 0, Vector4(4, 0, 0, 0), SUN, 12, 2))
				var q := _label(p[1], 21, INK); q.add_theme_font_override("font", Game.font_display); pc.add_child(q); card_box.add_child(pc)
			"kv":
				var g := GridContainer.new(); g.columns = 3
				g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10)
				for kv in p[1]:
					var cell := PanelContainer.new()
					cell.add_theme_stylebox_override("panel", _box(PAPER2, Color.TRANSPARENT, 10, 0, Vector4.ZERO, Color.TRANSPARENT, 10, 8))
					cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
					v.add_child(_label(kv[0].to_upper(), 11, MUTED)); v.add_child(_label(kv[1], 18, INK))
					cell.add_child(v); g.add_child(cell)
				card_box.add_child(g)
			"row":
				var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10)
				for bdef in p[1]:
					var b := _button(bdef[0], bdef[1], bdef[2] if bdef.size() > 2 else true, bdef[3] if bdef.size() > 3 else "")
					b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					hb.add_child(b)
					if first_btn == null and not b.disabled: first_btn = b
				card_box.add_child(hb)
			"item":
				# [title, desc, button text, callback, enabled, optional icon Callable(ci, rect), optional dim]
				var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14)
				if p.size() > 6 and p[6] is Callable:
					hb.add_child(_icon_tile(p[6], 64, p.size() > 7 and p[7]))
				var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 2)
				v.add_child(_label(p[1], 16, INK)); v.add_child(_label(p[2], 13, MUTED))
				v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hb.add_child(v)
				var b := _button(p[3], p[4], p[5])
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hb.add_child(b)
				card_box.add_child(hb)
				var sep := HSeparator.new(); sep.add_theme_color_override("separator", LINE); card_box.add_child(sep)
			"node": card_box.add_child(p[1])
			"kit":
				# a strip of small pictures: [label, [[icon Callable(ci, rect), tooltip], ...]]
				var kh := HBoxContainer.new(); kh.add_theme_constant_override("separation", 10)
				var kl := _label(p[1].to_upper(), 11, MUTED); kl.add_theme_font_override("font", Game.font_bold)
				kl.custom_minimum_size.x = 0; kl.autowrap_mode = TextServer.AUTOWRAP_OFF; kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				kh.add_child(kl)
				var kf := HFlowContainer.new(); kf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				kf.add_theme_constant_override("h_separation", 6); kf.add_theme_constant_override("v_separation", 6)
				for k in p[2]:
					var tile := _icon_tile(k[0], 42, false)
					tile.tooltip_text = k[1]
					if k.size() > 2: # a count badge
						var badge := Label.new(); badge.text = k[2]
						badge.add_theme_font_override("font", Game.font_bold); badge.add_theme_font_size_override("font_size", 11)
						badge.add_theme_color_override("font_color", Color.WHITE)
						badge.add_theme_stylebox_override("normal", _box(INK, Color.TRANSPARENT, 999, 0, Vector4.ZERO, Color.TRANSPARENT, 5, 0))
						badge.position = Vector2(28, 28)
						tile.add_child(badge)
					kf.add_child(tile)
				kh.add_child(kf)
				card_box.add_child(kh)
			"pic":
				var pc := Control.new()
				pc.custom_minimum_size = Vector2(0, p[2])
				pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var fn: Callable = p[1]
				pc.draw.connect(func(): fn.call(pc))
				pc.resized.connect(pc.queue_redraw)
				if p.size() > 3 and p[3]: pc.set_process(true); pc.add_child(_redrawer(pc))
				card_box.add_child(pc)
			"goal":
				# [title, side note, progress 0..1 or -1, optional body]
				var gp := PanelContainer.new()
				gp.add_theme_stylebox_override("panel", _box(PAPER2, Color.TRANSPARENT, 10, 0, Vector4(4, 0, 0, 0), CORAL, 14, 10))
				var gv := VBoxContainer.new(); gv.add_theme_constant_override("separation", 6)
				var top := HBoxContainer.new()
				var gt := _label("Goal" if p.size() <= 4 else p[1], 15, INK); gt.add_theme_font_override("font", Game.font_bold); gt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				top.add_child(gt)
				if p[2] != "":
					var side := _label(p[2], 13, MUTED); side.autowrap_mode = TextServer.AUTOWRAP_OFF; side.custom_minimum_size.x = 0; top.add_child(side)
				gv.add_child(top)
				gv.add_child(_label(p[1] if p.size() <= 4 else p[4], 16, INK))
				if p[3] >= 0:
					var bar := Control.new(); bar.custom_minimum_size = Vector2(0, 14)
					var frac: float = p[3]
					bar.draw.connect(func():
						bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color("#e9dcc0"))
						bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * clampf(frac, 0, 1), bar.size.y)), TEAL)
						bar.draw_rect(Rect2(Vector2.ZERO, bar.size), INK, false, 2))
					gv.add_child(bar)
				gp.add_child(gv); card_box.add_child(gp)
			"lb":
				var lv := VBoxContainer.new(); lv.add_theme_constant_override("separation", 4)
				var i := 0
				for r in p[1]:
					i += 1
					var rp := PanelContainer.new()
					rp.add_theme_stylebox_override("panel", _box(SUN if r[2] else PAPER2, Color.TRANSPARENT, 8, 0, Vector4.ZERO, Color.TRANSPARENT, 12, 6))
					var rh := HBoxContainer.new()
					var n := _label("%d. %s" % [i, r[0]], 15, INK); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var v := _label(r[1], 15, INK); v.add_theme_font_override("font", Game.font_bold); v.custom_minimum_size.x = 0; v.autowrap_mode = TextServer.AUTOWRAP_OFF
					rh.add_child(n); rh.add_child(v); rp.add_child(rh); lv.add_child(rp)
				card_box.add_child(lv)
			"grid":
				# plaques: [[title, desc, got], ...]
				var g := GridContainer.new(); g.columns = 2
				g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
				for a in p[1]:
					var cell := PanelContainer.new()
					cell.add_theme_stylebox_override("panel", _box(Color("#fff4cf") if a[2] else PAPER2, SUN if a[2] else Color.TRANSPARENT, 8, 2 if a[2] else 0, Vector4.ZERO, Color.TRANSPARENT, 10, 6))
					cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
					var tl := _label(("★ " if a[2] else "") + a[0], 14, INK if a[2] else MUTED); tl.add_theme_font_override("font", Game.font_bold)
					v.add_child(tl); v.add_child(_label(a[1], 12, MUTED))
					cell.add_child(v); g.add_child(cell)
				card_box.add_child(g)
			"chips":
				# a flowing row of small tags: [[text, style], ...] with style "got", "leg" or ""
				var fl := HFlowContainer.new()
				fl.add_theme_constant_override("h_separation", 6); fl.add_theme_constant_override("v_separation", 6)
				for c in p[1]:
					var st: String = c[1]
					var l := _label(c[0], 12, Color.WHITE if st == "got" else INK)
					l.custom_minimum_size.x = 0
					l.autowrap_mode = TextServer.AUTOWRAP_OFF
					var bg := TEAL if st == "got" else Color("#fff4cf") if st == "leg" else PAPER2
					l.add_theme_stylebox_override("normal", _box(bg, SUN if st == "leg" else Color.TRANSPARENT, 999, 2 if st == "leg" else 0, Vector4.ZERO, Color.TRANSPARENT, 9, 3))
					fl.add_child(l)
				card_box.add_child(fl)
			"keys":
				var g := GridContainer.new(); g.columns = 2
				g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 8)
				for kd in p[1]:
					var kc := _label(kd[0], 14, INK); kc.add_theme_font_override("font", Game.font_bold)
					kc.autowrap_mode = TextServer.AUTOWRAP_OFF; kc.custom_minimum_size = Vector2(150, 0)
					kc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					var ks := _box(Color.WHITE, INK, 6, 2, Vector4.ZERO, Color.TRANSPARENT, 8, 4)
					ks.border_width_bottom = 4
					kc.add_theme_stylebox_override("normal", ks)
					var ka := _label(kd[1], 15, INK); ka.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					ka.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					g.add_child(kc); g.add_child(ka)
				card_box.add_child(g)
			"vol":
				# [label, 0..10, callable(new value)]
				var vh := HBoxContainer.new(); vh.add_theme_constant_override("separation", 10)
				var vl := _label(p[1], 15, INK); vl.custom_minimum_size.x = 110; vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				vh.add_child(vl)
				var cbv: Callable = p[3]
				var val: int = p[2]
				var minus := _button("−", func(): cbv.call(val - 1), val > 0); minus.custom_minimum_size.x = 44
				vh.add_child(minus)
				var vbar := Control.new(); vbar.custom_minimum_size = Vector2(0, 22); vbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				vbar.draw.connect(func():
					var w := (vbar.size.x - 9 * 4) / 10.0
					for i in 10: vbar.draw_rect(Rect2(i * (w + 4), 0, w, vbar.size.y), TEAL if i < val else Color("#e9dcc0")))
				vbar.mouse_filter = Control.MOUSE_FILTER_STOP
				vbar.gui_input.connect(func(ev):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						cbv.call(clampi(ceili(ev.position.x / vbar.size.x * 10.0), 0, 10)))
				vh.add_child(vbar)
				var plus := _button("+", func(): cbv.call(val + 1), val < 10); plus.custom_minimum_size.x = 44
				vh.add_child(plus)
				var pct := _label("%d%%" % (val * 10), 14, MUTED); pct.custom_minimum_size.x = 48; pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				vh.add_child(pct)
				card_box.add_child(vh)
			"head":
				var hl := _label(p[1], 15, INK); hl.add_theme_font_override("font", Game.font_bold)
				var hr := HBoxContainer.new(); hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hr.add_child(hl)
				if p.size() > 2:
					var hs := _label(p[2], 13, MUTED); hs.autowrap_mode = TextServer.AUTOWRAP_OFF; hs.custom_minimum_size.x = 0; hr.add_child(hs)
				card_box.add_child(hr)
			"tabs":
				var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6)
				for tdef in p[1]:
					var b := _button(tdef[0], tdef[1], true, "ink" if tdef[2] else "")
					hb.add_child(b)
				card_box.add_child(hb)
	if not modal.visible:
		Sound.play("ui_open", -4.0)
		modal.visible = true
		modal.modulate.a = 0
		var card: Control = card_box.get_parent().get_parent()
		card.pivot_offset = card.size / 2
		card.scale = Vector2(0.96, 0.96)
		var tw := create_tween().set_parallel()
		tw.tween_property(modal, "modulate:a", 1.0, 0.12)
		tw.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if first_btn: first_btn.grab_focus.call_deferred()

## A rounded paper tile with a picture drawn in it. Locked items are drawn faded.
func _icon_tile(fn: Callable, sz: int, dim: bool) -> Control:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(sz, sz)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := _box(Color("#fff8ea"), LINE, 10, 2, Vector4.ZERO, Color.TRANSPARENT, 0, 0)
	tile.draw.connect(func():
		tile.draw_style_box(bg, Rect2(Vector2.ZERO, tile.size))
		var pad := tile.size.x * 0.1
		fn.call(tile, Rect2(Vector2(pad, pad), tile.size - Vector2(pad, pad) * 2)))
	if dim: tile.modulate = Color(1, 1, 1, 0.4)
	return tile

func _redrawer(c: Control) -> Node:
	var tm := Timer.new(); tm.wait_time = 0.05; tm.autostart = true
	tm.timeout.connect(c.queue_redraw)
	return tm

func _label(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.custom_minimum_size.x = 100
	return l

func _button(s: String, cb: Callable, enabled: bool, style := "") -> Button:
	var b := Button.new()
	b.text = s
	b.disabled = not enabled
	if style != "":
		var bg: Color = { "hot": SUN, "go": CORAL, "ink": INK, "teal": TEAL }.get(style, PAPER)
		var sb: StyleBoxFlat = theme_.get_stylebox("normal", "Button").duplicate()
		sb.bg_color = bg
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var fc := Color.WHITE if style in ["go", "ink", "teal"] else INK
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(k, fc)
	b.pressed.connect(func(): Sound.play("ui_click", -4))
	b.pressed.connect(cb)
	# a little lift on hover and a squish on press
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.mouse_entered.connect(func(): if not b.disabled: Sound.play("ui_hover", -6); create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.08))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.button_down.connect(func(): create_tween().tween_property(b, "scale", Vector2(0.97, 0.97), 0.05))
	b.button_up.connect(func(): create_tween().tween_property(b, "scale", Vector2(1.03, 1.03) if b.is_hovered() else Vector2.ONE, 0.08))
	return b
