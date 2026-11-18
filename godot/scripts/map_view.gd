class_name MapView
extends Control
## The big town map (M): zoom with the buttons, the mouse wheel or + and -, drag to move around.
## The detailed picture underneath is drawn once (MapArt); this view draws it, then the labels, street names,
## fishing spots, shops, bus stops, your boats and you on top, crisp at any zoom.

const ZMIN := 1.0
const ZMAX := 7.0

var main: Node                 # for the ground texture, the zone overlay and the player
var zoom := 1.0
var center := Vector2(Town.MW / 2.0, Town.MH / 2.0)   # the tile at the middle of the view
var dragging := false
var started := false
var zl: Label
var locked: Texture2D          # grey over the part of town that isn't open yet
var base: Control              # the map picture, smoothly scaled
var over: Control              # everything drawn on top of it
static var show_legend := true

func _init(m: Node) -> void:
	main = m
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	base = _Layer.new(self, true); add_child(base)
	over = _Layer.new(self, false); add_child(over)
	MapArt.bake(main, func(): if is_instance_valid(self): queue_redraw())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(12, 12)
	add_child(box)
	for d in [["+", func(): zoom_by(1.5)], ["−", func(): zoom_by(1 / 1.5)], ["Whole map", show_all], ["Find me", find_me], ["Home", find_home], ["Legend", func(): show_legend = not show_legend; queue_redraw()]]:
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
			for a in OS.get_cmdline_user_args():   # test hook: --mapview=zoom,x,y
				if a.begins_with("--mapview="):
					var v := a.substr(10).split(",")
					zoom = float(v[0]); center = Vector2(float(v[1]), float(v[2])); clamp_center()
		queue_redraw())
	# only the layer with your blinking dot redraws on its own; the picture redraws when you move or zoom
	var tm := Timer.new(); tm.wait_time = 0.05; tm.autostart = true; tm.timeout.connect(over.queue_redraw); add_child(tm)

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

## Zooms in around your house.
func find_home() -> void:
	zoom = 2.5
	center = home_pos()
	clamp_center(); queue_redraw()

## The middle of your house, in tiles.
static func home_pos() -> Vector2:
	for b in Town.buildings:
		if b.get("home", false): return Vector2(b.x + b.w / 2.0, b.y + b.h / 2.0)
	return Vector2(10, 10)

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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#cfe3ea"))
	if base: base.queue_redraw()
	if over: over.queue_redraw()
	zl.text = "%d%%" % roundi(zoom * 100)

## The map picture (filtered smoothly) or everything on top of it (kept sharp).
class _Layer extends Control:
	var v: MapView
	var picture: bool
	func _init(view: MapView, pic: bool) -> void:
		v = view; picture = pic
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if pic else CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		if picture: v.draw_picture(self)
		else: v.draw_over(self)

func map_rect() -> Rect2:
	return Rect2(to_screen(Vector2.ZERO), Vector2(Town.MW, Town.MH) * k())

func draw_picture(ci: CanvasItem) -> void:
	var r := map_rect()
	if MapArt.tex != null:
		ci.draw_texture_rect(MapArt.tex, r, false)
	else:   # still being drawn: the plain version for a frame or two
		ci.draw_texture_rect(main.ground_tex, r, false)

# ---------- what's on top ----------

const INK := Color("#22313a")
const PAPER := Color(0.98, 0.95, 0.89)
const SPOT_BLUE := Color("#2b7ea6")
const GOLD := Color("#f2b134")
const SHOP_RED := Color("#e2583e")

## Where each fishing spot's marker goes, in tiles. Big waters get a hand-picked spot so it doesn't sit on a label or a bridge.
const SPOT_AT := { 2: Vector2(70.5, 52.5), 7: Vector2(18.5, 63.5), 9: Vector2(70.5, 79.5), 13: Vector2(79.5, 128), 14: Vector2(44, 163.5), 15: Vector2(30, 177.5) }
## Shops and landmarks: [label, tile, icon].
const PLACES := [["Lou's Bait & Tackle", Vector2(49, 29.5), "hook"], ["Mullet Bay Marina", Vector2(88.5, 142.5), "anchor"], ["FINTASTIC! Outdoors", Vector2(88.5, 124.5), "bag"]]

static var _spots: Array = []     # [id, tile, name]

static func spots() -> Array:
	if not _spots.is_empty(): return _spots
	for id in Game.spots:
		var p: Vector2
		if SPOT_AT.has(id): p = SPOT_AT[id]
		else:
			var sum := Vector2.ZERO
			var n := 0
			for i in Town.region.size():
				if Town.region[i] == id: sum += Vector2(i % Town.MW + 0.5, i / Town.MW + 0.5); n += 1
			if n == 0: continue
			var c := sum / n
			p = c
			var best := INF
			for i in Town.region.size():
				if Town.region[i] != id: continue
				var q := Vector2(i % Town.MW + 0.5, i / Town.MW + 0.5)
				if q.distance_squared_to(c) < best: best = q.distance_squared_to(c); p = q
		_spots.append([id, p, Game.spots[id].name])
	return _spots

## How many of a spot's fish you've caught, and how many there are.
static func spot_progress(id: int) -> Vector2i:
	var fish: Array = Game.spots[id].fish
	var got := 0
	for f in fish:
		if Game.S.journal.has(f.n): got += 1
	return Vector2i(got, fish.size())

var _placed: Array[Rect2] = []    # labels drawn so far this frame, so later ones don't land on top

func draw_over(ci: CanvasItem) -> void:
	_placed.clear()
	var kk := k()
	var r := map_rect()
	var o := r.position
	if locked: ci.draw_texture_rect(locked, r, false)
	# street names once there's room for them
	if zoom >= 1.6: _street_names(ci, kk)
	var isz := clampf(kk * 1.1, 9, 15)
	var hp := to_screen(home_pos())
	var hsz := clampf(kk * 1.6, 14, 30)
	# the icons first, then the names on top of them; earlier names win when two would overlap
	for bs in Story.BUS: bus_icon(ci, o + bs[1] * kk, isz)
	for pl in PLACES: place_icon(ci, o + pl[1] * kk, isz * 1.1, pl[2])
	for sp in spots():
		var pr := spot_progress(sp[0])
		spot_icon(ci, o + sp[1] * kk, isz, Unlocks.open_p(sp[1]), pr.x >= pr.y)
	_home_marker(ci, hp, hsz)
	_text_on(ci, hp + Vector2(hsz * 0.95 + 3, 5), "Home", 14 if zoom < 2 else 16, Color("#c4572f"), false)
	var fs := int(clampf(7 + kk * 0.9, 10, 20))
	for l in Town.labels:
		_text_on(ci, o + Vector2(l.x, l.y) * kk, l.t, fs, INK, true)
	if zoom >= 1.6:
		for pl in PLACES: _text_on(ci, o + pl[1] * kk + Vector2(isz * 1.1 + 4, 5), pl[0], 12, SHOP_RED.darkened(0.2), false)
	if zoom >= 1.6:
		for sp in spots():
			var pr := spot_progress(sp[0])
			var open := Unlocks.open_p(sp[1])
			_text_on(ci, o + sp[1] * kk + Vector2(0, isz + 13), "%s  %d/%d" % [sp[2], pr.x, pr.y], 11, SPOT_BLUE.darkened(0.25) if open else Color("#6b7378"), true)
	if zoom >= 2.5:
		for bs in Story.BUS: _text_on(ci, o + bs[1] * kk + Vector2(isz + 3, 4), "Bus · " + bs[0], 11, SPOT_BLUE, false)
	# building names up close
	if zoom >= 3.2:
		for b in Town.buildings:
			var lb: String = b.get("label", "")
			if lb == "" or b.get("home", false): continue
			if PLACES.any(func(pl): return Rect2(b.x, b.y, b.w, b.h).has_point(pl[1])): continue
			var c: Vector2 = o + Vector2(b.x + b.w / 2.0, b.y + b.h / 2.0) * kk
			_text_on(ci, c + Vector2(0, 4), lb.capitalize() if lb.length() > 3 else lb, 11, Color("#4a3a2c"), true)
	# the boats you left somewhere
	var pk := Player.parked()
	for kind in pk:
		if not Game.S.gear.has(kind): continue
		var v: Array = pk[kind]
		var bp := to_screen(Vector2(v[0], v[1]))
		var sk := clampf(kk * 0.9, 5, 16)
		ci.draw_set_transform(bp, v[2], Vector2(sk, sk))
		if kind == "skiff": Player.draw_skiff(ci)
		else: Player.draw_kayak(ci, null)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_text_on(ci, bp + Vector2(sk * 1.2 + 4, 4), "Your " + kind, 12, Color("#c4572f"), false)
	# you
	var pp := to_screen(main.player.position)
	var pulse := 5.0 + 2.0 * sin(Time.get_ticks_msec() / 200.0) + minf(zoom, 3)
	ci.draw_circle(pp, pulse + 6, Color(0.95, 0.69, 0.2, 0.25))
	ci.draw_circle(pp, pulse + 2, INK)
	ci.draw_circle(pp, pulse, GOLD)
	ci.draw_rect(r, INK, false, 2)
	_compass(ci, Vector2(size.x - 34, 38))
	if show_legend: _legend(ci)

## Each street's name along it, every so often, turned to run with the street.
func _street_names(ci: CanvasItem, kk: float) -> void:
	var done := {}
	var fs := 11 if zoom < 3 else 13
	for s in MapArt.STREETS:
		if done.has(s[0]) and s[0] == "Egret Circle": continue
		done[s[0]] = true
		var a: Vector2 = to_screen(s[1])
		var b: Vector2 = to_screen(s[2])
		var len := a.distance_to(b)
		var dir := (b - a) / len
		var vert := absf(dir.y) > absf(dir.x)
		var tw := Game.font_bold.get_string_size(s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var gap := maxf(360.0, tw * 3)
		var t := gap * 0.37
		while t < len - tw:
			var c := a + dir * t
			t += gap
			if c.x < -40 or c.y < -40 or c.x > size.x + 40 or c.y > size.y + 40: continue
			# not in the middle of a crossing
			var tile := (c - map_rect().position) / kk
			var side := Vector2(1, 0) if vert else Vector2(0, 1)
			var w: float = s[3] / 2.0 + 0.6
			var busy := false
			for f in [-0.5, 0.0, 0.5]:
				var along: Vector2 = tile + (Vector2(0, 1) if vert else Vector2(1, 0)) * (tw / kk) * f
				for sg in [-1, 1]:
					var q: Vector2 = along + side * w * sg
					if Town.t_at(floori(q.x), floori(q.y)) == Town.T.ROAD: busy = true
			if busy: continue
			ci.draw_set_transform(c, PI / 2 if vert else 0.0, Vector2.ONE)
			var p := Vector2(-tw / 2, fs * 0.36)
			ci.draw_string_outline(Game.font_bold, p, s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color("#4f565d"))
			ci.draw_string(Game.font_bold, p, s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fbf7ee"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ---------- icons, shared with the legend ----------

static func spot_icon(ci: CanvasItem, p: Vector2, s: float, open := true, all := false) -> void:
	var col := SPOT_BLUE if open else Color("#8a9298")
	ci.draw_circle(p + Vector2(1, 1.5), s, Color(0, 0, 0, 0.25))
	ci.draw_circle(p, s, PAPER)
	ci.draw_circle(p, s * 0.82, col)
	if all: ci.draw_arc(p, s + 0.5, 0, TAU, 32, GOLD, 3.0, true)
	# a little fish
	var f := s * 0.5
	ci.draw_set_transform(p + Vector2(-f * 0.15, 0), 0, Vector2(f, f * 0.62))
	ci.draw_circle(Vector2.ZERO, 1.0, PAPER)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(f * 0.65, 0), p + Vector2(f * 1.35, -f * 0.6), p + Vector2(f * 1.35, f * 0.6)]), PAPER)
	ci.draw_circle(p + Vector2(-f * 0.6, -f * 0.12), maxf(1.0, f * 0.13), col)

static func bus_icon(ci: CanvasItem, p: Vector2, s: float) -> void:
	var r := Rect2(p - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6)
	ci.draw_rect(Rect2(r.position + Vector2(1, 1.5), r.size), Color(0, 0, 0, 0.25))
	ci.draw_rect(r.grow(1.5), PAPER)
	ci.draw_rect(r, SPOT_BLUE)
	var bus := Rect2(p - Vector2(s * 0.55, s * 0.45), Vector2(s * 1.1, s * 0.8))
	ci.draw_rect(bus, PAPER)
	ci.draw_rect(Rect2(bus.position + Vector2(s * 0.12, s * 0.12), Vector2(s * 0.86, s * 0.28)), SPOT_BLUE)
	for wx in [0.25, 0.85]: ci.draw_circle(bus.position + Vector2(s * wx, s * 0.8), maxf(1.2, s * 0.14), INK)

static func place_icon(ci: CanvasItem, p: Vector2, s: float, kind: String) -> void:
	ci.draw_circle(p + Vector2(1, 1.5), s, Color(0, 0, 0, 0.25))
	ci.draw_circle(p, s, PAPER)
	ci.draw_circle(p, s * 0.84, SHOP_RED if kind != "anchor" else Color("#1f4e79"))
	var w := maxf(1.6, s * 0.16)
	match kind:
		"hook":
			ci.draw_line(p + Vector2(s * 0.12, -s * 0.55), p + Vector2(s * 0.12, s * 0.1), PAPER, w, true)
			ci.draw_arc(p + Vector2(-s * 0.1, s * 0.1), s * 0.22, 0, PI, 12, PAPER, w, true)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.32 - w * 0.5, s * 0.12), p + Vector2(-s * 0.32 - w * 0.5, -s * 0.22), p + Vector2(-s * 0.12, s * 0.02)]), PAPER)
			ci.draw_circle(p + Vector2(s * 0.12, -s * 0.58), w * 0.9, PAPER)
		"anchor":
			ci.draw_line(p + Vector2(0, -s * 0.45), p + Vector2(0, s * 0.5), PAPER, w, true)
			ci.draw_line(p + Vector2(-s * 0.25, -s * 0.25), p + Vector2(s * 0.25, -s * 0.25), PAPER, w, true)
			ci.draw_arc(p + Vector2(0, s * 0.12), s * 0.4, 0.15, PI - 0.15, 12, PAPER, w, true)
			ci.draw_arc(p + Vector2(0, -s * 0.52), s * 0.12, 0, TAU, 10, PAPER, w * 0.7, true)
		"bag":
			ci.draw_rect(Rect2(p + Vector2(-s * 0.38, -s * 0.18), Vector2(s * 0.76, s * 0.66)), PAPER)
			ci.draw_arc(p + Vector2(0, -s * 0.18), s * 0.2, PI, TAU, 10, PAPER, w, true)

## A little house with a red roof, so you can spot home at any zoom.
static func _home_marker(ci: CanvasItem, p: Vector2, sz: float) -> void:
	var w := sz; var h := sz * 0.75
	var body := Rect2(p + Vector2(-w / 2, -h * 0.35), Vector2(w, h * 0.85))
	ci.draw_circle(p + Vector2(0, sz * 0.05), sz * 0.95, Color(0.98, 0.95, 0.89, 0.85))
	ci.draw_rect(body, Color("#f6c86d")); ci.draw_rect(body, INK, false, 2)
	var roof := PackedVector2Array([p + Vector2(-w * 0.68, -h * 0.3), p + Vector2(0, -h * 1.05), p + Vector2(w * 0.68, -h * 0.3)])
	ci.draw_colored_polygon(roof, Color("#e2583e")); ci.draw_polyline(roof + PackedVector2Array([roof[0]]), INK, 2, true)
	ci.draw_rect(Rect2(p + Vector2(-w * 0.12, h * 0.1), Vector2(w * 0.24, h * 0.4)), INK)

func _compass(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c, 20, Color(0.98, 0.95, 0.89, 0.9))
	ci.draw_arc(c, 20, 0, TAU, 32, INK, 1.5, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15), c + Vector2(5, 0), c + Vector2(-5, 0)]), SHOP_RED)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 15), c + Vector2(5, 0), c + Vector2(-5, 0)]), INK)
	var tw := Game.font_bold.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	ci.draw_string(Game.font_bold, c + Vector2(-tw / 2, -23), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)

func _legend(ci: CanvasItem) -> void:
	var rows := [["you", "You"], ["home", "Home"], ["spot", "Fishing spot (fish caught / all)"], ["all", "Every fish caught there"],
		["shop", "Shop"], ["bus", "Bus stop ($2 ride)"], ["private", "Private: keep your head down"], ["road", "Street"]]
	if locked: rows.append(["closed", "Closed for now"])
	var fs := 12
	var lh := 22.0
	var w := 236.0
	var h := 30.0 + rows.size() * lh
	var r := Rect2(size.x - w - 12, size.y - h - 12, w, h)
	ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.18))
	ci.draw_rect(r, Color(0.98, 0.95, 0.89, 0.94))
	ci.draw_rect(r, INK, false, 1.5)
	ci.draw_string(Game.font_bold, r.position + Vector2(12, 20), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	for i in rows.size():
		var y := r.position.y + 38 + i * lh
		var ic := Vector2(r.position.x + 22, y - 4)
		match rows[i][0]:
			"you": ci.draw_circle(ic, 7, INK); ci.draw_circle(ic, 5, GOLD)
			"home": _home_marker(ci, ic + Vector2(0, 2), 12)
			"spot": spot_icon(ci, ic, 8)
			"all": spot_icon(ci, ic, 8, true, true)
			"shop": place_icon(ci, ic, 8.5, "hook")
			"bus": bus_icon(ci, ic, 7)
			"private":
				var sw := Rect2(ic - Vector2(10, 7), Vector2(20, 14))
				ci.draw_rect(sw, C_GRASS_MIX); ci.draw_rect(sw, Color(0.89, 0.25, 0.2, 0.12))
				for j in 4: ci.draw_line(sw.position + Vector2(j * 6 - 2, 14), sw.position + Vector2(j * 6 + 12, 0).min(sw.end), Color(0.8, 0.22, 0.18, 0.45), 1.2)
				ci.draw_rect(sw, Color(0.78, 0.2, 0.16), false, 1.5)
			"road":
				var sw := Rect2(ic - Vector2(10, 5), Vector2(20, 10))
				ci.draw_rect(sw, MapArt.C_ROAD)
				ci.draw_line(sw.position + Vector2(3, 5), sw.position + Vector2(8, 5), Color.WHITE, 1.5)
				ci.draw_line(sw.position + Vector2(12, 5), sw.position + Vector2(17, 5), Color.WHITE, 1.5)
			"closed":
				var sw := Rect2(ic - Vector2(10, 7), Vector2(20, 14))
				ci.draw_rect(sw, Color(0.28, 0.3, 0.33, 0.72))
		ci.draw_string(Game.font_bold, Vector2(r.position.x + 40, y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)

const C_GRASS_MIX := Color("#d9e6c4")

func _text_on(ci: CanvasItem, p: Vector2, s: String, fs: int, col: Color, centered: bool) -> void:
	var tw := Game.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if centered: p.x -= tw / 2
	if p.x > size.x or p.x + tw < 0 or p.y < 0 or p.y - fs > size.y: return
	var box := Rect2(p.x - 2, p.y - fs * 0.85, tw + 4, fs * 1.1)
	for q in _placed:
		if q.intersects(box): return
	_placed.append(box)
	ci.draw_string_outline(Game.font_bold, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.98, 0.95, 0.89, 0.9))
	ci.draw_string(Game.font_bold, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
