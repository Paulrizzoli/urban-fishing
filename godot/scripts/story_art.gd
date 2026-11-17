class_name StoryArt
extends RefCounted
## Little illustrated panels for the story cards: Lou behind his counter, Trent on the TV,
## and the marina. Each draws into a Control, scaled from a 560-wide design.

const INK := Color("#22313a")
const PAPER := Color("#fbf3e2")
const SUN := Color("#f2b134")
const CORAL := Color("#e2583e")
const TEAL := Color("#13807b")
const SEA := Color("#2b7ea6")

## Scales the 560-wide design to fit the control, centered. Returns [offset, scale].
static func _fit(ci: Control, design_h: float, extra_scale := Vector2.ONE, at := Vector2.ZERO) -> Array:
	var s := minf(ci.size.x / 560.0, ci.size.y / design_h)
	var o := Vector2((ci.size.x - 560.0 * s) / 2.0, (ci.size.y - design_h * s) / 2.0)
	ci.draw_set_transform(o + at * s, 0, extra_scale * s)
	return [o, s]

static func _txt(ci: Control, p: Vector2, s: String, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Game.font_display
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, p - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _frame(ci: Control, h: float) -> void:
	var f := _fit(ci, h)
	ci.draw_set_transform(Vector2.ZERO)
	var r := Rect2(f[0], Vector2(560, h) * f[1])
	var fr := StyleBoxFlat.new()
	fr.bg_color = Color(0, 0, 0, 0); fr.border_color = INK; fr.set_border_width_all(2)
	ci.draw_style_box(fr, r)

static func _wood(ci: Control, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, 560, h), Color("#8a5a35"))
	for i in 15: ci.draw_rect(Rect2(i * 40, 0, 3, h), Color("#7a4e2e"))

static func lou(ci: Control) -> void:
	_fit(ci, 160)
	_wood(ci, 118)
	# chalkboard
	ci.draw_rect(Rect2(17, 11, 166, 84), Color("#c9a574"))
	ci.draw_rect(Rect2(20, 14, 160, 78), Color("#2d3b33"))
	_txt(ci, Vector2(100, 37), "TODAY", 16, PAPER)
	ci.draw_string(Game.font_body, Vector2(34, 58), "Live shrimp · $3/doz", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	ci.draw_string(Game.font_body, Vector2(34, 78), "Ice $2 · NO credit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SUN)
	# the tarpon
	ci.draw_rect(Rect2(324, 18, 178, 60), Color("#5c3a22"))
	var fish := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		fish.append(Vector2(336 + t * 126, 48 - sin(t * PI) * 28 * (1.0 - t * 0.35)))
	fish.append(Vector2(482, 24)); fish.append(Vector2(476, 48)); fish.append(Vector2(482, 72))
	for i in 21:
		var t := 1.0 - i / 20.0
		fish.append(Vector2(336 + t * 126, 48 + sin(t * PI) * 28 * (1.0 - t * 0.35)))
	ci.draw_colored_polygon(fish, Color("#d6dee2"))
	ci.draw_polyline(fish + PackedVector2Array([fish[0]]), INK, 2.5, true)
	ci.draw_circle(Vector2(352, 44), 3.5, INK)
	ci.draw_line(Vector2(370, 33), Vector2(370, 63), Color(INK, 0.35), 2)
	_txt(ci, Vector2(404, 98), "LOU'S TARPON · 1987 · \"142 LB\"", 11, SUN, Game.font_bold)
	# Lou
	var c := Vector2(272, 76)
	_fit(ci, 160, Vector2(1, 0.72), c)
	ci.draw_circle(Vector2(0, 64), 50, TEAL)
	_fit(ci, 160)
	for p in [[Vector2(-18, 34), 5], [Vector2(14, 50), 5], [Vector2(24, 30), 4]]: ci.draw_circle(c + p[0], p[1], SUN)
	ci.draw_circle(c, 28, Color("#e0b48c"))
	var cap := PackedVector2Array()
	for i in 17: cap.append(c + Vector2(-28 + i * 3.5, -5 - sin(i / 16.0 * PI) * 26))
	ci.draw_colored_polygon(cap, CORAL)
	ci.draw_rect(Rect2(c + Vector2(-6, -14), Vector2(44, 8)), Color("#c94a33"))
	_txt(ci, c + Vector2(0, -15), "LOU", 10, PAPER)
	ci.draw_circle(c + Vector2(-10, 1), 2.8, INK); ci.draw_circle(c + Vector2(10, 1), 2.8, INK)
	var mus := PackedVector2Array([c + Vector2(-16, 12), c + Vector2(-8, 8), c + Vector2(0, 7.5), c + Vector2(8, 8), c + Vector2(16, 12), c + Vector2(8, 16), c + Vector2(0, 17), c + Vector2(-8, 16)])
	ci.draw_colored_polygon(mus, Color("#7a5a40"))
	# counter
	ci.draw_rect(Rect2(0, 118, 560, 42), Color("#c9a574"))
	ci.draw_rect(Rect2(0, 114, 560, 8), Color("#e8d7a5"))
	ci.draw_rect(Rect2(105, 90, 40, 28), Color("#bfe3ea", 0.85)); ci.draw_rect(Rect2(105, 90, 40, 28), INK, false, 2)
	for p in [Vector2(117, 106), Vector2(130, 101), Vector2(128, 111)]: ci.draw_circle(p, 4.5, Color("#f3a6a0"))
	ci.draw_rect(Rect2(492, 96, 58, 20), Color("#3d4a52")); ci.draw_rect(Rect2(500, 88, 42, 11), Color("#9fc4d6"))
	ci.draw_rect(Rect2(196, 104, 44, 12), CORAL)
	_txt(ci, Vector2(218, 113.5), "TALL TALES", 8, Color.WHITE, Game.font_bold)
	# the coffee can
	ci.draw_rect(Rect2(420, 96, 26, 22), Color("#b9c2c7")); ci.draw_rect(Rect2(420, 102, 26, 10), CORAL)
	_txt(ci, Vector2(433, 110), "NOTE", 7, Color.WHITE, Game.font_bold)
	_frame(ci, 160)

static func tv(ci: Control) -> void:
	_fit(ci, 150)
	_wood(ci, 150)
	ci.draw_rect(Rect2(150, 10, 260, 130), INK)
	ci.draw_rect(Rect2(162, 20, 236, 104), SEA)
	ci.draw_rect(Rect2(162, 86, 236, 38), TEAL)
	ci.draw_circle(Vector2(360, 40), 14, SUN)
	var c := Vector2(250, 82)
	_fit(ci, 150, Vector2(1, 26.0 / 34.0), c + Vector2(0, 34))
	ci.draw_circle(Vector2.ZERO, 34, PAPER)
	_fit(ci, 150)
	ci.draw_rect(Rect2(c + Vector2(-32, 20), Vector2(64, 8)), CORAL)
	ci.draw_rect(Rect2(c + Vector2(-20, 36), Vector2(12, 8)), SEA)
	ci.draw_rect(Rect2(c + Vector2(4, 34), Vector2(16, 7)), SUN)
	ci.draw_circle(c, 21, Color("#e9c29a"))
	var hair := PackedVector2Array()
	for i in 13: hair.append(c + Vector2(-21 + i * 3.5, -6 - sin(i / 12.0 * PI) * 22))
	ci.draw_colored_polygon(hair, Color("#f2d16b"))
	ci.draw_circle(c + Vector2(-7, -2), 2.4, INK); ci.draw_circle(c + Vector2(7, -2), 2.4, INK)
	ci.draw_rect(Rect2(c + Vector2(-10, 7), Vector2(20, 7)), Color.WHITE)
	# the bass he's holding up
	var f := Vector2(316, 92)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(Vector2(-30 + t * 52, -sin(t * PI) * 12))
	pts.append(Vector2(32, -12)); pts.append(Vector2(29, 0)); pts.append(Vector2(32, 12))
	for i in 13:
		var t := 1.0 - i / 12.0
		pts.append(Vector2(-30 + t * 52, sin(t * PI) * 12))
	var rot := Transform2D(-0.31, f)
	pts = rot * pts
	ci.draw_colored_polygon(pts, Color("#6f9a4a"))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2, true)
	ci.draw_rect(Rect2(168, 100, 88, 18), CORAL)
	_txt(ci, Vector2(212, 114), "REEL DEAL", 12, Color.WHITE)
	ci.draw_circle(Vector2(390, 30), 4, CORAL)
	ci.draw_string(Game.font_bold, Vector2(358, 34), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	ci.draw_rect(Rect2(250, 138, 60, 12), INK)
	_frame(ci, 150)

static func marina(ci: Control) -> void:
	_fit(ci, 130)
	for i in 16:
		ci.draw_rect(Rect2(0, i * 78.0 / 16.0, 560, 78.0 / 16.0 + 1), Color("#8fd3f0").lerp(Color("#d9f1fa"), i / 15.0))
	ci.draw_circle(Vector2(470, 34), 18, SUN)
	ci.draw_rect(Rect2(0, 78, 560, 52), Color("#2b93b6"))
	ci.draw_rect(Rect2(0, 78, 560, 6), Color("#74d6d4"))
	for r in [Rect2(40, 96, 60, 3), Rect2(250, 110, 80, 3), Rect2(420, 100, 50, 3)]: ci.draw_rect(r, Color(1, 1, 1, 0.5))
	ci.draw_rect(Rect2(20, 70, 520, 10), Color("#b38758"))
	for x in [60, 160, 260, 360, 460]: ci.draw_rect(Rect2(x, 70, 8, 26), Color("#6b4426"))
	_boat(ci, Vector2(110, 64), 46, 14, Color("#f4f6f8"))
	ci.draw_rect(Rect2(92, 50, 30, 14), Color("#e9edf0")); ci.draw_rect(Rect2(98, 54, 18, 6), SEA)
	_boat(ci, Vector2(300, 66), 34, 11, Color("#f4f6f8"))
	ci.draw_rect(Rect2(296, 56, 12, 10), Color("#3d4a52")); ci.draw_rect(Rect2(260, 62, 8, 12), INK)
	_txt(ci, Vector2(304, 75), "COFFEE CAN", 7, TEAL)
	_boat(ci, Vector2(450, 60), 62, 18, Color.WHITE)
	ci.draw_rect(Rect2(414, 42, 64, 18), Color("#f4f6f8")); ci.draw_rect(Rect2(422, 48, 48, 6), INK)
	_txt(ci, Vector2(450, 72), "REEL DEAL", 9, CORAL)
	ci.draw_rect(Rect2(190, 8, 180, 26), TEAL); ci.draw_rect(Rect2(190, 8, 180, 26), INK, false, 2)
	_txt(ci, Vector2(280, 27), "MULLET BAY MARINA", 15, Color.WHITE)
	_frame(ci, 130)

static func _boat(ci: Control, p: Vector2, hw: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(-hw, 0), p + Vector2(hw, 0), p + Vector2(hw * 0.74, h), p + Vector2(-hw * 0.87, h)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2)
