class_name MapView
extends Control
## The big town map (M): zoom with the buttons, the mouse wheel or + and -, drag to move around.

const ZMIN := 1.0
const ZMAX := 7.0

var main: Node                 # for the ground texture, the zone overlay and the player
var zoom := 1.0
var center := Vector2(Town.MW / 2.0, Town.MH / 2.0)   # the tile at the middle of the view
var dragging := false
var started := false
var zl: Label
var locked: Texture2D          # grey over the part of town that isn't open yet

func _init(m: Node) -> void:
	main = m
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(12, 12)
	add_child(box)
	for d in [["+", func(): zoom_by(1.5)], ["−", func(): zoom_by(1 / 1.5)], ["Whole map", show_all], ["Find me", find_me]]:
		var b: Button = main.hud._button(d[0], d[1], true)
		b.custom_minimum_size = Vector2(44 if d[0].length() == 1 else 0, 40)
		b.focus_mode = Control.FOCUS_NONE
		box.add_child(b)
	zl = Label.new()
	zl.add_theme_font_override("font", Game.font_bold)
	zl.add_theme_font_size_override("font_size", 13)
	zl.add_theme_color_override("font_color", Color("#22313a"))
	zl.add_theme_color_override("font_outline_color", Color(0.98, 0.95, 0.89))
	zl.add_theme_constant_override("outline_size", 4)
	box.add_child(zl)
	resized.connect(func():
		if not started and size.x > 10:
			started = true; find_me()
		queue_redraw())
	var tm := Timer.new(); tm.wait_time = 0.05; tm.autostart = true; tm.timeout.connect(queue_redraw); add_child(tm)

## Pixels per tile at zoom 1, where the whole map fits.
func base_k() -> float: return minf(size.x / Town.MW, size.y / Town.MH)
func k() -> float: return base_k() * zoom
func to_screen(p: Vector2) -> Vector2: return size / 2 + (p - center) * k()
func to_map(s: Vector2) -> Vector2: return center + (s - size / 2) / k()

func clamp_center() -> void:
	var half := size / 2 / k()
	for ax in 2:
		var lim: float = [Town.MW, Town.MH][ax]
		center[ax] = lim / 2.0 if half[ax] * 2 >= lim else clampf(center[ax], half[ax], lim - half[ax])

func zoom_by(f: float, at := Vector2(-1, -1)) -> void:
	if at.x < 0: at = size / 2
	var before := to_map(at)
	zoom = clampf(zoom * f, ZMIN, ZMAX)
	center += before - to_map(at)        # keep the spot under the mouse where it was
	clamp_center(); queue_redraw()

func show_all() -> void:
	zoom = ZMIN; clamp_center(); queue_redraw()

## Zooms in around the player.
func find_me() -> void:
	zoom = 2.0
	center = main.player.position
	clamp_center(); queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: zoom_by(1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: zoom_by(1 / 1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			dragging = e.pressed
			if e.double_click: zoom_by(1.8, e.position)
		accept_event()
	elif e is InputEventMouseMotion and dragging:
		center -= e.relative / k(); clamp_center(); queue_redraw(); accept_event()
	elif e is InputEventMagnifyGesture:
		zoom_by(e.factor, e.position); accept_event()
	elif e is InputEventPanGesture:
		center += e.delta * 8 / k(); clamp_center(); queue_redraw(); accept_event()

func _draw() -> void:
	clamp_center()
	var kk := k()
	var r := Rect2(to_screen(Vector2.ZERO), Vector2(Town.MW, Town.MH) * kk)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#cfe3ea"))
	draw_texture_rect(main.ground_tex, r, false)
	draw_texture_rect(main._zone_tex, r, false)
	var o := r.position
	for b in Town.buildings: draw_rect(Rect2(o + Vector2(b.x, b.y) * kk, Vector2(b.w, b.h) * kk), Color(b.color) if b.has("color") else Color("#c9b9a0"))
	var bsz := clampf(kk * 1.2, 6, 14)
	for bs in Story.BUS:
		var bp: Vector2 = o + bs[1] * kk
		draw_rect(Rect2(bp - Vector2(bsz, bsz) / 2, Vector2(bsz, bsz)), Color("#2b7ea6"))
		if zoom >= 2.5:
			_text(bp + Vector2(bsz, 4), "Bus · " + bs[0], 11, Color("#2b7ea6"), false)
	if locked: draw_texture_rect(locked, r, false)
	var fs := int(clampf(7 + kk * 0.9, 10, 20))
	for l in Town.labels:
		_text(o + Vector2(l.x, l.y) * kk, l.t, fs, Color("#22313a"), true)
	# the boats you left somewhere
	var pk := Player.parked()
	for kind in pk:
		if not Game.S.gear.has(kind): continue
		var v: Array = pk[kind]
		var bp := to_screen(Vector2(v[0], v[1]))
		var sk := clampf(kk * 0.9, 5, 16)
		draw_set_transform(bp, v[2], Vector2(sk, sk))
		if kind == "skiff": Player.draw_skiff(self)
		else: Player.draw_kayak(self, null)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_text(bp + Vector2(sk * 1.2 + 4, 4), "Your " + kind, 12, Color("#c4572f"), false)
	var pp := to_screen(main.player.position)
	var pulse := 5.0 + 2.0 * sin(Time.get_ticks_msec() / 200.0) + minf(zoom, 3)
	draw_circle(pp, pulse + 2, Color("#22313a"))
	draw_circle(pp, pulse, Color("#f2b134"))
	draw_rect(r, Color("#22313a"), false, 2)
	zl.text = "%d%%" % roundi(zoom * 100)

func _text(p: Vector2, s: String, fs: int, col: Color, centered: bool) -> void:
	var tw := Game.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if centered: p.x -= tw / 2
	if p.x > size.x or p.x + tw < 0 or p.y < 0 or p.y - fs > size.y: return
	draw_string_outline(Game.font_bold, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.98, 0.95, 0.89, 0.9))
	draw_string(Game.font_bold, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
