class_name TownLife
extends Node
## People out walking on the sidewalks and park paths (some with a dog, umbrellas up when it rains),
## flags on poles outside a few buildings, and the fountains. Wind (from the weather) makes the
## trees and flags move more on a stormy day.

const COUNT := 44
const SHIRTS := ["#e2583e", "#2b7ea6", "#f2b134", "#5bb5a9", "#f4efe4", "#7a3b3b", "#9fd3c7", "#c9b6e4", "#3d4a52", "#f3a6a0", "#6d9a4a", "#e98a7b"]
const UMBRELLAS := ["#e2583e", "#2b7ea6", "#f2b134", "#22313a", "#5bb5a9", "#c9b6e4"]

var player: Player
var holder: Node2D
var walkers: Array = []

## 1 on a calm day, up to about 3 in a storm.
static func wind() -> float:
	var wx: Dictionary = Game.wx
	if wx.is_empty(): return 1.0
	return 1.0 + float(wx.get("cloud", 0.0)) * 0.4 + float(wx.get("rain", 0.0)) * 1.2 + (0.8 if wx.get("storm", false) else 0.0)

static func _walkable(c: Vector2i) -> bool:
	var t := Town.t_at(c.x, c.y)
	return t == Town.T.WALK or t == Town.T.PATH

class Walker extends Node2D:
	var cell := Vector2i.ZERO
	var next := Vector2i.ZERO
	var d := Vector2i(1, 0)
	var face := 0.0
	var speed := 1.3
	var phase := 0.0
	var moving := true
	var pause := 0.0
	var wait := 0.0
	var look := {}
	var dog := false
	var dog_col := Color.WHITE
	var umb := Color.WHITE
	var owl := 0.0              # how likely they're still out late at night
	var fade := 1.0
	var rain_k := 0.0

	func _process(_dt: float) -> void: queue_redraw()

	func _draw() -> void:
		modulate.a = fade
		var fw := Vector2.from_angle(face)
		if dog:
			var dp := -fw * 0.75 + Vector2(-fw.y, fw.x) * 0.25 + Vector2(0, 0.15)
			draw_line(Vector2(0.12, -0.25), dp + fw * 0.12 + Vector2(0, -0.08), Color(0.2, 0.15, 0.1, 0.6), 0.02)
			TownLife.draw_dog(self, dp, face, dog_col, phase, moving)
		Art.character(self, Vector2.ZERO, face, look, phase, moving)
		if rain_k > 0.01:
			# an umbrella over their head
			var top := Vector2(0.05, -0.8)
			draw_line(Vector2(0.16, -0.12), top, Color("#3a3a3a"), 0.025)
			var c := Color(umb, rain_k)
			Art.ellipse(self, top + Vector2(0.15, 0.95), 0.4, 0.14, Color(0, 0, 0, 0.12 * rain_k))
			Art.ellipse(self, top, 0.46, 0.22, Art.shade(c, -0.15))
			Art.ellipse(self, top + Vector2(0, -0.03), 0.42, 0.18, c)
			for k in 4:
				var a := k * PI / 4
				draw_line(top + Vector2(cos(a), sin(a) * 0.45) * 0.42, top - Vector2(cos(a), sin(a) * 0.45) * 0.42, Color(0, 0, 0, 0.12 * rain_k), 0.015)

## A small dog trotting along: body, head, ears and a wagging tail.
static func draw_dog(ci: CanvasItem, p: Vector2, face: float, col: Color, phase: float, moving: bool) -> void:
	var fw := Vector2(cos(face), sin(face) * 0.55)
	Art.ellipse(ci, p + Vector2(0.02, 0.12), 0.2, 0.07, Color(0, 0, 0, 0.25))
	for i in 4:
		var lx := (-0.1 if i < 2 else 0.1)
		var sw := sin(phase * 1.4 + i * PI) * 0.04 if moving else 0.0
		var top := p + fw * (lx + sw * 0.0) + Vector2((i % 2) * 0.06 - 0.03, 0.0)
		ci.draw_line(top, top + fw * sw + Vector2(0, 0.12), Art.shade(col, -0.25), 0.04)
	Art.ellipse(ci, p, 0.17, 0.08, col)
	var head := p + fw * 0.17 + Vector2(0, -0.07)
	ci.draw_circle(head, 0.07, col)
	ci.draw_circle(head + fw * 0.05 + Vector2(0, 0.02), 0.035, Art.shade(col, -0.1))
	ci.draw_circle(head + Vector2(-0.04, -0.05), 0.03, Art.shade(col, -0.3))
	ci.draw_circle(head + Vector2(0.04, -0.05), 0.03, Art.shade(col, -0.3))
	var tail := p - fw * 0.16 + Vector2(0, -0.03)
	ci.draw_line(tail, tail - fw * 0.08 + Vector2(sin(phase * 2.5) * 0.04, -0.08), col, 0.03)

func setup(ents: Node2D) -> void:
	holder = ents
	for i in COUNT:
		var w := Walker.new()
		w.look = {
			"shirt": Color(SHIRTS.pick_random()),
			"pants": [Color("#4a5a6a"), Color("#c9b48a"), Color("#3d5a73"), Color("#6b5a48"), Color("#22313a")].pick_random(),
			"skin": Color(Art.SKINS.pick_random()), "hair": Color(Art.HAIRS.pick_random()),
			"hat": Color(SHIRTS.pick_random()) if randf() < 0.25 else Color(0, 0, 0, 0), "hat_kind": "cap" }
		w.speed = randf_range(1.0, 1.5)
		w.dog = randf() < 0.15
		w.dog_col = [Color("#c9a574"), Color("#3a2a1e"), Color("#f4efe4"), Color("#8a5a35")].pick_random()
		w.umb = Color(UMBRELLAS.pick_random())
		w.owl = randf()
		holder.add_child(w)
		walkers.append(w)
		_place(w, false)

## Put someone on a random bit of sidewalk or path, off screen unless anywhere is fine.
func _place(w: Walker, hidden := true) -> void:
	var view := _view().grow(2)
	for tries in 300:
		var c := Vector2i(randi_range(1, Town.MW - 2), randi_range(1, Town.MH - 2))
		if not _walkable(c): continue
		var p := Vector2(c) + Vector2(0.5, 0.5)
		if hidden and view.has_point(p): continue
		if player != null and player.position.distance_to(p) < 3.0: continue
		var opts := _exits(c, Vector2i.ZERO)
		if opts.is_empty(): continue
		w.cell = c
		w.d = opts.pick_random()
		w.next = c + w.d
		w.position = p + _side(w.d)
		w.face = Vector2(w.d).angle()
		return

static func _side(d: Vector2i) -> Vector2:
	# keep to the right, so people walking opposite ways pass each other
	return Vector2(-d.y, d.x) * 0.2

static func _exits(c: Vector2i, from: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if d == -from and from != Vector2i.ZERO: continue
		if _walkable(c + d): out.append(d)
	return out

func _view() -> Rect2:
	var vp := holder.get_viewport()
	var cam_rect := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return Rect2(cam_rect.position / Game.TS, cam_rect.size / Game.TS)

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var dk := Game.darkness() / 0.62
	var h := Game.hour()
	var late := h >= 23 or h < 5.5
	var rain := float(Game.wx.get("rain", 0.0)) if not Game.wx.is_empty() else 0.0
	for w: Walker in walkers:
		var out := w.owl < (0.12 if late else 0.45 if dk > 0.5 else 1.0)
		w.fade = move_toward(w.fade, 1.0 if out else 0.0, dt)
		w.visible = w.fade > 0.01
		w.rain_k = move_toward(w.rain_k, 1.0 if rain > 0.12 else 0.0, dt * 2.0)
		if not w.visible: continue
		_walk(w, dt)

func _walk(w: Walker, dt: float) -> void:
	w.face = lerp_angle(w.face, Vector2(w.d).angle(), minf(1.0, dt * 10.0))
	if w.pause > 0:
		w.pause -= dt
		w.moving = false
		return
	# don't walk into you
	if player != null:
		var rel := player.position - w.position
		if rel.dot(Vector2(w.d)) > 0 and rel.length() < 0.8:
			w.moving = false
			w.wait += dt
			if w.wait > 1.2:
				w.wait = 0.0
				w.d = -w.d
				var back := w.cell
				w.cell = w.next; w.next = back
			return
	w.wait = 0.0
	w.moving = true
	w.phase += dt * 7.5 * w.speed
	var goal := Vector2(w.next) + Vector2(0.5, 0.5) + _side(w.d)
	var step := w.speed * (0.85 if w.rain_k > 0.5 else 1.0) * dt
	var to := goal - w.position
	if to.length() > step:
		w.position += to.normalized() * step
		return
	w.position = goal
	w.cell = w.next
	if randf() < 0.03: w.pause = randf_range(1.0, 3.0)
	var opts := _exits(w.cell, w.d)
	if opts.is_empty():
		w.d = -w.d
	elif w.d in opts and randf() < 0.75:
		pass
	else:
		w.d = opts.pick_random()
	w.next = w.cell + w.d

# ---------- flags and fountains ----------

## A flag on a pole: p is the foot of the pole. style picks the design.
static func flag(ci: CanvasItem, p: Vector2, style: String, t: float) -> void:
	var top := p + Vector2(0, -2.6)
	Art.ellipse(ci, p + Vector2(0, 0.02), 0.14, 0.07, Color("#3d4a52"))
	ci.draw_line(p + Vector2(0.04, 0.02), p + Vector2(1.2, 0.65), Color(0, 0, 0, 0.15), 0.06)
	ci.draw_line(p, top, Color("#b8c1c6"), 0.06)
	ci.draw_line(p + Vector2(-0.015, 0), top + Vector2(-0.015, 0), Color(1, 1, 1, 0.4), 0.02)
	ci.draw_circle(top, 0.06, Color("#f2b134"))
	var w := wind()
	var cols: Array = { "town": [Color("#2b7ea6"), Color("#f4efe4"), Color("#f2b134")],
		"marina": [Color("#f4efe4"), Color("#e2583e"), Color("#2b7ea6")],
		"golf": [Color("#2f8a3e"), Color("#f4efe4"), Color("#f2b134")],
		"shop": [Color("#f2b134"), Color("#2b7ea6"), Color("#e2583e")] }[style]
	var L := 1.15
	var H := 0.7
	var n := 10
	var top_e := PackedVector2Array()
	var bot_e := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		var wave := sin(t * (3.0 + w) - f * 5.0) * 0.09 * f * w
		var droop := (1.0 - minf(w, 2.0) / 2.0) * f * f * 0.25
		top_e.append(top + Vector2(0.03 + f * L * (0.9 + 0.1 / w), 0.04 + wave + droop))
		bot_e.append(top + Vector2(0.03 + f * L * (0.9 + 0.1 / w) * 0.98, 0.04 + H + wave + droop * 1.4))
	var body := top_e.duplicate()
	for i in range(n, -1, -1): body.append(bot_e[i])
	ci.draw_colored_polygon(body, cols[0])
	# a stripe across the middle and a badge near the pole, all following the wave
	var mid := PackedVector2Array()
	for i in n + 1: mid.append(top_e[i].lerp(bot_e[i], 0.4))
	for i in range(n, -1, -1): mid.append(top_e[i].lerp(bot_e[i], 0.6))
	ci.draw_colored_polygon(mid, cols[1])
	var bc := top_e[3].lerp(bot_e[3], 0.5)
	ci.draw_circle(bc, 0.17, cols[2])
	if style == "town":
		# a little mullet on the town flag
		Art.ellipse(ci, bc, 0.11, 0.045, cols[0])
		ci.draw_colored_polygon(PackedVector2Array([bc + Vector2(-0.1, 0), bc + Vector2(-0.16, -0.05), bc + Vector2(-0.16, 0.05)]), cols[0])
	# shading on the folds
	for i in n:
		var k := sin(t * (3.0 + w) - (float(i) / n) * 5.0)
		if k > 0.3:
			ci.draw_colored_polygon(PackedVector2Array([top_e[i], top_e[i + 1], bot_e[i + 1], bot_e[i]]), Color(1, 1, 1, 0.1 * k))
		elif k < -0.3:
			ci.draw_colored_polygon(PackedVector2Array([top_e[i], top_e[i + 1], bot_e[i + 1], bot_e[i]]), Color(0, 0, 0, 0.1 * -k))

## A fountain jet in a pool: water shoots up from p and falls back in a ring of drops.
static func fountain(ci: CanvasItem, p: Vector2, t: float, big := 1.0) -> void:
	var w := wind()
	var hgt := 2.1 * big
	var reach := 1.15 * big
	var drift := (w - 1.0) * 0.3
	# churned white water where the spray comes down, and rings spreading from it
	Art.ellipse(ci, p + Vector2(drift, 0.05), reach * 1.05, reach * 0.42, Color(1, 1, 1, 0.22))
	Art.ellipse(ci, p + Vector2(0, 0.02), 0.32 * big, 0.14 * big, Color(1, 1, 1, 0.55))
	Art.ellipse(ci, p + Vector2(0, 0.0), 0.14 * big, 0.06 * big, Color("#5d6a70"))
	for k in 3:
		var rr := fmod(t * 0.5 + k / 3.0, 1.0)
		ci.draw_set_transform(p + Vector2(drift, 0.05), 0, Vector2(1, 0.42))
		ci.draw_arc(Vector2.ZERO, reach * (1.0 + rr * 0.9), 0, TAU, 36, Color(1, 1, 1, 0.4 * (1.0 - rr)), 0.06)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# drops arcing up and over, drawn as short streaks so the spray reads as moving water
	var n := int(70 * big)
	for i in n:
		var k := fmod(t * 0.8 + Town.hash2(i, 11) * 5.0, 1.0)
		var a := float(i) / n * TAU + Town.hash2(i, 7) * 0.4
		var r := reach * (0.6 + 0.4 * Town.hash2(i, 5))
		var f := func(kk: float) -> Vector2: return p + Vector2(cos(a), sin(a) * 0.42) * r * kk + Vector2(drift * kk, -hgt * 4.0 * kk * (1.0 - kk) * 0.55 - hgt * 0.45 * (1.0 - kk) * (1.0 - kk))
		var p1: Vector2 = f.call(k)
		var p0: Vector2 = f.call(maxf(k - 0.06, 0.0))
		var dw := (0.06 + 0.03 * Town.hash2(i, 3)) * big
		ci.draw_line(p0 + Vector2(0, 0.02), p1 + Vector2(0, 0.02), Color(0.3, 0.5, 0.62, 0.35 * (1.0 - k * 0.4)), dw * 1.4)
		ci.draw_line(p0, p1, Color(0.9, 0.97, 1.0, 0.75 * (1.0 - k * 0.4)), dw)
	# the central jet
	var col := PackedVector2Array()
	for i in 9:
		var ff := i / 8.0
		col.append(p + Vector2(sin(t * 7.0 + ff * 6.0) * 0.025 * ff + drift * ff * 0.5, -hgt * ff))
	ci.draw_polyline(col, Color(0.3, 0.5, 0.62, 0.35), 0.22 * big)
	ci.draw_polyline(col, Color(0.88, 0.96, 1.0, 0.8), 0.16 * big)
	ci.draw_polyline(col, Color(1, 1, 1, 0.95), 0.06 * big)
	for i in 6:
		var mp := p + Vector2(sin(t * 1.3 + i * 2.0) * 0.35 * big + drift, -hgt * (0.75 + 0.1 * sin(i)) + cos(t + i) * 0.1)
		ci.draw_circle(mp, 0.28 * big, Color(1, 1, 1, 0.1))
