class_name JunkArt
## A picture of each bit of junk you can reel in, for the catch card and Lou's Sell tab.
## Each one is drawn in a 100 × 64 box centred on (0, 0) and scaled to fit.

const INK := Color(0.12, 0.14, 0.16, 0.9)

static func has(n: String) -> bool:
	return _fns().has(n)

static func _fns() -> Dictionary:
	return {
		"Soggy Flip-Flop": _flipflop, "Shopping Cart": _cart, "Bicycle": _bike, "Dozen Golf Balls": _golf,
		"Cracked Phone": _phone, "Tri-County Hard Hat": _hardhat, "Rubber Duck": _duck, "Single Sneaker": _sneaker,
		"Toy Alligator": _toygator, "Lost Retainer": _retainer, "Somebody's Car Keys": _keys,
		"\"Florida Man's Greatest Hits\" VHS": _vhs, "Message in a Bottle": _bottle, "Gold Tooth": _tooth,
		"Wedding Ring": _ring, "Lost Kayak Paddle": _paddle, "Animatronic Fish Part": _robofish,
		"Lost Sunglasses": _shades, "HOA Violation Notice": _notice, "Luggage Tag (Cleveland)": _tag,
		"Bag of Airline Peanuts": _peanuts, "Lost Valet Ticket": _valet, "Sunken Scooter": _scooter,
		"Tourist's Selfie Stick": _selfie, "Cruise Ship Deck Chair": _chair, "Pirate Doubloon": _doubloon,
		"Weather Balloon": _balloon, "Lucky Penny": _penny, "Executive's Rolex": _rolex,
		"Fintastic Stock Certificate": _certificate, "Wishing Coins": _coins,
		"Traffic Cone": _cone, "Wooden Bobbin": _bobbin, "Empty Keg": _keg, "Home Run Ball": _baseball, "Foam Finger": _finger,
	}

## Draw the junk named n into r. False if there's no picture for it.
static func draw(ci: CanvasItem, n: String, r: Rect2, t := 0.0) -> bool:
	var fns := _fns()
	if not fns.has(n): return false
	var s := minf(r.size.x / 100.0, r.size.y / 64.0)
	_base = Transform2D(0.0, Vector2(s, s), 0.0, r.get_center())
	ci.draw_set_transform_matrix(_base)
	(fns[n] as Callable).call(ci, t)
	ci.draw_set_transform_matrix(_base)
	# a couple of drips: it did just come out of the water
	for i in 3:
		var k := fmod(t * 0.7 + i * 0.33, 1.0)
		ci.draw_circle(Vector2(-20 + i * 20, 22 + k * 8), 1.4 * (1.0 - k), Color(0.45, 0.7, 0.85, 0.6 * (1.0 - k)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true

static var _base := Transform2D.IDENTITY

## Tilt what's drawn next by a radians (inside the fitted box).
static func _rot(ci: CanvasItem, a: float) -> void:
	ci.draw_set_transform_matrix(_base * Transform2D(a, Vector2.ZERO))

static func _poly(ci: CanvasItem, pts: Array, fill: Color, lw := 1.4) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, fill)
	p.append(p[0])
	ci.draw_polyline(p, INK, lw)

static func _el(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, outline := true, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := i * TAU / 28
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, col)
	if outline:
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 1.3)

static func _rr(ci: CanvasItem, r: Rect2, rad: float, col: Color, outline := true) -> void:
	var pts := Art.rrect(r.get_center(), r.size.x / 2, r.size.y / 2, rad)
	ci.draw_colored_polygon(pts, col)
	if outline:
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 1.3)

static func _txt(ci: CanvasItem, p: Vector2, s: String, size: int, col: Color) -> void:
	var w := Game.font_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(Game.font_bold, p - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _weed(ci: CanvasItem, p: Vector2, len := 14.0) -> void:
	var pts := PackedVector2Array()
	for i in 8: pts.append(p + Vector2(sin(i * 1.2) * 2.5, -i * len / 7.0))
	ci.draw_polyline(pts, Color("#3f8a4a"), 2.2)

# ---------- the junk ----------

static func _flipflop(ci: CanvasItem, _t: float) -> void:
	_el(ci, Vector2(0, 0), 40, 15, Color("#2b7ea6"), true, -0.1)
	_el(ci, Vector2(-2, -1), 35, 11, Color("#5bb5a9"), false, -0.1)
	ci.draw_polyline(PackedVector2Array([Vector2(-14, -10), Vector2(12, 0), Vector2(-14, 10)]), Color("#f2b134"), 3.5)
	ci.draw_circle(Vector2(12, 0), 2.5, Color("#f2b134"))
	_weed(ci, Vector2(30, 8))

static func _cart(ci: CanvasItem, _t: float) -> void:
	var wire := Color("#9aa6ad")
	_poly(ci, [Vector2(-36, -22), Vector2(30, -22), Vector2(22, 8), Vector2(-28, 8)], Color(0.6, 0.66, 0.7, 0.25))
	for i in 7: ci.draw_line(Vector2(-34 + i * 10, -22), Vector2(-27 + i * 8, 8), wire, 1.5)
	for i in 3: ci.draw_line(Vector2(-36 + i * 2.5, -12 + i * 10), Vector2(29 - i * 2.5, -12 + i * 10), wire, 1.5)
	ci.draw_polyline(PackedVector2Array([Vector2(30, -22), Vector2(40, -30), Vector2(46, -30)]), Color("#e2583e"), 3.0)
	ci.draw_polyline(PackedVector2Array([Vector2(-28, 8), Vector2(-30, 18), Vector2(22, 18), Vector2(22, 8)]), wire, 2.0)
	for x in [-26, 18]:
		ci.draw_circle(Vector2(x, 22), 4.5, Color("#22313a")); ci.draw_circle(Vector2(x, 22), 1.6, Color("#9aa6ad"))
	_weed(ci, Vector2(-10, 8), 18); _weed(ci, Vector2(6, 8), 12)

static func _bike(ci: CanvasItem, _t: float) -> void:
	for x in [-26.0, 26.0]:
		ci.draw_arc(Vector2(x, 8), 17, 0, TAU, 32, Color("#22313a"), 3.0)
		for i in 8: ci.draw_line(Vector2(x, 8), Vector2(x, 8) + Vector2.from_angle(i * TAU / 8) * 16, Color(0.6, 0.6, 0.6, 0.6), 0.8)
	var fr := Color("#e2583e")
	ci.draw_polyline(PackedVector2Array([Vector2(-26, 8), Vector2(-6, 8), Vector2(14, -14), Vector2(-14, -14), Vector2(-26, 8)]), fr, 3.0)
	ci.draw_line(Vector2(-6, 8), Vector2(-16, -20), fr, 3.0)
	ci.draw_line(Vector2(14, -14), Vector2(26, 8), fr, 3.0)
	ci.draw_line(Vector2(14, -14), Vector2(12, -22), fr, 3.0)
	ci.draw_line(Vector2(6, -24), Vector2(18, -22), Color("#22313a"), 3.0)
	_el(ci, Vector2(-17, -22), 7, 2.5, Color("#22313a"))
	_weed(ci, Vector2(-30, 24), 16)

static func _golf(ci: CanvasItem, _t: float) -> void:
	# an open carton of a dozen, a bit soggy
	_poly(ci, [Vector2(-42, -22), Vector2(42, -22), Vector2(42, 24), Vector2(-42, 24)], Color("#2f6a3a"))
	for i in 6:
		for j in 2:
			var c := Vector2(-32.5 + i * 13, -11 + j * 13)
			ci.draw_circle(c, 6, Color("#f6f6f2")); ci.draw_arc(c, 6, 0, TAU, 16, INK, 1.0)
			for d in 3: ci.draw_circle(c + Vector2(-2 + d * 2, -1 + (d % 2) * 2), 0.7, Color(0, 0, 0, 0.2))
	_txt(ci, Vector2(0, 21), "PELICAN POINT", 6, Color("#f4efe4"))
	_weed(ci, Vector2(36, 24), 12)

static func _phone(ci: CanvasItem, _t: float) -> void:
	_rr(ci, Rect2(-15, -28, 30, 56), 5, Color("#22313a"))
	_rr(ci, Rect2(-12, -23, 24, 44), 2, Color("#5a7a8a"), false)
	ci.draw_polyline(PackedVector2Array([Vector2(-10, -18), Vector2(-2, -6), Vector2(-6, 2), Vector2(4, 12), Vector2(10, 18)]), Color(1, 1, 1, 0.8), 1.2)
	ci.draw_polyline(PackedVector2Array([Vector2(-2, -6), Vector2(8, -12)]), Color(1, 1, 1, 0.8), 1.0)
	ci.draw_polyline(PackedVector2Array([Vector2(-6, 2), Vector2(-11, 8)]), Color(1, 1, 1, 0.8), 1.0)
	ci.draw_circle(Vector2(0, -25.5), 1.2, Color("#5a6a74"))
	_weed(ci, Vector2(14, 26), 10)

static func _hardhat(ci: CanvasItem, _t: float) -> void:
	_el(ci, Vector2(0, 12), 42, 7, Color("#e0a020"))
	var dome := [Vector2(-28, 12)]
	for i in 13: dome.append(Vector2(-28 + i * 56.0 / 12.0, 12 - sin(i * PI / 12.0) * 30))
	_poly(ci, dome, Color("#f2b134"))
	ci.draw_line(Vector2(0, -18), Vector2(0, 10), Color("#e0a020"), 5.0)
	_txt(ci, Vector2(0, 4), "TRI-COUNTY", 6, INK)

static func _duck(ci: CanvasItem, t: float) -> void:
	var b := sin(t * 2.0) * 1.5
	_el(ci, Vector2(-4, 10 + b), 30, 15, Color("#f6d23a"))
	_el(ci, Vector2(16, -12 + b), 14, 13, Color("#f6d23a"))
	_poly(ci, [Vector2(28, -12 + b), Vector2(40, -9 + b), Vector2(28, -5 + b)], Color("#f08a2a"))
	ci.draw_circle(Vector2(20, -16 + b), 2.4, INK); ci.draw_circle(Vector2(21, -17 + b), 0.8, Color.WHITE)
	_el(ci, Vector2(-10, 6 + b), 14, 6, Color("#f0c020"), false, -0.3)

static func _sneaker(ci: CanvasItem, _t: float) -> void:
	_poly(ci, [Vector2(-40, 10), Vector2(-38, -12), Vector2(-18, -16), Vector2(-4, -6), Vector2(30, 0), Vector2(40, 8), Vector2(38, 14), Vector2(-40, 14)], Color("#f4efe4"))
	_poly(ci, [Vector2(-40, 14), Vector2(38, 14), Vector2(36, 19), Vector2(-40, 19)], Color("#e2583e"))
	for i in 4: ci.draw_line(Vector2(-14 + i * 6, -10 + i * 1.5), Vector2(-8 + i * 6, -4 + i * 1.5), Color("#2b7ea6"), 1.6)
	ci.draw_polyline(PackedVector2Array([Vector2(-20, 4), Vector2(0, -2), Vector2(22, 6)]), Color("#2b7ea6"), 2.5)
	_weed(ci, Vector2(-34, -12), 12)

static func _toygator(ci: CanvasItem, _t: float) -> void:
	var g := Color("#5bb04a")
	_poly(ci, [Vector2(44, 2), Vector2(24, -6), Vector2(4, -10), Vector2(-20, -8), Vector2(-46, 0), Vector2(-20, 8), Vector2(4, 10), Vector2(24, 6)], g)
	for x in [-12, 14]: ci.draw_line(Vector2(x, 8), Vector2(x + 3, 16), Art.shade(g, -0.2), 4.0)
	for i in 6: ci.draw_circle(Vector2(-20 + i * 8, -9), 2.2, Art.shade(g, -0.2))
	ci.draw_circle(Vector2(22, -6), 3.5, Color.WHITE); ci.draw_circle(Vector2(23, -6), 1.8, INK)
	ci.draw_line(Vector2(26, 1), Vector2(44, 2), INK, 1.2)
	_rr(ci, Rect2(-6, -2, 14, 6), 2, Color("#f2b134"))   # a price sticker

static func _retainer(ci: CanvasItem, _t: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + i * PI / 16
		pts.append(Vector2(cos(a) * 30, sin(a) * 24 + 10))
	ci.draw_polyline(pts, Color("#f3a6a0"), 10.0)
	for i in 9:
		var a := PI + 0.25 + i * (PI - 0.5) / 8
		var p := Vector2(cos(a) * 30, sin(a) * 24 + 10)
		_rr(ci, Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), 2, Color("#f6f6f2"))
	ci.draw_polyline(pts, Color("#c8ccd0"), 1.2)

static func _keys(ci: CanvasItem, _t: float) -> void:
	ci.draw_arc(Vector2(-18, -8), 12, 0, TAU, 24, Color("#b8c1c6"), 3.0)
	_rr(ci, Rect2(-40, -2, 22, 26), 6, Color("#22313a"))
	ci.draw_circle(Vector2(-29, 8), 3, Color("#5a6a74"))
	for k in 2:
		var o := Vector2(k * 10, k * 4)
		_poly(ci, [Vector2(-8, -8) + o, Vector2(30, -8) + o, Vector2(34, -4) + o, Vector2(30, 0) + o, Vector2(-8, 0) + o], Color("#d8b860") if k == 0 else Color("#c8ccd0"))
		for i in 4: ci.draw_line(Vector2(6 + i * 6, 0) + o, Vector2(8 + i * 6, 3) + o, INK, 1.2)
	_txt(ci, Vector2(-29, 20), "KIA", 6, Color.WHITE)

static func _vhs(ci: CanvasItem, _t: float) -> void:
	_rr(ci, Rect2(-44, -26, 88, 52), 3, Color("#1e1e22"))
	_rr(ci, Rect2(-38, -22, 76, 22), 2, Color("#f2b134"))
	_txt(ci, Vector2(0, -14), "FLORIDA MAN'S", 9, INK)
	_txt(ci, Vector2(0, -4), "GREATEST HITS", 9, Color("#e2583e"))
	for x in [-18, 18]:
		ci.draw_circle(Vector2(x, 12), 8, Color("#3a3a40")); ci.draw_circle(Vector2(x, 12), 3, Color("#f4efe4"))
	ci.draw_rect(Rect2(-8, 8, 16, 8), Color("#2a2a30"))
	_weed(ci, Vector2(40, 24), 12)

static func _bottle(ci: CanvasItem, t: float) -> void:
	var bob := sin(t * 1.6) * 2.0
	var glass := Color(0.55, 0.78, 0.6, 0.65)
	_rot(ci, -0.25)
	_poly(ci, [Vector2(-34, -10 + bob), Vector2(16, -10 + bob), Vector2(26, -5 + bob), Vector2(36, -5 + bob), Vector2(36, 5 + bob), Vector2(26, 5 + bob), Vector2(16, 10 + bob), Vector2(-34, 10 + bob)], glass)
	_rr(ci, Rect2(36, -4 + bob, 7, 8), 2, Color("#b08a5a"))
	_rr(ci, Rect2(-26, -5 + bob, 36, 10), 4, Color("#f1e4c8"))
	ci.draw_line(Vector2(-6, -5 + bob), Vector2(-6, 5 + bob), Color("#c8322a"), 1.5)
	ci.draw_line(Vector2(-30, -7 + bob), Vector2(10, -7 + bob), Color(1, 1, 1, 0.5), 1.5)

static func _tooth(ci: CanvasItem, _t: float) -> void:
	_poly(ci, [Vector2(-18, -20), Vector2(18, -20), Vector2(22, -6), Vector2(14, 22), Vector2(6, 6), Vector2(-6, 6), Vector2(-14, 22), Vector2(-22, -6)], Color("#e9b23a"))
	ci.draw_line(Vector2(-12, -14), Vector2(-4, -16), Color(1, 1, 0.8, 0.8), 3.0)
	for p in [Vector2(26, -22), Vector2(-28, 2)]: _sparkle(ci, p, 6)

static func _ring(ci: CanvasItem, t: float) -> void:
	ci.draw_arc(Vector2(0, 6), 20, 0, TAU, 40, Color("#e9b23a"), 6.0)
	ci.draw_arc(Vector2(0, 6), 20, PI * 1.1, PI * 1.6, 12, Color(1, 1, 0.8, 0.8), 2.0)
	_poly(ci, [Vector2(-8, -16), Vector2(8, -16), Vector2(12, -22), Vector2(0, -32), Vector2(-12, -22)], Color("#cfeaf6"))
	ci.draw_line(Vector2(-12, -22), Vector2(12, -22), INK, 1.0)
	_sparkle(ci, Vector2(14, -30), 5 + sin(t * 4.0) * 1.5)

static func _paddle(ci: CanvasItem, _t: float) -> void:
	_rot(ci, -0.3)
	ci.draw_line(Vector2(-30, 0), Vector2(30, 0), Color("#3d4a52"), 4.0)
	for sd in [-1.0, 1.0]:
		var x: float = 30.0 * sd
		_poly(ci, [Vector2(x, -3), Vector2(x + 16 * sd, -9), Vector2(x + 22 * sd, -6), Vector2(x + 22 * sd, 6), Vector2(x + 16 * sd, 9), Vector2(x, 3)], Color("#f2b134"))
	ci.draw_rect(Rect2(-14, -2.5, 6, 5), Color("#22313a")); ci.draw_rect(Rect2(8, -2.5, 6, 5), Color("#22313a"))

static func _robofish(ci: CanvasItem, t: float) -> void:
	_poly(ci, [Vector2(-34, -16), Vector2(20, -18), Vector2(36, -4), Vector2(30, 12), Vector2(-34, 14)], Color("#c8964a"))
	_poly(ci, [Vector2(-34, -10), Vector2(-46, -18), Vector2(-46, 18), Vector2(-34, 10)], Color("#5a6a74"))
	for i in 4: ci.draw_circle(Vector2(-24 + i * 14, -12), 1.6, Color("#5a6a74"))
	# wires spilling out where it broke off
	for i in 3:
		var c: Color = [Color("#e2583e"), Color("#2b7ea6"), Color("#f2b134")][i]
		ci.draw_polyline(PackedVector2Array([Vector2(-34, -4 + i * 5), Vector2(-40, -2 + i * 6), Vector2(-44 + sin(t * 3.0 + i) * 2, 6 + i * 6)]), c, 1.6)
	ci.draw_circle(Vector2(22, -6), 5, Color.WHITE); ci.draw_circle(Vector2(23, -6), 2.5, Color("#e2583e") if fmod(t, 1.4) < 0.2 else INK)
	ci.draw_line(Vector2(28, 4), Vector2(34, 6), INK, 1.5)

static func _shades(ci: CanvasItem, _t: float) -> void:
	for sd in [-1.0, 1.0]:
		_rr(ci, Rect2(sd * 19 - 15, -10, 30, 20), 8, Color("#1e2a34"))
		ci.draw_line(Vector2(sd * 19 - 9, -5), Vector2(sd * 19 + 2, -7), Color(1, 1, 1, 0.4), 2.0)
	ci.draw_line(Vector2(-4, -4), Vector2(4, -4), INK, 3.0)
	ci.draw_line(Vector2(-34, -6), Vector2(-46, -14), INK, 2.5); ci.draw_line(Vector2(34, -6), Vector2(46, -14), INK, 2.5)
	ci.draw_polyline(PackedVector2Array([Vector2(8, -8), Vector2(14, 0), Vector2(10, 8)]), Color(1, 1, 1, 0.8), 1.0)   # a crack

static func _notice(ci: CanvasItem, _t: float) -> void:
	_rot(ci, 0.08)
	_poly(ci, [Vector2(-26, -30), Vector2(26, -30), Vector2(28, 30), Vector2(-24, 30)], Color("#f6f2e6"))
	_txt(ci, Vector2(1, -20), "HERON LAKES HOA", 4, INK)
	_txt(ci, Vector2(1, -10), "VIOLATION", 7, Color("#c8322a"))
	for i in 5: ci.draw_line(Vector2(-18, -2 + i * 5), Vector2(18 - (i % 2) * 8, -2 + i * 5), Color(0, 0, 0, 0.3), 1.2)
	ci.draw_arc(Vector2(14, 22), 6, 0, TAU, 16, Color("#c8322a"), 1.6)
	_el(ci, Vector2(-14, 16), 10, 6, Color(0.5, 0.6, 0.55, 0.25), false)   # a water stain

static func _tag(ci: CanvasItem, _t: float) -> void:
	ci.draw_polyline(PackedVector2Array([Vector2(-34, -2), Vector2(-42, -12), Vector2(-46, -22)]), Color("#2b2b2b"), 2.0)
	_poly(ci, [Vector2(-30, -16), Vector2(36, -16), Vector2(36, 16), Vector2(-30, 16), Vector2(-38, 0)], Color("#e2583e"))
	ci.draw_circle(Vector2(-30, 0), 3, Color("#f4efe4"))
	_rr(ci, Rect2(-20, -10, 50, 20), 2, Color("#f4efe4"))
	_txt(ci, Vector2(5, -2), "CLEVELAND", 7, INK)
	_txt(ci, Vector2(5, 7), "CLE", 7, Color("#5a6a74"))

static func _peanuts(ci: CanvasItem, _t: float) -> void:
	_poly(ci, [Vector2(-22, -26), Vector2(22, -26), Vector2(24, 26), Vector2(-24, 26)], Color("#2b7ea6"))
	for i in 6: ci.draw_line(Vector2(-22 + i * 9, -26), Vector2(-18 + i * 9, -30), INK, 1.0)
	_txt(ci, Vector2(0, -8), "HONEY", 8, Color("#f2b134"))
	_txt(ci, Vector2(0, 4), "ROASTED", 8, Color.WHITE)
	_el(ci, Vector2(0, 16), 9, 5, Color("#d8b070"))
	ci.draw_line(Vector2(0, 11), Vector2(0, 21), Color(0, 0, 0, 0.2), 1.0)

static func _valet(ci: CanvasItem, _t: float) -> void:
	_rot(ci, -0.1)
	_poly(ci, [Vector2(-16, -30), Vector2(16, -30), Vector2(16, 30), Vector2(-16, 30)], Color("#f6c86d"))
	ci.draw_circle(Vector2(0, -22), 3, Color("#fffaf0"))
	_txt(ci, Vector2(0, -8), "VALET", 9, INK)
	_txt(ci, Vector2(0, 8), "No 247", 8, Color("#c8322a"))
	for i in 8: ci.draw_line(Vector2(-16 + i * 4.5, 14), Vector2(-14 + i * 4.5, 16), INK, 1.0)

static func _scooter(ci: CanvasItem, _t: float) -> void:
	var c := Color("#5bb5a9")
	_poly(ci, [Vector2(-34, 4), Vector2(14, 4), Vector2(24, -6), Vector2(32, -6), Vector2(30, 10), Vector2(-36, 10)], c)
	_el(ci, Vector2(-20, -2), 14, 6, Color("#22313a"))
	ci.draw_line(Vector2(26, -6), Vector2(20, -30), Color("#5a6a74"), 3.0)
	ci.draw_line(Vector2(14, -30), Vector2(28, -30), INK, 3.0)
	ci.draw_circle(Vector2(24, -24), 3, Color("#f6e8a0"))
	for x in [-26, 26]:
		ci.draw_circle(Vector2(x, 14), 7, Color("#22313a")); ci.draw_circle(Vector2(x, 14), 2.5, Color("#9aa6ad"))
	_weed(ci, Vector2(-4, 4), 14); _weed(ci, Vector2(8, 4), 10)
	for p in [Vector2(-40, -10), Vector2(36, 18)]: ci.draw_arc(p, 2.5, 0, TAU, 10, Color(0.45, 0.7, 0.85, 0.7), 1.0)

static func _selfie(ci: CanvasItem, _t: float) -> void:
	_rot(ci, -0.45)
	ci.draw_line(Vector2(-44, 0), Vector2(24, 0), Color("#b8c1c6"), 4.0)
	for i in 3: ci.draw_line(Vector2(-30 + i * 16, -3), Vector2(-30 + i * 16, 3), INK, 1.5)
	_rr(ci, Rect2(-48, -4, 12, 8), 3, Color("#22313a"))
	_rr(ci, Rect2(24, -10, 10, 20), 2, Color("#22313a"))
	_rr(ci, Rect2(34, -14, 6, 28), 2, Color("#f3a6a0"))   # a pink phone, still in the clamp

static func _chair(ci: CanvasItem, _t: float) -> void:
	var w := Color("#f4efe4")
	for i in 5:
		ci.draw_line(Vector2(-34 + i * 2, -20 + i * 7), Vector2(14 + i * 6, -20 + i * 7), Color("#2b7ea6") if i % 2 else w, 5.0)
	ci.draw_line(Vector2(14, 10), Vector2(42, 10), w, 5.0); ci.draw_line(Vector2(14, 16), Vector2(42, 16), Color("#2b7ea6"), 5.0)
	ci.draw_polyline(PackedVector2Array([Vector2(-36, -24), Vector2(-26, 24)]), Color("#c8ccd0"), 3.0)
	ci.draw_polyline(PackedVector2Array([Vector2(14, -24), Vector2(22, 24)]), Color("#c8ccd0"), 3.0)
	ci.draw_line(Vector2(42, 6), Vector2(44, 24), Color("#c8ccd0"), 3.0)
	_txt(ci, Vector2(-8, 30), "SS SUNSHINE", 7, Color("#2b7ea6"))

static func _doubloon(ci: CanvasItem, t: float) -> void:
	_el(ci, Vector2.ZERO, 26, 24, Color("#e9b23a"))
	ci.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color("#b8861a"), 1.5)
	ci.draw_line(Vector2(0, -14), Vector2(0, 14), Color("#b8861a"), 3.0); ci.draw_line(Vector2(-14, 0), Vector2(14, 0), Color("#b8861a"), 3.0)
	for p in [Vector2(-7, -7), Vector2(7, -7), Vector2(-7, 7), Vector2(7, 7)]: ci.draw_circle(p, 2.5, Color("#b8861a"))
	_sparkle(ci, Vector2(22, -22), 5 + sin(t * 4.0) * 1.5)

static func _balloon(ci: CanvasItem, t: float) -> void:
	var b := sin(t * 1.2) * 2.0
	_el(ci, Vector2(0, -6 + b), 26, 22, Color("#f6f6f2"))
	_el(ci, Vector2(-8, -14 + b), 8, 5, Color(1, 1, 1, 0.9), false)
	ci.draw_polyline(PackedVector2Array([Vector2(0, 16 + b), Vector2(-4, 22), Vector2(4, 26), Vector2(0, 30)]), INK, 1.2)
	_rr(ci, Rect2(-6, 22, 12, 9), 2, Color("#f2b134"))
	_txt(ci, Vector2(0, 0 + b), "NWS", 9, Color("#2b7ea6"))

static func _penny(ci: CanvasItem, t: float) -> void:
	_el(ci, Vector2.ZERO, 22, 22, Color("#c8743e"))
	ci.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color("#9a5428"), 1.4)
	_el(ci, Vector2(2, -2), 8, 10, Color("#a8602e"), false)
	_txt(ci, Vector2(0, 14), "1 CENT", 6, Color("#7a4020"))
	_sparkle(ci, Vector2(18, -18), 4 + sin(t * 4.0))

static func _rolex(ci: CanvasItem, t: float) -> void:
	for sd in [-1.0, 1.0]:
		_poly(ci, [Vector2(-10, sd * 14), Vector2(10, sd * 14), Vector2(9, sd * 30), Vector2(-9, sd * 30)], Color("#d8c070"))
		for i in 3: ci.draw_line(Vector2(-9, sd * (18 + i * 4)), Vector2(9, sd * (18 + i * 4)), Color("#b8861a"), 1.0)
	_el(ci, Vector2.ZERO, 18, 18, Color("#e9c860"))
	_el(ci, Vector2.ZERO, 14, 14, Color("#1f3a5a"))
	for i in 12: ci.draw_line(Vector2.from_angle(i * TAU / 12) * 11, Vector2.from_angle(i * TAU / 12) * 13, Color.WHITE, 1.2)
	ci.draw_line(Vector2.ZERO, Vector2.from_angle(t * 0.5) * 10, Color.WHITE, 1.4)
	ci.draw_line(Vector2.ZERO, Vector2.from_angle(-1.0) * 7, Color.WHITE, 2.0)
	_poly(ci, [Vector2(-3, -9), Vector2(0, -6), Vector2(3, -9), Vector2(0, -11)], Color("#e9c860"), 0.6)

static func _certificate(ci: CanvasItem, _t: float) -> void:
	_poly(ci, [Vector2(-44, -28), Vector2(44, -28), Vector2(44, 28), Vector2(-44, 28)], Color("#eef4e6"))
	ci.draw_rect(Rect2(-40, -24, 80, 48), Color("#4f8a5a"), false, 1.5)
	_txt(ci, Vector2(0, -12), "FINTASTIC! OUTDOORS", 6, Color("#2f6a3a"))
	_txt(ci, Vector2(0, -2), "100 SHARES", 9, INK)
	for i in 2: ci.draw_line(Vector2(-28, 6 + i * 5), Vector2(28, 6 + i * 5), Color(0, 0, 0, 0.25), 1.0)
	ci.draw_circle(Vector2(28, 18), 6, Color("#c8322a"))
	ci.draw_line(Vector2(-30, 20), Vector2(-6, 18), Color(0.1, 0.2, 0.5, 0.7), 1.2)   # a signature

static func _coins(ci: CanvasItem, t: float) -> void:
	var cs := [[Vector2(-18, 6), Color("#c8ccd0"), 12.0], [Vector2(6, 10), Color("#c8743e"), 10.0], [Vector2(20, -4), Color("#c8ccd0"), 13.0], [Vector2(-4, -10), Color("#c8ccd0"), 9.0], [Vector2(-28, -12), Color("#c8743e"), 9.0]]
	for c in cs:
		_el(ci, c[0], c[2], c[2] * 0.8, c[1])
		ci.draw_arc(c[0], c[2] * 0.7, 0, TAU, 20, Art.shade(c[1], -0.2), 1.0)
	_sparkle(ci, Vector2(26, -18), 4 + sin(t * 4.0))

static func _sparkle(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0), p + Vector2(s * 0.25, s * 0.25), p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0), p + Vector2(-s * 0.25, -s * 0.25)]), Color("#fff4c0"))

# ---------- Ironwater ----------

static func _cone(ci: CanvasItem, _t: float) -> void:
	_rot(ci, 0.25)
	_poly(ci, [Vector2(-26, 24), Vector2(26, 24), Vector2(22, 18), Vector2(-22, 18)], Color("#3a3a3a"))
	_poly(ci, [Vector2(-18, 18), Vector2(18, 18), Vector2(4, -28), Vector2(-4, -28)], Color("#f2742a"))
	_poly(ci, [Vector2(-12.5, 0), Vector2(12.5, 0), Vector2(9.5, -10), Vector2(-9.5, -10)], Color("#f4f6f4"), 0.8)
	ci.draw_line(Vector2(-6, 12), Vector2(-2, -22), Color(1, 1, 1, 0.3), 2.0)
	_el(ci, Vector2(10, 21), 5, 2, Color("#6b7a3a", 0.8), false)   # river weed

static func _bobbin(ci: CanvasItem, _t: float) -> void:
	_rot(ci, -0.2)
	_poly(ci, [Vector2(-34, -10), Vector2(34, -10), Vector2(34, 10), Vector2(-34, 10)], Color("#c8a46a"))
	for x in [-34.0, 26.0]: _poly(ci, [Vector2(x, -16), Vector2(x + 8, -16), Vector2(x + 8, 16), Vector2(x, 16)], Color("#8a5a35"))
	for i in 9: ci.draw_line(Vector2(-24 + i * 6, -9), Vector2(-20 + i * 6, 9), Color("#7a2a2a", 0.6), 3.0)
	ci.draw_line(Vector2(-26, -2), Vector2(24, -2), Color(1, 1, 1, 0.2), 2.0)

static func _keg(ci: CanvasItem, _t: float) -> void:
	_poly(ci, [Vector2(-22, -28), Vector2(22, -28), Vector2(26, 0), Vector2(22, 28), Vector2(-22, 28), Vector2(-26, 0)], Color("#b8bec4"))
	for y in [-20.0, 0.0, 20.0]: ci.draw_line(Vector2(-25, y), Vector2(25, y), Color("#7a8288"), 3.0)
	_el(ci, Vector2(0, -28), 22, 4, Color("#d8dde0"))
	_el(ci, Vector2(0, -28), 5, 2, Color("#3a3a3a"))
	ci.draw_line(Vector2(-12, -14), Vector2(-10, 18), Color(1, 1, 1, 0.35), 3.0)
	_txt(ci, Vector2(0, 9), "CALDER", 7, Color("#5a3a2a"))

static func _baseball(ci: CanvasItem, t: float) -> void:
	_el(ci, Vector2.ZERO, 24, 24, Color("#f4f0e4"))
	for sd in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 13:
			var a := -1.0 + i / 12.0 * 2.0
			pts.append(Vector2(sd * (12 - a * a * 6), a * 20))
		ci.draw_polyline(pts, Color("#c8402a"), 1.6)
		for i in 6:
			var a := -0.8 + i * 0.32
			var p := Vector2(sd * (12 - a * a * 6), a * 20)
			ci.draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color("#c8402a"), 1.2)
	ci.draw_line(Vector2(-8, 4), Vector2(6, -2), Color("#2a4a8a", 0.8), 1.4)   # somebody's autograph
	ci.draw_line(Vector2(6, -2), Vector2(10, 3), Color("#2a4a8a", 0.8), 1.4)
	_sparkle(ci, Vector2(18, -18), 3 + sin(t * 4.0))

static func _finger(ci: CanvasItem, _t: float) -> void:
	_rot(ci, 0.15)
	_poly(ci, [Vector2(-20, 28), Vector2(20, 28), Vector2(22, -4), Vector2(8, -6), Vector2(8, -30), Vector2(-4, -30), Vector2(-6, -6), Vector2(-22, -2)], Color("#2b7ea6"))
	_txt(ci, Vector2(0, 14), "#1", 14, Color("#f2c040"))
	_txt(ci, Vector2(0, 24), "HAWKS", 6, Color.WHITE)
