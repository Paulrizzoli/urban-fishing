class_name FintasticArt
extends RefCounted
## The inside of FINTASTIC! Outdoor Megastore, drawn at the top of its card: a big-box store with
## a steel-truss ceiling and buzzing light strips, aisle end caps going back forever, a wall of
## rods with Trent's face on them, REEL DEAL on the TV, a cardboard Trent giving a thumbs up,
## an energy drink fridge, a robot fish that sings, and Brayden behind the register.
## After Act II it's the same store, dark and shut, with the cardboard Trent face down.
## Drawn on a 640 x 320 design and scaled to fit, like HomeArt.

const W := 640.0
const H := 320.0
const INK := Color("#22313a")
const PAPER := Color("#fbf3e2")
const SUN := Color("#f2b134")
const CORAL := Color("#e2583e")
const TEAL := Color("#13807b")
const SEA := Color("#2b7ea6")
const STEEL := Color("#5d6b74")
const SKIN := Color("#e9c29a")
const BLOND := Color("#f2d16b")
const CEIL := 44.0
const FLOOR_Y := 206.0
## The aisle end caps across the back: [x, aisle number, sign]
const AISLES := [[168.0, "7", "RODS & REELS"], [252.0, "12", "CAMO"], [336.0, "23", "MORE CAMO"], [420.0, "40", "???"]]

static var _o := Vector2.ZERO
static var _s := 1.0

static func _fit(ci: Control) -> void:
	_s = minf(ci.size.x / W, ci.size.y / H)
	_o = Vector2((ci.size.x - W * _s) / 2.0, (ci.size.y - H * _s) / 2.0)
	ci.draw_set_transform(_o, 0, Vector2(_s, _s))

static func _txt(ci: Control, p: Vector2, s: String, size: int, col: Color, font: Font = null) -> void:
	var f: Font = font if font else Game.font_bold
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, p - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func _box(ci: Control, r: Rect2, fill: Color, lw := 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, INK, false, lw)

static func _shape(ci: Control, pts: PackedVector2Array, fill: Color, lw := 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, lw, true)

static func store(ci: Control) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var shut := Fintastic.closed()
	_fit(ci)
	_ceiling(ci, t, shut)
	_back_wall(ci)
	_floor(ci, shut)
	for i in AISLES.size(): _end_cap(ci, AISLES[i], i, t)
	_rod_wall(ci)
	_tv(ci, t, shut)
	_fridge(ci, t, shut)
	_counter(ci, t, shut)
	_cart(ci)
	_cutout(ci, t, shut)
	if shut:
		# lights off: only daylight through the papered glass and the fridge hum
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.06, 0.12, 0.62))
		for i in 5: ci.draw_circle(Vector2(300, 250), 40.0 + i * 30, Color(1, 0.95, 0.8, 0.025))
		var b := PackedVector2Array([Vector2(150, 118), Vector2(490, 96), Vector2(494, 134), Vector2(154, 156)])
		_shape(ci, b, Color("#fbf3e2"), 2.4)
		var tr := Transform2D(-0.064, Vector2(322, 128))
		ci.draw_set_transform(_o + tr.origin * _s, tr.get_rotation(), Vector2(_s, _s))
		_txt(ci, Vector2(0, 2), "CLOSED FOR REBRANDING", 26, CORAL, Game.font_display)
		_txt(ci, Vector2(0, 18), "THANK YOU FOR SHOPPING FINTASTIC!", 10, INK)
		ci.draw_set_transform(_o, 0, Vector2(_s, _s))
	_robot_fish(ci, t)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_rect(Rect2(_o, Vector2(W, H) * _s), INK, false, 2)

## Bare steel trusses, ducts and long light strips; one of them flickers.
static func _ceiling(ci: Control, t: float, shut: bool) -> void:
	ci.draw_rect(Rect2(0, 0, W, CEIL), Color("#3c4a54"))
	ci.draw_rect(Rect2(0, 10, W, 12), Color("#8f9ca3"))                # the duct
	for i in 17: ci.draw_line(Vector2(i * 40, 10), Vector2(i * 40, 22), Color("#7a878e"), 1.5)
	ci.draw_line(Vector2(0, 32), Vector2(W, 32), STEEL, 3)
	for i in 32:
		var x := i * 20.0
		ci.draw_line(Vector2(x, 32), Vector2(x + 10, CEIL - 2), STEEL, 1.5)
		ci.draw_line(Vector2(x + 10, CEIL - 2), Vector2(x + 20, 32), STEEL, 1.5)
	ci.draw_line(Vector2(0, CEIL - 2), Vector2(W, CEIL - 2), STEEL, 3)
	for i in 5:
		var x := 22.0 + i * 128.0
		var on := 1.0
		if i == 3: on = 0.35 if fmod(t * 7.0, 5.3) < 0.4 or fmod(t * 3.1, 7.0) < 0.15 else 1.0
		if shut: on = 0.0
		ci.draw_rect(Rect2(x, 24, 96, 6), Color("#dfe7ea").lerp(Color("#fffbe8"), on))
		ci.draw_rect(Rect2(x, 24, 96, 6), INK, false, 1.2)
		if on > 0.5: ci.draw_rect(Rect2(x - 10, 30, 116, 10), Color(1, 1, 0.9, 0.12 * on))

## The back wall: FINTASTIC! in giant letters, a MEGA SALE banner and the hanging aisle signs.
static func _back_wall(ci: Control) -> void:
	ci.draw_rect(Rect2(0, CEIL, W, FLOOR_Y - CEIL), Color("#2b7ea6"))
	ci.draw_rect(Rect2(0, CEIL, W, 6), Color("#1f6488"))
	_txt(ci, Vector2(296, 76), "FINTASTIC!", 30, SUN, Game.font_display)
	_txt(ci, Vector2(296, 88), "OUTDOOR MEGASTORE · AS SEEN ON TV", 9, PAPER)
	# the aisle signs on chains, above each end cap
	for a in AISLES:
		var x: float = a[0]
		for sx in [-16, 16]: ci.draw_line(Vector2(x + sx, CEIL), Vector2(x + sx, 96), Color("#9aa6ad"), 1)
		_box(ci, Rect2(x - 38, 96, 76, 22), PAPER, 1.6)
		ci.draw_rect(Rect2(x - 38, 96, 18, 22), CORAL); ci.draw_rect(Rect2(x - 38, 96, 18, 22), INK, false, 1.6)
		_txt(ci, Vector2(x - 29, 112), a[1], 12, Color.WHITE, Game.font_display)
		_txt(ci, Vector2(x + 9, 110), a[2], 7 if a[2].length() > 6 else 9, INK)

## Polished concrete that reflects the light strips, with a faded painted walkway.
static func _floor(ci: Control, shut: bool) -> void:
	ci.draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color("#b9c2c7"))
	var y := FLOOR_Y
	var gap := 6.0
	while y < H:
		ci.draw_line(Vector2(0, y), Vector2(W, y), Color("#a8b2b8"), 1)
		y += gap; gap *= 1.35
	for i in 13:
		var x0 := -160.0 + i * 80.0
		var a := Vector2(W / 2 + (x0 - W / 2) * 0.35, FLOOR_Y)
		var b := Vector2(x0, H)
		if b.x < 0: b = a.lerp(b, (0.0 - a.x) / (b.x - a.x))
		elif b.x > W: b = a.lerp(b, (W - a.x) / (b.x - a.x))
		ci.draw_line(a, b, Color("#a8b2b8"), 1)
	if not shut:
		for i in 5: ci.draw_rect(Rect2(22.0 + i * 128.0 + 10, FLOOR_Y + 30, 76, 4), Color(1, 1, 1, 0.35))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(272, FLOOR_Y), Vector2(320, FLOOR_Y), Vector2(380, H), Vector2(210, H)]), Color(SUN, 0.22))
	ci.draw_rect(Rect2(0, FLOOR_Y - 3, W, 4), Color("#3d4a52"))

## One aisle end cap: a tall shelf unit of boxes, the dark aisle going back beside it, a sale burst.
static func _end_cap(ci: Control, a: Array, i: int, t: float) -> void:
	var x: float = a[0]
	# the aisle behind, going on forever
	ci.draw_rect(Rect2(x + 34, 122, 16, FLOOR_Y - 122), Color("#1b4a63"))
	for k in 4: ci.draw_rect(Rect2(x + 37 + k * 2.5, 128 + k * 6, 10 - k * 5, FLOOR_Y - 128 - k * 6), Color("#163e54"))
	_box(ci, Rect2(x - 34, 122, 68, FLOOR_Y - 122), Color("#d7dde0"))
	var cols: Array = [[CORAL, SUN, TEAL], [Color("#5a6b3a"), Color("#7a6a4a"), Color("#3f5a32")], [Color("#4f5f36"), Color("#6e7a4a"), Color("#8a7b52")], [Color("#c9b6e4"), CORAL, SEA]][i]
	for row in 4:
		var yy := 128.0 + row * 20
		ci.draw_rect(Rect2(x - 32, yy + 16, 64, 3), STEEL)
		for k in 4:
			var bw := 13.0
			var c: Color = cols[(row + k) % 3]
			_box(ci, Rect2(x - 30 + k * 15.5, yy + 2 + (k % 2) * 2, bw, 14 - (k % 2) * 2), c, 1)
			if i == 1 or i == 2:
				for d in 3: ci.draw_circle(Vector2(x - 26 + k * 15.5 + d * 4, yy + 8 + (d % 2) * 3), 1.6, c.darkened(0.3))   # camo blotches
	if i == 0 or i == 3:
		var c := Vector2(x + 26, 130)
		var pts := PackedVector2Array()
		for k in 16: pts.append(c + Vector2.from_angle(k * TAU / 16 + t * 0.3) * (13.0 if k % 2 == 0 else 9.0))
		_shape(ci, pts, SUN, 1.4)
		_txt(ci, c + Vector2(0, -1), "MEGA", 6, CORAL)
		_txt(ci, c + Vector2(0, 6), "SALE", 6, CORAL)

## The rod wall on the left, every rod with a Trent sticker, and the Signature Rod in a case.
static func _rod_wall(ci: Control) -> void:
	_box(ci, Rect2(0, 96, 128, FLOOR_Y - 96), Color("#c9a574"))
	for k in 12:
		for j in 7: ci.draw_circle(Vector2(8 + k * 10, 104 + j * 14), 1.1, Color("#a8875a"))
	_box(ci, Rect2(4, 98, 120, 16), INK, 1)
	_txt(ci, Vector2(64, 110), "AS SEEN ON TV!", 11, SUN)
	for k in 8:
		var x := 12.0 + k * 13.5
		if k == 4: continue
		ci.draw_line(Vector2(x, 120), Vector2(x + 2, 200), Color(["#3f7d4e", "#2b2f36", "#2a3e5c", "#c94a33"][k % 4]), 2.4)
		ci.draw_rect(Rect2(x - 1.5, 182, 5, 14), Color("#3a3a3a"))
		_face(ci, Vector2(x + 1, 150), 4.5)
	# the glass case with the Signature Rod
	_box(ci, Rect2(60, 118, 16, 84), Color("#bfe3ea", 0.5), 1.4)
	ci.draw_line(Vector2(66, 122), Vector2(70, 198), Color("#3f7d4e"), 3)
	_face(ci, Vector2(68, 140), 5.5)
	_box(ci, Rect2(54, 196, 28, 9), CORAL, 1)
	_txt(ci, Vector2(68, 203.5), "$999", 7, Color.WHITE)

## A tiny Trent: the swoop of blond hair and all the teeth.
static func _face(ci: Control, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r + 1.2, PAPER)
	ci.draw_circle(c, r, SKIN)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.6, -r * 1.1), c + Vector2(r * 0.4, -r * 1.25), c + Vector2(r * 1.05, -r * 0.5), c + Vector2(r, 0)]), BLOND)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.3), Vector2(r, r * 0.32)), Color.WHITE)

## REEL DEAL on a big TV hanging from the ceiling, looping Trent holding up a bass.
static func _tv(ci: Control, t: float, shut: bool) -> void:
	var r := Rect2(470, 50, 104, 64)
	for sx in [20, 84]: ci.draw_line(Vector2(r.position.x + sx, CEIL), Vector2(r.position.x + sx, r.position.y), STEEL, 2)
	_box(ci, r, INK, 2)
	var sc := r.grow(-5)
	if shut:
		ci.draw_rect(sc, Color("#111a20")); ci.draw_line(sc.position + Vector2(8, 6), sc.position + Vector2(30, 6), Color(1, 1, 1, 0.08), 3); return
	ci.draw_rect(sc, Color("#9fd3ea"))
	ci.draw_rect(Rect2(sc.position.x, sc.end.y - 18, sc.size.x, 18), TEAL)
	var c := sc.position + Vector2(36, 30 + sin(t * 2.4) * 1.2)
	ci.draw_rect(Rect2(c + Vector2(-12, 10), Vector2(24, 14)), CORAL)
	_face(ci, c, 10)
	# the bass, held up and waggled
	var f := c + Vector2(30, 2)
	var pts := PackedVector2Array()
	for k in 9: pts.append(Vector2(-14 + k * 3.2, -sin(k / 8.0 * PI) * 6))
	pts.append(Vector2(16, -6)); pts.append(Vector2(14, 0)); pts.append(Vector2(16, 6))
	for k in 9: pts.append(Vector2(-14 + (8 - k) * 3.2, sin((8 - k) / 8.0 * PI) * 6))
	pts = Transform2D(-0.4 + sin(t * 3.0) * 0.12, f) * pts
	_shape(ci, pts, Color("#6f9a4a"), 1.2)
	ci.draw_rect(Rect2(sc.position.x + 2, sc.end.y - 12, 44, 10), CORAL)
	_txt(ci, Vector2(sc.position.x + 24, sc.end.y - 4), "REEL DEAL", 7, Color.WHITE)
	if fmod(t, 1.2) < 0.7: ci.draw_circle(Vector2(sc.end.x - 8, sc.position.y + 6), 2.5, CORAL)
	for k in 6: ci.draw_line(Vector2(sc.position.x, sc.position.y + fmod(t * 20.0 + k * 9.0, sc.size.y)), Vector2(sc.end.x, sc.position.y + fmod(t * 20.0 + k * 9.0, sc.size.y)), Color(1, 1, 1, 0.07), 1)

## The REEL DEAL fridge by the register, cans glowing green.
static func _fridge(ci: Control, t: float, shut: bool) -> void:
	var r := Rect2(588, 82, 46, 124)
	_box(ci, r, Color("#1d2b45"))
	_box(ci, Rect2(r.position + Vector2(4, 16), Vector2(38, 104)), Color("#0f1a2c"), 1.4)
	_txt(ci, Vector2(611, 96), "REEL DEAL", 7, Color("#c6ff3a"))
	var glow := 0.25 if shut else 0.75 + 0.1 * sin(t * 3)
	for row in 4:
		for k in 3:
			var cp := Vector2(596 + k * 11, 104 + row * 26)
			ci.draw_rect(Rect2(cp, Vector2(8, 18)), Color("#c6ff3a").darkened(1.0 - glow))
			ci.draw_rect(Rect2(cp + Vector2(0, 6), Vector2(8, 4)), CORAL.darkened(1.0 - glow))
		ci.draw_rect(Rect2(592, 122 + row * 26, 38, 2), STEEL)
	ci.draw_rect(Rect2(r.position + Vector2(4, 16), Vector2(38, 104)), Color(0.78, 1, 0.3, 0.08 * glow))
	ci.draw_line(Vector2(592, 102), Vector2(600, 194), Color(1, 1, 1, 0.12), 3)

## The checkout counter, the register, and Brayden behind it.
static func _counter(ci: Control, t: float, shut: bool) -> void:
	if not shut:
		ci.draw_set_transform(_o + Vector2(540, 146) * _s, 0, Vector2(_s, _s) * 1.35)
		_brayden(ci, Vector2.ZERO, t)
		ci.draw_set_transform(_o, 0, Vector2(_s, _s))
	var top := 186.0
	_box(ci, Rect2(458, top, 128, 54), Color("#d7dde0"))
	ci.draw_rect(Rect2(458, top, 128, 8), Color("#f4f7f8")); ci.draw_rect(Rect2(458, top, 128, 8), INK, false, 2)
	_box(ci, Rect2(466, top + 16, 112, 18), CORAL, 1.4)
	_txt(ci, Vector2(522, top + 29), "ASK ME ABOUT FIN CLUB!", 9, Color.WHITE)
	# the register
	_box(ci, Rect2(562, top - 22, 20, 22), Color("#3d4a52"), 1.4)
	_box(ci, Rect2(560, top - 34, 24, 12), Color("#9fc4d6") if not shut else Color("#3d4a52"), 1.4)
	if not shut: _txt(ci, Vector2(572, top - 25), "$$$", 7, INK)

## Brayden, 17: FINTASTIC! visor, teal polo, name tag, and the face of someone eleven months in.
## He blinks, sways a little, and shuts his eyes when the robot fish sings.
static func _brayden(ci: Control, c: Vector2, t: float) -> void:
	var sway := sin(t * 0.9) * 1.2
	c += Vector2(sway, 0)
	# polo and arms
	var body := PackedVector2Array([c + Vector2(-26, 20), c + Vector2(-16, 12), c + Vector2(16, 12), c + Vector2(26, 20), c + Vector2(30, 40), c + Vector2(-30, 40)])
	_shape(ci, body, TEAL)
	_shape(ci, PackedVector2Array([c + Vector2(-8, 12), c + Vector2(0, 20), c + Vector2(8, 12)]), PAPER, 1.4)
	_box(ci, Rect2(c + Vector2(8, 22), Vector2(15, 7)), PAPER, 1)
	_txt(ci, c + Vector2(15.5, 28), "BRAYDEN", 4, INK)
	ci.draw_circle(c + Vector2(-14, 26), 3.2, SUN)
	# neck, head and ears
	ci.draw_rect(Rect2(c + Vector2(-4, 4), Vector2(8, 9)), Color("#d9a77c"))
	ci.draw_circle(c + Vector2(-13, -6), 3.4, Color("#d9a77c"))
	ci.draw_circle(c + Vector2(13, -6), 3.4, Color("#d9a77c"))
	ci.draw_circle(c + Vector2(0, -6), 13, Color("#e2b48a"))
	ci.draw_arc(c + Vector2(0, -6), 13, 0, TAU, 24, INK, 1.4)
	# shaggy hair under the visor
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -10), c + Vector2(-10, -17), c + Vector2(10, -17), c + Vector2(13, -10), c + Vector2(8, -12), c + Vector2(4, -9), c + Vector2(-1, -12), c + Vector2(-6, -9)]), Color("#6b4a2e"))
	# the visor: band and brim
	ci.draw_rect(Rect2(c + Vector2(-13, -20), Vector2(26, 5)), SUN)
	ci.draw_rect(Rect2(c + Vector2(-13, -20), Vector2(26, 5)), INK, false, 1.2)
	_shape(ci, PackedVector2Array([c + Vector2(-14, -15), c + Vector2(14, -15), c + Vector2(20, -11), c + Vector2(-8, -12)]), SUN, 1.2)
	_txt(ci, c + Vector2(0, -16), "F!", 5, CORAL)
	# eyes: half-lidded, glancing your way now and then, shut tight while the fish sings
	var pained := Fintastic.singing()
	var blink := fmod(t, 4.3) < 0.14
	var look := 1.6 if fmod(t, 9.0) > 6.0 else 0.0
	for sx in [-5, 5]:
		var e := c + Vector2(sx, -5)
		if pained:
			ci.draw_polyline(PackedVector2Array([e + Vector2(-3, -1.5), e + Vector2(0, 0.5), e + Vector2(3, -1.5)]), INK, 1.4, true)
		elif blink: ci.draw_line(e + Vector2(-2.5, 0), e + Vector2(2.5, 0), INK, 1.4)
		else:
			ci.draw_circle(e + Vector2(look, 0.6), 1.6, INK)
			ci.draw_line(e + Vector2(-3, -1), e + Vector2(3, -1), Color("#c9946a"), 2.2)   # heavy lids
	# a flat little mouth, a pimple and a sigh of a smirk
	ci.draw_line(c + Vector2(-3, 2), c + Vector2(4, 1.4), INK, 1.4)
	ci.draw_circle(c + Vector2(7, -1), 0.9, Color("#e07a6a"))

## A shopping cart left in the walkway.
static func _cart(ci: Control) -> void:
	var o := Vector2(268, 246)
	var basket := PackedVector2Array([o, o + Vector2(70, 0), o + Vector2(62, 30), o + Vector2(8, 30)])
	ci.draw_colored_polygon(basket, Color(0.6, 0.66, 0.7, 0.35))
	for k in 8: ci.draw_line(o + Vector2(k * 10, 0), o + Vector2(8 + k * 7.7, 30), Color("#8a959b"), 1.2)
	for k in 3: ci.draw_line(o + Vector2(k * 2.7, k * 10), o + Vector2(70 - k * 2.7, k * 10), Color("#8a959b"), 1.2)
	ci.draw_polyline(basket + PackedVector2Array([basket[0]]), INK, 2, true)
	ci.draw_line(o + Vector2(70, 0), o + Vector2(84, -10), INK, 2.4)
	ci.draw_line(o + Vector2(80, -12), o + Vector2(88, -8), CORAL, 4)
	ci.draw_line(o + Vector2(8, 30), o + Vector2(10, 44), INK, 2); ci.draw_line(o + Vector2(62, 30), o + Vector2(60, 44), INK, 2)
	ci.draw_line(o + Vector2(10, 44), o + Vector2(60, 44), INK, 2)
	for x in [12.0, 58.0]: ci.draw_circle(o + Vector2(x, 47), 3.4, INK)
	# a camo hat and a box in the cart
	_box(ci, Rect2(o + Vector2(14, -8), Vector2(22, 14)), SUN, 1.4)
	ci.draw_circle(o + Vector2(48, -2), 9, Color("#5a6b3a")); ci.draw_circle(o + Vector2(45, -4), 2, Color("#3f5a32"))

## Life-size cardboard Trent by the door, thumbs up. Face down on the floor once the store closes.
static func _cutout(ci: Control, t: float, shut: bool) -> void:
	var base := Vector2(170, 300)
	if shut:
		var lying := PackedVector2Array([base + Vector2(-70, -8), base + Vector2(40, -14), base + Vector2(44, 0), base + Vector2(-66, 4)])
		_shape(ci, lying, Color("#c9a574"), 1.6)
		ci.draw_line(base + Vector2(-60, -2), base + Vector2(30, -8), Color("#a8875a"), 1.4)
		return
	var c := base + Vector2(0, -100)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-26, 0), base + Vector2(26, 0), base + Vector2(20, 6), base + Vector2(-20, 6)]), Color(0, 0, 0, 0.18))
	# legs, shirt, the arm up with a thumb
	ci.draw_rect(Rect2(base + Vector2(-14, -48), Vector2(11, 48)), Color("#2a3e5c")); ci.draw_rect(Rect2(base + Vector2(3, -48), Vector2(11, 48)), Color("#2a3e5c"))
	_shape(ci, PackedVector2Array([c + Vector2(-22, 18), c + Vector2(22, 18), c + Vector2(20, 54), c + Vector2(-20, 54)]), CORAL, 1.6)
	_txt(ci, c + Vector2(0, 40), "REEL", 8, Color.WHITE)
	var arm := c + Vector2(22, 22)
	ci.draw_line(arm, arm + Vector2(14, -18), CORAL, 7)
	ci.draw_circle(arm + Vector2(15, -20), 5, SKIN)
	ci.draw_line(arm + Vector2(15, -23), arm + Vector2(15, -31), SKIN, 3.4)
	ci.draw_line(c + Vector2(-22, 22), c + Vector2(-28, 48), CORAL, 7)
	_face(ci, c + Vector2(0, 2), 14)
	ci.draw_circle(c + Vector2(-5, 0), 1.6, INK); ci.draw_circle(c + Vector2(5, 0), 1.6, INK)
	# speech bubble
	var b := Rect2(c + Vector2(24, -42), Vector2(70, 22))
	_box(ci, b, Color.WHITE, 1.4)
	ci.draw_colored_polygon(PackedVector2Array([b.position + Vector2(8, 22), b.position + Vector2(18, 22), b.position + Vector2(4, 30)]), Color.WHITE)
	_txt(ci, b.position + Vector2(35, 15), "IT'S FINTASTIC!", 8, CORAL)
	# the cardboard edge
	ci.draw_rect(Rect2(base + Vector2(-30, -2), Vector2(60, 4)), Color("#a8875a"))

## The robot fish on the counter: it flaps its tail and mouth and sings when you press its button.
static func _robot_fish(ci: Control, t: float) -> void:
	var c := Vector2(488, 172)
	_box(ci, Rect2(c + Vector2(-26, -12), Vector2(52, 26)), Color("#8a5a35"), 1.6)
	ci.draw_circle(c + Vector2(20, 9), 2.4, CORAL)
	var sing := Fintastic.singing()
	var flap := (sin(t * 16.0) * 0.5 + 0.5) if sing else (0.15 if fmod(t, 11.0) < 1.5 else 0.0) * (sin(t * 14.0) * 0.5 + 0.5)
	var tail := sin(t * 10.0) * 4.0 if sing else 0.0
	var pts := PackedVector2Array()
	for k in 9: pts.append(c + Vector2(-16 + k * 3.6, -sin(k / 8.0 * PI) * 7))
	pts.append(c + Vector2(20, -6 + tail)); pts.append(c + Vector2(17, 0)); pts.append(c + Vector2(20, 6 + tail))
	for k in 9: pts.append(c + Vector2(-16 + (8 - k) * 3.6, sin((8 - k) / 8.0 * PI) * 7))
	_shape(ci, pts, Color("#6f9a4a"), 1.4)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -1 - flap * 3), c + Vector2(-9, 0), c + Vector2(-17, 1 + flap * 3)]), INK)
	ci.draw_circle(c + Vector2(-10, -3), 1.4, INK)
	if sing or fmod(t, 11.0) < 1.5:
		for k in 3:
			var q := fmod(t * 0.9 + k * 0.33, 1.0)
			var np := c + Vector2(-20 - q * 18, -10 - q * 28 + sin(q * 9 + k) * 3)
			ci.draw_circle(np, 2.2, Color(INK, 1.0 - q))
			ci.draw_line(np + Vector2(2, 0), np + Vector2(2, -7), Color(INK, 1.0 - q), 1.2)
