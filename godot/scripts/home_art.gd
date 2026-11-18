class_name HomeArt
extends RefCounted
## The inside of your house, drawn at the top of the home card. It fills up as you play:
## legends you've landed get mounted on the wall, Slam cups line the shelf, the rods you own
## stand in the rack, parts you've found hang on the pegboard, and the big tank (if you bought
## it) bubbles under the window. The window shows the real time of day and weather.
## Everything is drawn on a 640 x 300 design and scaled to fit, like StoryArt. The room's own
## coordinates start under the ceiling (TOP), so the ceiling sits at negative y.
## Chum the cat wakes up and reacts when you pet him (pet()).

const W := 640.0
const H := 300.0
const TOP := 28.0
const ROOM_B := H - TOP
const INK := Color("#22313a")
const PAPER := Color("#fbf3e2")
const SUN := Color("#f2b134")
const CORAL := Color("#e2583e")
const TEAL := Color("#13807b")
const SEA := Color("#2b7ea6")
const WOOD := Color("#8a5a35")
const FLOOR_Y := 214.0
const MAX_MOUNTS := 12

static var _o := Vector2.ZERO
static var _s := 1.0
static var pet_t := -100.0   # when you last petted Chum (seconds, Time.get_ticks_msec)
static var pet_kind := 0     # 0 stretch, 1 roll over, 2 purr
const PET_LEN := 3.4
static var test_since := -1.0   # test hook: hold the pet reaction at this many seconds in

## Pet the cat: he picks a way to react. Returns which (see pet_kind).
static func pet() -> int:
	pet_kind = randi() % 3
	pet_t = Time.get_ticks_msec() / 1000.0
	return pet_kind

static func _fit(ci: Control) -> void:
	_s = minf(ci.size.x / W, ci.size.y / H)
	_o = Vector2((ci.size.x - W * _s) / 2.0, (ci.size.y - H * _s) / 2.0 + TOP * _s)
	ci.draw_set_transform(_o, 0, Vector2(_s, _s))

## ItemIcons.draw sets its own transform, so hand it a rect in control space and fit again after.
static func _icon(ci: Control, id: String, r: Rect2, t := 0.0) -> void:
	ItemIcons.draw(ci, id, Rect2(_o + r.position * _s, r.size * _s), t)
	ci.draw_set_transform(_o, 0, Vector2(_s, _s))

static func _txt(ci: Control, p: Vector2, s: String, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Game.font_bold
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, p - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _box(ci: Control, r: Rect2, fill: Color, lw := 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, INK, false, lw)

## Legends you've landed, heaviest first: [{n, w}, ...]
static func mounts() -> Array:
	var out := []
	for f in Story.all_fish():
		if f.get("legend", false) and Game.S.journal.has(f.n):
			out.append({ "n": f.n, "w": float(Game.S.journal[f.n].w) })
	out.sort_custom(func(a, b): return a.w > b.w)
	return out

static func rods_owned() -> Array:
	var out := ["rod0"]
	for id in ["rod1", "rod2", "rod3", "rod4"]:
		if Game.S.gear.has(id): out.append(id)
	return out

static func room(ci: Control) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_fit(ci)
	var dk := Game.darkness()
	# wall, wainscot and floorboards
	ci.draw_rect(Rect2(0, 0, W, FLOOR_Y), Color("#e9d7b3"))
	for i in 16:
		ci.draw_rect(Rect2(i * 40 + 18, 0, 3, 150), Color("#e2cda5"))   # wallpaper stripes
		for j in 7: ci.draw_circle(Vector2(i * 40 + 38, 12 + j * 20 + (i % 2) * 10), 1.3, Color("#dfc89d"))
	ci.draw_rect(Rect2(0, 150, W, FLOOR_Y - 150), Color("#7fb6a8"))                 # wainscot
	for i in 33: ci.draw_rect(Rect2(i * 20, 152, 2, FLOOR_Y - 152), Color("#6fa597"))
	ci.draw_rect(Rect2(0, 148, W, 5), Color("#f4ead2"))
	ci.draw_rect(Rect2(0, FLOOR_Y, W, ROOM_B - FLOOR_Y), Color("#b07a4a"))
	for i in 5: ci.draw_line(Vector2(0, FLOOR_Y + 10 + i * 12), Vector2(W, FLOOR_Y + 10 + i * 12), Color("#99673c"), 1.5)
	for i in 12: ci.draw_line(Vector2(fmod(i * 97.0, W), FLOOR_Y + 10 + (i % 4) * 12), Vector2(fmod(i * 97.0, W), FLOOR_Y + 22 + (i % 4) * 12), Color("#99673c"), 1.5)
	ci.draw_rect(Rect2(0, FLOOR_Y - 4, W, 5), Color("#f4ead2"))
	# rug
	var rug := Rect2(168, FLOOR_Y + 14, 220, 32)
	ci.draw_rect(rug, Color("#c94a33")); ci.draw_rect(rug.grow(-5), Color("#e2583e")); ci.draw_rect(rug.grow(-11), Color("#f2b134"))
	ci.draw_rect(rug.grow(-15), Color("#e2583e"))
	for i in 7:
		ci.draw_line(Vector2(rug.position.x, rug.position.y + 3 + i * 4.3), Vector2(rug.position.x - 4, rug.position.y + 3 + i * 4.3), Color("#f4ead2"), 1.4)
		ci.draw_line(Vector2(rug.end.x, rug.position.y + 3 + i * 4.3), Vector2(rug.end.x + 4, rug.position.y + 3 + i * 4.3), Color("#f4ead2"), 1.4)
	_ceiling(ci, t, dk)
	_door(ci, t)
	_plant(ci, t)
	_window(ci, t, dk)
	_tank(ci, t)
	_mounts(ci)
	_cups(ci)
	_couch(ci, t)
	_lamp(ci, dk)
	_rods(ci, t)
	_bench(ci, t)
	_table(ci, t)
	_sunbeam(ci, t, dk)
	# night: the room dims and the lamp throws a warm pool
	if dk > 0.05:
		ci.draw_rect(Rect2(0, -TOP, W, H), Color(0.06, 0.08, 0.2, 0.32 * dk))
		for i in 6:
			ci.draw_circle(Vector2(404, 120), 30.0 + i * 22, Color(1.0, 0.8, 0.45, 0.05 * dk))
			ci.draw_circle(Vector2(280, -2), 16.0 + i * 16, Color(1.0, 0.85, 0.55, 0.035 * dk))
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_rect(Rect2(_o - Vector2(0, TOP * _s), Vector2(W, H) * _s), INK, false, 2)

## The window under the time of day: sky, sun or moon and stars, a palm, rain on the glass.
static func _window(ci: Control, t: float, dk: float) -> void:
	var r := Rect2(30, 26, 104, 92)
	var h := Game.hour()
	var sky := Color("#9fd3ea")
	if h < 5 or h >= 21: sky = Color("#1b2a4a")
	elif h < 6.5: sky = Color("#1b2a4a").lerp(Color("#f4a37a"), (h - 5) / 1.5)
	elif h < 8: sky = Color("#f4a37a").lerp(Color("#9fd3ea"), (h - 6.5) / 1.5)
	elif h >= 17 and h < 19: sky = Color("#9fd3ea").lerp(Color("#f08a5d"), (h - 17) / 2.0)
	elif h >= 19: sky = Color("#f08a5d").lerp(Color("#1b2a4a"), (h - 19) / 2.0)
	var wx: Dictionary = Game.wx
	sky = sky.lerp(Color("#8d98a0"), clampf(float(wx.cloud) * 0.5 + float(wx.rain) * 0.4, 0, 0.6) * (1.0 - dk * 0.7))
	ci.draw_rect(r, sky)
	if dk > 0.5:
		for i in 9: ci.draw_circle(r.position + Vector2(fmod(i * 37.0, r.size.x), fmod(i * 23.0, 50.0) + 4), 1.1, Color(1, 1, 0.9, (dk - 0.5) * 2 * (0.6 + 0.4 * sin(t * 2 + i))))
		ci.draw_circle(r.position + Vector2(78, 22), 9, Color("#f4efd8")); ci.draw_circle(r.position + Vector2(83, 19), 8, sky)
	elif float(wx.rain) < 0.3:
		ci.draw_circle(r.position + Vector2(76, 26), 11, Color("#ffe39a"))
	# the neighbor's roof and a palm
	ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 74), r.position + Vector2(40, 56), r.position + Vector2(80, 74), r.position + Vector2(80, 92), r.position + Vector2(0, 92)]), Color("#c97b5a").darkened(dk * 0.6))
	var sway := sin(t * 0.9) * 2.0
	var pb := r.position + Vector2(88, 92)
	ci.draw_line(pb, pb + Vector2(-6 + sway * 0.3, -50), Color("#7a5a3a").darkened(dk * 0.6), 4)
	var top := pb + Vector2(-6 + sway * 0.3, -50)
	for a in [-2.6, -2.0, -1.2, -0.5, 0.2]:
		var tip := top + Vector2(cos(a + sway * 0.03), sin(a + sway * 0.03) + 0.6) * 24
		ci.draw_polyline(PackedVector2Array([top, top.lerp(tip, 0.5) + Vector2(0, -5), tip]), Color("#3f8a4a").darkened(dk * 0.6), 4, true)
	# rain on the glass
	if float(wx.rain) > 0.05:
		for i in int(18 * float(wx.rain)) + 4:
			var x := r.position.x + fmod(i * 29.0, r.size.x)
			var y := r.position.y + fmod(i * 41.0 + t * 90.0, r.size.y - 8)
			ci.draw_line(Vector2(x, y), Vector2(x - 2, y + 8), Color(1, 1, 1, 0.45), 1.2)
	# frame, muntins, sill and curtains
	ci.draw_rect(r, Color("#f4ead2"), false, 6)
	ci.draw_line(r.position + Vector2(r.size.x / 2, 0), r.position + Vector2(r.size.x / 2, r.size.y), Color("#f4ead2"), 4)
	ci.draw_line(r.position + Vector2(0, r.size.y / 2), r.position + Vector2(r.size.x, r.size.y / 2), Color("#f4ead2"), 4)
	ci.draw_rect(r.grow(3), INK, false, 2)
	_box(ci, Rect2(r.position.x - 10, r.end.y + 2, r.size.x + 20, 7), Color("#f4ead2"))
	for side in [-1, 1]:
		var cx := r.position.x - 8 if side < 0 else r.end.x - 6
		var cur := PackedVector2Array([Vector2(cx, r.position.y - 8), Vector2(cx + 14, r.position.y - 8), Vector2(cx + 14 - side * 6, r.end.y - 30), Vector2(cx + 7, r.end.y), Vector2(cx - side * 6, r.end.y - 30)])
		ci.draw_colored_polygon(cur, Color("#13807b")); ci.draw_polyline(cur + PackedVector2Array([cur[0]]), INK, 1.6, true)
	ci.draw_line(Vector2(r.position.x - 14, r.position.y - 9), Vector2(r.end.x + 14, r.position.y - 9), INK, 3)
	_sill_cactus(ci)

## A little cactus in a pot on the window sill.
static func _sill_cactus(ci: Control) -> void:
	var p := PackedVector2Array([Vector2(36, 109), Vector2(48, 109), Vector2(46, 120), Vector2(38, 120)])
	ci.draw_colored_polygon(p, Color("#c97b5a")); ci.draw_polyline(p + PackedVector2Array([p[0]]), INK, 1.2, true)
	var cac := Art.rrect(Vector2(42, 101), 3.2, 8, 3)
	ci.draw_colored_polygon(cac, Color("#5a9a4a")); ci.draw_polyline(cac + PackedVector2Array([cac[0]]), INK, 1.2, true)
	ci.draw_polyline(PackedVector2Array([Vector2(45, 102), Vector2(49, 102), Vector2(49, 96)]), INK, 3.4, true)
	ci.draw_polyline(PackedVector2Array([Vector2(45, 102), Vector2(49, 102), Vector2(49, 96)]), Color("#5a9a4a"), 1.8, true)
	ci.draw_circle(Vector2(42, 93), 1.6, Color("#f08aa0"))

## The ceiling: crown molding and a ceiling fan turning, its light on in the evening.
static func _ceiling(ci: Control, t: float, dk: float) -> void:
	ci.draw_rect(Rect2(0, -TOP, W, TOP), Color("#f6efdf"))
	ci.draw_rect(Rect2(0, -6, W, 6), Color("#f4ead2"))
	ci.draw_line(Vector2(0, -6), Vector2(W, -6), Color("#d8c8a8"), 1.2)
	ci.draw_line(Vector2(0, 0), Vector2(W, 0), Color("#cdb994"), 1.5)
	# the fan
	var fx := 280.0
	ci.draw_line(Vector2(fx, -TOP), Vector2(fx, -16), INK, 2.4)
	var a := t * 5.0
	for k in 2:
		var ang := a + k * PI / 2
		var L := 64.0 * cos(ang)
		var bl := PackedVector2Array([Vector2(fx, -14), Vector2(fx + L, -15 - 2 * sin(ang)), Vector2(fx + L, -11 - 2 * sin(ang)), Vector2(fx, -10)])
		ci.draw_colored_polygon(bl, Color("#a8743f")); ci.draw_polyline(bl + PackedVector2Array([bl[0]]), INK, 1.2, true)
	Art.ellipse(ci, Vector2(fx, -12), 9, 4, Color("#c9a574"))
	ci.draw_arc(Vector2(fx, -12), 9, PI, TAU, 10, INK, 1.2)
	var glow := dk > 0.05
	ci.draw_circle(Vector2(fx, -4), 6, Color("#fff1c4") if glow else Color("#f4ead2"))
	ci.draw_arc(Vector2(fx, -4), 6, 0, TAU, 14, INK, 1.2)
	ci.draw_line(Vector2(fx + 6, -10), Vector2(fx + 6, -1 + sin(t * 2) * 0.5), Color("#9aa4a8"), 1)
	ci.draw_circle(Vector2(fx + 6, -1), 1.3, Color("#9aa4a8"))

## The front door, a clock over it showing the real time, a doormat, and what's hanging on the hooks.
static func _door(ci: Control, t: float) -> void:
	var r := Rect2(584, 44, 48, FLOOR_Y - 44)
	_box(ci, r.grow(4), Color("#f4ead2"))
	_box(ci, r, Color("#2b7ea6"))
	for p in [Rect2(590, 54, 36, 30), Rect2(590, 94, 16, 50), Rect2(610, 94, 16, 50), Rect2(590, 150, 36, 52)]:
		ci.draw_rect(p, Color("#246c90")); ci.draw_rect(p, Color(INK, 0.5), false, 1.2)
	ci.draw_rect(Rect2(592, 56, 32, 26), Color("#bfe3ea"))   # the little window in the door
	ci.draw_line(Vector2(596, 78), Vector2(604, 60), Color(1, 1, 1, 0.6), 2)
	ci.draw_circle(Vector2(590, 132), 3, SUN); ci.draw_arc(Vector2(590, 132), 3, 0, TAU, 10, INK, 1.2)
	ci.draw_rect(Rect2(588, 118, 4, 5), Color("#9aa4a8"))
	# the clock
	var cc := Vector2(608, 18)
	ci.draw_circle(cc, 13, PAPER); ci.draw_arc(cc, 13, 0, TAU, 24, INK, 2)
	for i in 12: ci.draw_line(cc + Vector2.from_angle(i * TAU / 12) * 10, cc + Vector2.from_angle(i * TAU / 12) * 12, INK, 1)
	var h := Game.hour()
	ci.draw_line(cc, cc + Vector2.from_angle(fmod(h, 12.0) / 12.0 * TAU - PI / 2) * 6.5, INK, 2.2)
	ci.draw_line(cc, cc + Vector2.from_angle(fmod(float(Game.S.min), 60.0) / 60.0 * TAU - PI / 2) * 10, INK, 1.4)
	ci.draw_circle(cc, 1.5, CORAL)
	# hooks: a bucket hat, the landing net and, if you have them, the disguises
	ci.draw_rect(Rect2(560, 60, 18, 4), WOOD)
	var hat := PackedVector2Array([Vector2(561, 74), Vector2(577, 74), Vector2(574, 64), Vector2(564, 64)])
	ci.draw_colored_polygon(hat, Color("#c9b78a")); ci.draw_polyline(hat + PackedVector2Array([hat[0]]), INK, 1.2, true)
	Art.ellipse(ci, Vector2(569, 74), 11, 2.5, Color("#b8a578"))
	ci.draw_line(Vector2(571, 64), Vector2(571, 104), INK, 2.4)
	ci.draw_arc(Vector2(571, 112), 9, 0, TAU, 16, INK, 1.6)
	for i in 4: ci.draw_line(Vector2(564 + i * 4.5, 104), Vector2(566 + i * 3, 120), Color(INK, 0.5), 0.8)
	if Game.S.gear.has("lanyard"):
		ci.draw_polyline(PackedVector2Array([Vector2(563, 63), Vector2(560, 84), Vector2(566, 86), Vector2(565, 63)]), CORAL, 1.4)
		_box(ci, Rect2(558, 84, 9, 11), PAPER, 1)
	# waders standing by the door
	if Game.S.gear.has("waders"):
		var wd := PackedVector2Array([Vector2(560, 150), Vector2(578, 150), Vector2(578, 208), Vector2(582, 212), Vector2(568, 213), Vector2(568, 176), Vector2(566, 213), Vector2(556, 212), Vector2(560, 206)])
		ci.draw_colored_polygon(wd, Color("#3f5a3a")); ci.draw_polyline(wd + PackedVector2Array([wd[0]]), INK, 1.4, true)
		ci.draw_line(Vector2(562, 150), Vector2(564, 136), INK, 1.4); ci.draw_line(Vector2(576, 150), Vector2(574, 136), INK, 1.4)
	else:
		for k in 2:
			var fl := Art.rrect(Vector2(566 + k * 9, 211), 3.5, 2, 2)
			ci.draw_colored_polygon(fl, CORAL); ci.draw_polyline(fl + PackedVector2Array([fl[0]]), INK, 1, true)
	# light switch, and the mat
	_box(ci, Rect2(566, 124, 7, 11), PAPER, 1); ci.draw_rect(Rect2(568.5, 127, 2, 4), INK)
	var mat := Rect2(578, FLOOR_Y + 4, 60, 12)
	ci.draw_rect(mat, Color("#8a6a3a")); ci.draw_rect(mat, INK, false, 1.2)
	_txt(ci, Vector2(608, FLOOR_Y + 13), "GONE FISHIN'", 7, PAPER)

## A snake plant in a pot between the tank and the couch.
static func _plant(ci: Control, t: float) -> void:
	for i in 6:
		var bx := 150.0 + i * 3.0
		var tip := Vector2(bx + (i - 2.5) * 3 + sin(t * 0.7 + i) * 0.8, 150 + fmod(i * 13.0, 22.0))
		var lf := PackedVector2Array([Vector2(bx - 2, 198), tip, Vector2(bx + 3, 198)])
		ci.draw_colored_polygon(lf, Color("#4f8a3f") if i % 2 == 0 else Color("#6aa44e"))
		ci.draw_polyline(lf, INK, 1.1, true)
		ci.draw_line(Vector2(bx + 0.5, 196), tip.lerp(Vector2(bx, 196), 0.3), Color("#d8d27a"), 0.8)
	var pot := PackedVector2Array([Vector2(147, 196), Vector2(171, 196), Vector2(168, FLOOR_Y), Vector2(150, FLOOR_Y)])
	ci.draw_colored_polygon(pot, Color("#e2583e")); ci.draw_polyline(pot + PackedVector2Array([pot[0]]), INK, 1.4, true)
	ci.draw_rect(Rect2(146, 194, 26, 4), Color("#c94a33")); ci.draw_rect(Rect2(146, 194, 26, 4), INK, false, 1.2)

## The coffee table: a mug (steaming in the morning), the remote and a fishing magazine.
static func _table(ci: Control, t: float) -> void:
	_box(ci, Rect2(226, FLOOR_Y + 12, 112, 6), Color("#a8743f"))
	for x in [232.0, 328.0]: ci.draw_rect(Rect2(x, FLOOR_Y + 18, 4, 22), INK)
	ci.draw_rect(Rect2(236, FLOOR_Y + 30, 92, 3), Color("#7a4e2e"))
	var mag := PackedVector2Array([Vector2(282, FLOOR_Y + 12), Vector2(312, FLOOR_Y + 10), Vector2(314, FLOOR_Y + 12)])
	ci.draw_rect(Rect2(284, FLOOR_Y + 9, 30, 3), Color("#13807b")); ci.draw_rect(Rect2(284, FLOOR_Y + 9, 30, 3), INK, false, 1)
	ci.draw_colored_polygon(mag, Color("#f2b134"))
	_box(ci, Rect2(318, FLOOR_Y + 9, 12, 3), Color("#3a3a3a"), 1)
	ci.draw_circle(Vector2(322, FLOOR_Y + 10), 0.8, CORAL)
	_box(ci, Rect2(244, FLOOR_Y + 1, 10, 11), PAPER, 1.2)
	ci.draw_arc(Vector2(255, FLOOR_Y + 6), 3, -PI / 2, PI / 2, 8, INK, 1.4)
	ci.draw_rect(Rect2(244, FLOOR_Y + 4, 10, 2), CORAL)
	var h := Game.hour()
	if h >= 5 and h < 11:
		for k in 2:
			var pts := PackedVector2Array()
			for i in 8:
				var u := i / 7.0
				pts.append(Vector2(247 + k * 4 + sin(t * 3 + u * 5 + k) * 2, FLOOR_Y - 2 - u * 16))
			ci.draw_polyline(pts, Color(1, 1, 1, 0.7), 1.2, true)

## By day, sunlight falls through the window across the floor, with dust floating in it.
static func _sunbeam(ci: Control, t: float, dk: float) -> void:
	var a := 0.1 * (1.0 - dk * 2.0) * (1.0 - clampf(float(Game.wx.rain) * 2 + float(Game.wx.cloud) * 0.5, 0, 0.9))
	if a <= 0.01: return
	ci.draw_colored_polygon(PackedVector2Array([Vector2(34, 30), Vector2(130, 30), Vector2(250, FLOOR_Y + 40), Vector2(130, FLOOR_Y + 40)]), Color(1, 0.94, 0.7, a))
	for i in 14:
		var u := fmod(i * 0.137 + t * 0.03, 1.0)
		var p := Vector2(60 + u * 120 + fmod(i * 23.0, 40.0) + sin(t * 0.7 + i) * 4, 40 + u * 200)
		ci.draw_circle(p, 0.9, Color(1, 1, 0.9, a * 6 * sin(u * PI)))

## The big tank if you bought it (your best catches swimming in it), otherwise a goldfish bowl.
static func _tank(ci: Control, t: float) -> void:
	if Game.S.gear.has("bigtank"):
		var r := Rect2(18, 158, 128, 42)
		_box(ci, Rect2(14, 200, 136, FLOOR_Y - 200), Color("#5c3a22"))
		ci.draw_rect(r, Color("#7cc6d6"))
		ci.draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), Color("#e3cf9a"))
		for i in 5:
			var x := r.position.x + 10 + i * 26.0
			ci.draw_polyline(PackedVector2Array([Vector2(x, r.end.y - 6), Vector2(x + sin(t * 1.5 + i) * 3, r.end.y - 18), Vector2(x + sin(t * 1.5 + i + 1) * 4, r.end.y - 28)]), Color("#3f8a4a"), 2.4, true)
		var kinds := []
		for n in Game.S.journal:
			if not Game.S.journal[n].get("legend", false): kinds.append(n)
		if kinds.is_empty(): kinds = ["Goldfish"]
		for i in mini(kinds.size(), 5):
			var sp := 0.25 + fmod(i * 0.37, 0.3)
			var ph := fmod(t * sp + i * 0.31, 2.0)
			var dir := 1.0 if ph < 1.0 else -1.0
			var u := ph if ph < 1.0 else 2.0 - ph
			var p := Vector2(r.position.x + 14 + u * (r.size.x - 28), r.position.y + 10 + fmod(i * 7.3, 20.0) + sin(t * 2 + i) * 2)
			ItemIcons._fish_at(ci, p, -0.28 * dir, ItemIcons.fish_color(str(kinds[i])))
		var cs := PackedVector2Array([Vector2(98, 192), Vector2(98, 178), Vector2(101, 178), Vector2(101, 181), Vector2(104, 181), Vector2(104, 176), Vector2(108, 176), Vector2(108, 181), Vector2(111, 181), Vector2(111, 178), Vector2(114, 178), Vector2(114, 192)])
		ci.draw_colored_polygon(cs, Color("#b8bcb8")); ci.draw_polyline(cs + PackedVector2Array([cs[0]]), INK, 1.1, true)
		ci.draw_rect(Rect2(104, 186, 4, 6), Color("#3a4a52"))
		_box(ci, Rect2(30, 184, 12, 8), Color("#8a5a35"), 1); ci.draw_rect(Rect2(30, 186, 12, 1.5), SUN)
		for i in 6:
			var by := r.end.y - 10 - fmod(t * 14 + i * 9, r.size.y - 12)
			ci.draw_arc(Vector2(r.end.x - 14 + sin(t * 3 + i) * 2, by), 1.6, 0, TAU, 8, Color(1, 1, 1, 0.8), 1.0)
		ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 3, 6, r.size.y - 14), Color(1, 1, 1, 0.25))
		ci.draw_rect(r, INK, false, 2.5)
		_box(ci, Rect2(r.position.x - 3, r.position.y - 6, r.size.x + 6, 6), Color("#2c3338"))
	else:
		# a side table with a goldfish bowl
		_box(ci, Rect2(48, 186, 64, 6), Color("#c9a574"))
		ci.draw_line(Vector2(56, 192), Vector2(54, FLOOR_Y), INK, 3); ci.draw_line(Vector2(104, 192), Vector2(106, FLOOR_Y), INK, 3)
		ci.draw_circle(Vector2(80, 170), 17, Color("#bfe3ea", 0.9))
		ci.draw_rect(Rect2(64, 155, 32, 6), Color("#e9d7b3"))
		var gx := 80 + sin(t * 0.9) * 8
		ItemIcons._fish_at(ci, Vector2(gx, 172), 0.2 * signf(cos(t * 0.9)), Color("#f29a2e"))
		ci.draw_arc(Vector2(80, 170), 17, deg_to_rad(-60), deg_to_rad(240), 24, INK, 2)

## Your legends, mounted on little wooden shields above the couch, heaviest first.
static func _mounts(ci: Control) -> void:
	var m := mounts()
	var x0 := 176.0; var y0 := 8.0
	_box(ci, Rect2(232, y0, 96, 14), Color("#5c3a22"), 1.5)
	_txt(ci, Vector2(280, y0 + 11), "MY LEGENDS  %d/%d" % [Story.legends_got(), Story.legends_all()], 9, SUN)
	for i in MAX_MOUNTS:
		var col := i % 6; var row := i / 6
		var c := Vector2(x0 + 18 + col * 42, y0 + 38 + row * 40)
		var sh := PackedVector2Array([c + Vector2(-17, -16), c + Vector2(17, -16), c + Vector2(17, 6), c + Vector2(0, 18), c + Vector2(-17, 6)])
		if i < m.size():
			ci.draw_colored_polygon(sh, Color("#8a5a35")); ci.draw_polyline(sh + PackedVector2Array([sh[0]]), INK, 1.6, true)
			var hue := Town.hash2(m[i].n.length(), i)
			ItemIcons._fish_at(ci, c + Vector2(1, -3), 0.42, Color("#e9b23a").lerp(Color("#f2d27a") if hue > 0.5 else Color("#d98a2a"), 0.5))
			ci.draw_rect(Rect2(c + Vector2(-8, 8), Vector2(16, 4)), Color("#d6b25c"))
		elif i == m.size() and i < MAX_MOUNTS:
			# an empty hook waiting for the next one
			ci.draw_polyline(sh + PackedVector2Array([sh[0]]), Color(INK, 0.25), 1.4, true)
			_txt(ci, c + Vector2(0, 4), "?", 14, Color(INK, 0.3), Game.font_display)
	if m.size() > MAX_MOUNTS:
		_txt(ci, Vector2(x0 + 268, y0 + 84), "+%d" % (m.size() - MAX_MOUNTS), 12, INK)

## A shelf of Slam cups: gold, silver and bronze for every top-three finish.
static func _cups(ci: Control) -> void:
	_box(ci, Rect2(182, 126, 196, 6), Color("#c9a574"), 1.5)
	var tr: Array = Game.S.trophies.filter(func(x): return int(x.place) >= 1 and int(x.place) <= 3)
	if tr.is_empty():
		_txt(ci, Vector2(280, 122), "(room for Slam cups)", 9, Color(INK, 0.35))
		return
	for i in mini(tr.size(), 12):
		var place := int(tr[i].place)
		var col: Color = [SUN, Color("#c8d0d6"), Color("#c98a52")][place - 1]
		var cx := 192 + i * 15.0
		var k := 1.0 if place == 1 else 0.82
		var by := 126.0
		var cup := PackedVector2Array([Vector2(cx - 5 * k, by - 16 * k), Vector2(cx + 5 * k, by - 16 * k), Vector2(cx + 3 * k, by - 8 * k), Vector2(cx + 1, by - 5 * k), Vector2(cx + 3, by), Vector2(cx - 3, by), Vector2(cx - 1, by - 5 * k), Vector2(cx - 3 * k, by - 8 * k)])
		ci.draw_colored_polygon(cup, col); ci.draw_polyline(cup + PackedVector2Array([cup[0]]), INK, 1.2, true)

## The couch, with the cat asleep on it.
static func _couch(ci: Control, t: float) -> void:
	_box(ci, Rect2(182, 140, 196, 40), Color("#2b7ea6"))         # back
	for i in 3: _box(ci, Rect2(190 + i * 61, 146, 58, 30), Color("#3a8fb8"), 1.5)
	_box(ci, Rect2(176, 172, 208, 28), Color("#2b7ea6"))          # seat
	for i in 3: _box(ci, Rect2(184 + i * 64, 168, 62, 14), Color("#4a9cc4"), 1.5)
	_box(ci, Rect2(168, 156, 18, 46), Color("#246c90")); _box(ci, Rect2(374, 156, 18, 46), Color("#246c90"))
	for x in [180.0, 372.0]: ci.draw_rect(Rect2(x, 200, 6, FLOOR_Y + 6 - 200), INK)
	# a throw pillow and the cat
	var pl := PackedVector2Array([Vector2(196, 152), Vector2(222, 148), Vector2(226, 170), Vector2(198, 172)])
	ci.draw_colored_polygon(pl, SUN); ci.draw_polyline(pl + PackedVector2Array([pl[0]]), INK, 1.5, true)
	var c := Vector2(320, 162)
	var breathe := 1.0 + sin(t * 1.6) * 0.04
	_cat(ci, c, breathe, t)

## A ginger cat curled up asleep, breathing, with the tip of its tail flicking now and then.
## Pet him and he wakes up for a few seconds: a big stretch and a yawn, a roll onto his back
## with his paws in the air, or a purr with his head up and his tail going. Hearts float up.
static func _cat(ci: Control, c: Vector2, breathe: float, t: float) -> void:
	var fur := Color("#e8964a")
	var dark := Art.shade(fur, -0.25)
	var since := t - pet_t if test_since < 0 else test_since
	var petting := since >= 0 and since < PET_LEN
	# how far into the reaction he is: eases in, holds, eases back to sleep
	var e := clampf(minf(since / 0.45, (PET_LEN - since) / 0.6), 0, 1) if petting else 0.0
	e = e * e * (3 - 2 * e)
	var kind := pet_kind if petting else -1
	var cc := c
	if kind == 2: cc += Vector2(sin(t * 70) * 0.6 * e, 0)
	# tail
	var flick := maxf(0.0, sin(t * 0.8)) ** 8 * 6.0
	var tail: PackedVector2Array
	if kind == 0:
		# straight up, with a curl at the tip
		tail = _bez(cc + Vector2(18 + 6 * e, 0), cc + Vector2(30 + 8 * e, -4 - 6 * e), cc + Vector2(28 + 8 * e, -22 * e), cc + Vector2(34 + 8 * e + sin(t * 4) * 3 * e, -10 - 22 * e))
	elif kind >= 1:
		var sw := sin(t * (9.0 if kind == 2 else 5.0)) * 9.0 * e
		tail = _bez(cc + Vector2(18, 2), cc + Vector2(30, 8), cc + Vector2(36, 4 + sw * 0.3), cc + Vector2(40 + sw * 0.3, -4 + sw))
	else:
		tail = _bez(cc + Vector2(18, 3), cc + Vector2(30, 10), cc + Vector2(10, 14), cc + Vector2(-8, 9 - flick))
	ci.draw_polyline(tail, INK, 6, true); ci.draw_circle(tail[tail.size() - 1], 3, INK)
	ci.draw_polyline(tail, fur, 3.6, true); ci.draw_circle(tail[tail.size() - 1], 1.8, fur)
	# body: longer and lower in a stretch, rump up
	var rx := 22.0 + (9.0 * e if kind == 0 else 0.0)
	var ry := 9.0 * breathe - (2.5 * e if kind == 0 else 0.0)
	var body := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		var pt := cc + Vector2(cos(a) * rx - (4 * e if kind == 0 else 0.0), sin(a) * ry - 2)
		if kind == 0 and cos(a) > 0: pt.y -= cos(a) * 6 * e
		body.append(pt)
	# stretched-out front legs go under the body
	if kind == 0 and e > 0.05:
		for k in 2:
			var leg := PackedVector2Array([cc + Vector2(-16 - 4 * e, 3 + k * 2), cc + Vector2(-30 - 14 * e + k * 3, 7 + k)])
			ci.draw_polyline(leg, INK, 5.4, true); ci.draw_polyline(leg, fur, 3.2, true)
			ci.draw_circle(leg[1], 2.6, PAPER); ci.draw_arc(leg[1], 2.6, 0, TAU, 8, INK, 1)
	ci.draw_colored_polygon(body, fur); ci.draw_polyline(body + PackedVector2Array([body[0]]), INK, 1.6, true)
	var rolled := kind == 1 and e > 0.5
	if rolled:
		# belly up, four paws in the air
		Art.ellipse(ci, cc + Vector2(-2, -6), 14, 4, Color("#fbe3c4"))
		for k in 4:
			var bx := -13.0 + k * 8.5
			var wig := sin(t * 9 + k * 1.7) * 2.5
			var leg := PackedVector2Array([cc + Vector2(bx, -8), cc + Vector2(bx + wig * 0.5, -17 - absf(wig))])
			ci.draw_polyline(leg, INK, 5, true); ci.draw_polyline(leg, fur, 3, true)
			ci.draw_circle(leg[1], 2.4, PAPER); ci.draw_arc(leg[1], 2.4, 0, TAU, 8, INK, 1)
	else:
		for i in 3: ci.draw_line(cc + Vector2(-6 + i * 8, -10), cc + Vector2(-8 + i * 8, -4), dark, 2)
	# head
	var hd := cc + Vector2(-20, 1)
	if kind == 0: hd += Vector2(-14 * e, -5 * e)
	if kind == 2: hd += Vector2(-2 * e, -7 * e)
	if rolled: hd += Vector2(-2, 2)
	ci.draw_circle(hd, 8, fur); ci.draw_arc(hd, 8, 0, TAU, 16, INK, 1.6)
	var up := -1.0 if rolled else 1.0      # upside down when he's on his back
	for side in [-1, 1]:
		var ear := PackedVector2Array([hd + Vector2(side * 3 - 3, -6 * up), hd + Vector2(side * 6 - 2, -13 * up), hd + Vector2(side * 7 + 1, -4 * up)])
		ci.draw_colored_polygon(ear, fur); ci.draw_polyline(ear, INK, 1.4, true)
		var eye := hd + Vector2(side * 3.2, -0.5 * up)
		if kind == 0 and e > 0.3 and e < 0.75:
			ci.draw_circle(eye, 1.8, INK); ci.draw_circle(eye + Vector2(-0.5, -0.6), 0.6, Color.WHITE)   # awake
		elif kind >= 1 and e > 0.2:
			ci.draw_arc(eye + Vector2(0, 1.2 * up), 2, PI + 0.3 if up > 0 else 0.3, TAU - 0.3 if up > 0 else PI - 0.3, 6, INK, 1.3)   # happy ^ ^
		else:
			ci.draw_arc(eye, 2, 0.2, PI - 0.2, 6, INK, 1.2)   # asleep
	ci.draw_circle(hd + Vector2(0, 3 * up), 1.2, Color("#c94a33"))
	for side in [-1, 1]:
		ci.draw_line(hd + Vector2(side * 4, 3 * up), hd + Vector2(side * 11, 2 * up), Color(INK, 0.6), 0.8)
		ci.draw_line(hd + Vector2(side * 4, 4 * up), hd + Vector2(side * 11, 5.5 * up), Color(INK, 0.6), 0.8)
	if kind == 0 and e > 0.7:
		Art.ellipse(ci, hd + Vector2(0, 5), 2.4, 2.4 * (e - 0.7) / 0.3 + 0.5, Color("#7a2a2a"))   # a big yawn
	if petting:
		# hearts, and a purr
		for i in 3:
			var hp := since - i * 0.55
			if hp > 0 and hp < 2.0:
				_heart(ci, cc + Vector2(-14 + i * 12 + sin(hp * 4 + i) * 3, -16 - hp * 24), 3.2 + hp, Color(CORAL, 1.0 - hp / 2.0))
		if kind == 2 or kind == 1:
			var pr := hd + Vector2(-16 + sin(t * 30) * 0.8, -14)
			_txt(ci, pr, "prrr", 9, Color(INK, e), Game.font_display)
	else:
		var zt := fmod(t * 0.5, 1.0)
		_txt(ci, hd + Vector2(-4 - zt * 6, -14 - zt * 14), "z", 8 + int(zt * 4), Color(INK, 1.0 - zt), Game.font_display)

## A smooth curve through four control points (a cubic Bezier), for the tail.
static func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		out.append(a.bezier_interpolate(b, c, d, u))
	return out

static func _heart(ci: Control, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(-r * 0.5, 0), r * 0.55, col)
	ci.draw_circle(p + Vector2(r * 0.5, 0), r * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.02, r * 0.15), p + Vector2(r * 1.02, r * 0.15), p + Vector2(0, r * 1.2)]), col)

## A floor lamp next to the couch: on in the evening.
static func _lamp(ci: Control, dk: float) -> void:
	var on := dk > 0.05
	ci.draw_line(Vector2(404, 132), Vector2(404, FLOOR_Y), INK, 3)
	ci.draw_rect(Rect2(394, FLOOR_Y - 3, 20, 4), INK)
	var shade := PackedVector2Array([Vector2(392, 132), Vector2(416, 132), Vector2(411, 108), Vector2(397, 108)])
	ci.draw_colored_polygon(shade, Color("#ffe39a") if on else Color("#f4ead2"))
	ci.draw_polyline(shade + PackedVector2Array([shade[0]]), INK, 1.5, true)

## The rod rack: every rod you own, plus the one you built.
static func _rods(ci: Control, t: float) -> void:
	_box(ci, Rect2(424, 186, 50, 10), WOOD)
	_box(ci, Rect2(424, 60, 50, 6), WOOD)
	var ids := rods_owned()
	var cols := { "rod0": [Color("#c9a55c"), Color("#3a3a3a")], "rod1": [Color("#3f7d4e"), Color("#c79a62")], "rod2": [Color("#2b2f36"), Color("#d9cbb0")],
		"rod3": [Color("#efe6d2"), Color("#c79a62")], "rod4": [Color("#2a3e5c"), Color("#3a3a3a")] }
	var list := []
	for id in ids: list.append(cols[id])
	if not Game.S.homerod.is_empty():
		list.append([Color("#2b2f36") if int(Game.S.homerod.lvl) >= 2 else Color("#c4b85a"), Color("#d9cbb0")])
	for i in list.size():
		var x := 430 + i * (38.0 / maxf(1, list.size() - 1)) if list.size() > 1 else 449.0
		ci.draw_line(Vector2(x, 190), Vector2(x + 1, 30), INK, 4.2)
		ci.draw_line(Vector2(x, 190), Vector2(x + 1, 30), list[i][0], 2.4)
		_box(ci, Rect2(x - 2.5, 160, 5, 28), list[i][1], 1.2)
		ci.draw_circle(Vector2(x + 3, 156), 4, Color("#9aa4a8")); ci.draw_arc(Vector2(x + 3, 156), 4, 0, TAU, 12, INK, 1.2)
		if i == list.size() - 1 and not Game.S.homerod.is_empty():
			_txt(ci, Vector2(x, 26), "★", 9, SUN)
	if Game.S.gear.has("rod3"):
		var sp := 0.5 + 0.5 * sin(t * 3)
		ItemIcons._sparkle(ci, Vector2(441 + sp, 70), 4.0 * sp + 1.0, Color(1, 0.95, 0.7, sp))

## The workbench: a pegboard with the parts you've found, a calendar, Lou's note if he's called,
## the jar you keep your cash in, and your cooler on the floor.
static func _bench(ci: Control, t: float) -> void:
	_box(ci, Rect2(482, 52, 72, 92), Color("#d8b98a"))
	for yy in 7:
		for xx in 6: ci.draw_circle(Vector2(490 + xx * 11, 60 + yy * 12), 1.1, Color("#a88a5e"))
	var have := []
	for p in Crafting.PARTS:
		if Crafting.count(p) > 0: have.append(p)
	for i in mini(have.size(), 9):
		_icon(ci, have[i], Rect2(486 + (i % 3) * 22, 62 + (i / 3) * 26, 22, 22), t)
	if have.is_empty(): _txt(ci, Vector2(518, 102), "no parts", 9, Color(INK, 0.45))
	# the calendar, with Slam day circled
	var day := int(Game.S.day)
	_box(ci, Rect2(490, 10, 52, 36), PAPER, 1.5)
	ci.draw_rect(Rect2(490, 10, 52, 10), CORAL)
	_txt(ci, Vector2(516, 18), "DAY", 8, PAPER)
	_txt(ci, Vector2(516, 41), str(day), 18, INK, Game.font_display)
	if day % 7 == 0: ci.draw_arc(Vector2(516, 34), 13, 0, TAU, 20, CORAL, 1.6)
	# Lou's note, pinned up once he's called
	if int(Game.S.saga.ch) >= 1:
		var nt := PackedVector2Array([Vector2(110, 92), Vector2(134, 90), Vector2(136, 116), Vector2(112, 118)])
		ci.draw_colored_polygon(nt, Color("#fff7c4")); ci.draw_polyline(nt + PackedVector2Array([nt[0]]), INK, 1.2, true)
		for i in 3: ci.draw_line(Vector2(115, 98 + i * 6), Vector2(131, 97 + i * 6), Color(INK, 0.5), 1)
		ci.draw_rect(Rect2(117, 88, 12, 5), Color(1, 1, 1, 0.6))
	# bench
	_box(ci, Rect2(478, 150, 82, 10), Color("#a8743f"))
	ci.draw_rect(Rect2(484, 160, 6, FLOOR_Y - 160), INK); ci.draw_rect(Rect2(548, 160, 6, FLOOR_Y - 160), INK)
	ci.draw_rect(Rect2(484, 192, 70, 4), Color("#5c3a22"))
	# the cash jar fills up with what you're carrying
	var fill := clampf(float(Game.S.cash) / 1500.0, 0.05, 1.0)
	ci.draw_rect(Rect2(530, 150 - 22 * fill, 18, 22 * fill), Color("#6fae5a"))
	ci.draw_rect(Rect2(530, 128, 18, 22), Color(1, 1, 1, 0.22))
	ci.draw_rect(Rect2(530, 128, 18, 22), INK, false, 1.4)
	ci.draw_rect(Rect2(528, 124, 22, 5), Color("#9aa4a8")); ci.draw_rect(Rect2(528, 124, 22, 5), INK, false, 1.2)
	# a home-made lure drying on the bench
	for l in Game.S.lures:
		if int(Game.S.lures[l]) > 0:
			_icon(ci, l, Rect2(488, 128, 24, 24), t); break
	# the cooler by the door
	_icon(ci, "mcooler" if Game.S.gear.has("mcooler") else "cooler", Rect2(486, 196, 40, 40))
