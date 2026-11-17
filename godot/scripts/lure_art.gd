class_name LureArt
extends RefCounted
## What's on the end of your line, drawn on the water in place of the old red-and-white bobber:
## the bait or lure you have on (worms, shrimp, a spinner, a hot dog chunk, bread, squid, and the
## four home-made lures). Drawn in tile units, about half a tile long.
## a points up the line toward the rod, so the nose (where the line ties on) is +x in the lure's own frame.
## sink goes 0 (riding the surface) to 1 (pulled under): it fades and tints toward the water.

const WATER := Color("#2b6f8f")
const SILVER := Color("#d9e2e6")
const STEEL := Color("#7d8a92")
const INK := Color("#22313a")
const CORAL := Color("#e2583e")
const SUN := Color("#f2b134")

static var _sink := 0.0

static func _c(col: Color) -> Color:
	var c := col.lerp(Color(WATER, col.a), _sink * 0.55)
	c.a *= 1.0 - _sink * 0.5
	return c

static func draw(ci: CanvasItem, id: String, p: Vector2, a: float, sink: float, now: float, dark: float) -> void:
	_sink = clampf(sink, 0.0, 1.0)
	# the lure lies along the line, but the view is 3/4 from above, so squash it a little up and down (and draw it a bit bigger than life so you can tell what it is)
	ci.draw_set_transform_matrix(Transform2D(0.0, p) * Transform2D(0.0, Vector2(1.25, 1.0), 0.0, Vector2.ZERO) * Transform2D(a, Vector2.ZERO))
	match id:
		"worms": _worm(ci, now)
		"shrimp", "bait": _shrimp(ci, now)
		"lure": _spinner(ci, now)
		"hotdog": _hotdog(ci)
		"bread": _bread(ci, now)
		"squid": _squid(ci, now)
		"spoon": _spoon(ci, now)
		"popper": _popper(ci, now)
		"jig": _jig(ci, now)
		"glowlure": _glow(ci, now, dark)
		_: _worm(ci, now)
	ci.draw_set_transform(Vector2.ZERO)

static func _hook(ci: CanvasItem, at: Vector2, s := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var t := PI * 0.5 + i * PI / 6
		pts.append(at + Vector2(cos(t) * 0.04, sin(t) * 0.04 + 0.04) * s)
	ci.draw_polyline(pts, _c(STEEL), 0.014, true)

static func _treble(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_line(at, at + Vector2(-0.05, 0), _c(STEEL), 0.014, true)
	for sy in [-1, 1]:
		var pts := PackedVector2Array()
		for i in 5:
			var t := i * PI / 4
			pts.append(at + Vector2(-0.05 - sin(t) * 0.025, sy * (0.025 - cos(t) * 0.025)))
		ci.draw_polyline(pts, _c(STEEL), 0.012, true)

## A pink nightcrawler threaded on the hook, both ends wriggling.
static func _worm(ci: CanvasItem, now: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var f := i / 12.0
		var wig := sin(f * 8.0 - now * 5.0) * 0.035 * (0.3 + absf(f - 0.35) * 1.6)
		pts.append(Vector2(0.04 - f * 0.32, wig + sin(f * 3.0) * 0.02))
	ci.draw_polyline(pts, _c(Color("#a84e5a")), 0.046)
	ci.draw_polyline(pts, _c(Color("#e88a95")), 0.032)
	var hl := PackedVector2Array()
	for q in pts: hl.append(q + Vector2(0, -0.007))
	ci.draw_polyline(hl, _c(Color(1, 0.85, 0.88, 0.6)), 0.008)
	ci.draw_circle(pts[4], 0.022, _c(Color("#d9737f")))   # the band round its middle
	_hook(ci, Vector2(0.0, -0.01))

## A live shrimp curled on the hook, kicking its tail.
static func _shrimp(ci: CanvasItem, now: float) -> void:
	var col := Color("#f08a6a")
	var kick := sin(now * 6.0) * 0.12
	var c := Vector2(-0.1, 0.02)
	var segs := 7
	var pts := []
	for i in segs:
		var t := lerpf(-0.15, PI * 1.05 + kick, float(i) / (segs - 1))
		pts.append(c + Vector2(cos(t) * 0.11, -sin(t) * 0.08))
	# antennae sweeping forward
	var head: Vector2 = pts[0]
	for k in [-1, 1]:
		var ant := PackedVector2Array([head, head + Vector2(0.09, k * 0.04 - 0.02), head + Vector2(0.17, k * 0.08 - 0.03 + sin(now * 3 + k) * 0.02)])
		ci.draw_polyline(ant, _c(Color(0.55, 0.3, 0.25, 0.8)), 0.008, true)
	var tail: Vector2 = pts[segs - 1]
	ci.draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-0.05, 0.05), tail + Vector2(0.01, 0.07)]), _c(Art.shade(col, -0.12)))
	for i in range(segs - 1, -1, -1):
		var rr := lerpf(0.045, 0.026, float(i) / (segs - 1))
		ci.draw_circle(pts[i], rr + 0.008, _c(Art.shade(col, -0.3)))
		ci.draw_circle(pts[i], rr, _c(col if i % 2 == 0 else Art.shade(col, 0.12)))
	ci.draw_circle(head + Vector2(0.02, -0.02), 0.012, _c(INK))
	_hook(ci, head + Vector2(-0.01, -0.03), 0.8)

## The spinner from Lou's: a gold body on a wire with a silver blade whirling at the front.
static func _spinner(ci: CanvasItem, now: float) -> void:
	ci.draw_line(Vector2(0.08, 0), Vector2(-0.3, 0), _c(STEEL), 0.014, true)
	var spin := cos(now * 16.0)
	var bw := 0.012 + 0.05 * absf(spin)
	Art.ellipse(ci, Vector2(0.02, 0.0), 0.075, bw, _c(SILVER if spin > 0 else Color("#aab6bc")))
	if spin > 0.6: ci.draw_circle(Vector2(0.03, -bw * 0.4), 0.02, _c(Color(1, 1, 1, 0.9)))
	ci.draw_circle(Vector2(-0.08, 0), 0.026, _c(CORAL))
	ci.draw_circle(Vector2(-0.125, 0), 0.026, _c(SUN))
	Art.ellipse(ci, Vector2(-0.2, 0), 0.065, 0.034, _c(Color("#d6a43a")))
	ci.draw_line(Vector2(-0.24, -0.012), Vector2(-0.16, -0.012), _c(Color(1, 1, 1, 0.5)), 0.01)
	for i in 6:
		var t := lerpf(-0.5, 0.5, i / 5.0) + sin(now * 7 + i) * 0.08
		ci.draw_line(Vector2(-0.26, 0), Vector2(-0.26, 0) + Vector2(-cos(t), sin(t)) * 0.13, _c(Color("#d23c3c")), 0.016, true)

## A chunk of hot dog on the hook, with a streak of mustard.
static func _hotdog(ci: CanvasItem) -> void:
	var dog := Color("#c4553f")
	_capsule(ci, Vector2(-0.02, 0), Vector2(-0.16, 0), 0.05, _c(Art.shade(dog, -0.35)))
	_capsule(ci, Vector2(-0.02, 0), Vector2(-0.16, 0), 0.04, _c(dog))
	ci.draw_circle(Vector2(-0.02, 0), 0.03, _c(Color("#e39a7e")))   # the cut end, paler inside
	ci.draw_line(Vector2(-0.04, -0.022), Vector2(-0.16, -0.022), _c(Color(1, 1, 1, 0.35)), 0.01, true)
	var z := PackedVector2Array()
	for i in 5: z.append(Vector2(-0.06 - i * 0.025, (-0.012 if i % 2 == 0 else 0.012)))
	ci.draw_polyline(z, _c(SUN), 0.012, true)
	_hook(ci, Vector2(0.02, -0.02), 0.9)

static func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	ci.draw_line(a, b, col, r * 2.0)
	ci.draw_circle(a, r, col); ci.draw_circle(b, r, col)

## A doughy ball of white bread, going soft and shedding crumbs.
static func _bread(ci: CanvasItem, now: float) -> void:
	for i in 5:
		var t := i * TAU / 5 + now * 0.3
		var r := 0.12 + 0.03 * sin(now * 0.8 + i)
		ci.draw_circle(Vector2(-0.05, 0) + Vector2(cos(t), sin(t)) * r, 0.012, _c(Color(0.98, 0.95, 0.87, 0.7)))
	ci.draw_circle(Vector2(-0.05, 0.01), 0.085, _c(Color("#c48a4a")))
	ci.draw_circle(Vector2(-0.05, 0.0), 0.075, _c(Color("#fbf1dc")))
	ci.draw_circle(Vector2(-0.07, -0.02), 0.03, _c(Color(1, 1, 1, 0.7)))
	for q in [Vector2(-0.02, 0.02), Vector2(-0.09, 0.03), Vector2(-0.04, -0.035)]: ci.draw_circle(q, 0.008, _c(Color("#d9c49a")))
	_hook(ci, Vector2(0.03, -0.02), 0.8)

## A strip of frozen squid, its tentacles trailing.
static func _squid(ci: CanvasItem, now: float) -> void:
	var col := Color("#e8b4c4")
	for i in 5:
		var y0 := (i - 2) * 0.016
		var pts := PackedVector2Array()
		for j in 6:
			var f := j / 5.0
			pts.append(Vector2(-0.16 - f * 0.2, y0 * (1.0 + f * 1.5) + sin(f * 5 - now * 4 + i) * 0.02 * f))
		ci.draw_polyline(pts, _c(Art.shade(col, -0.08)), 0.014, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.07, 0), Vector2(0.02, -0.05), Vector2(-0.17, -0.045), Vector2(-0.19, 0), Vector2(-0.17, 0.045), Vector2(0.02, 0.05)]), _c(Art.shade(col, -0.25)))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.06, 0), Vector2(0.02, -0.04), Vector2(-0.16, -0.036), Vector2(-0.175, 0), Vector2(-0.16, 0.036), Vector2(0.02, 0.04)]), _c(col))
	for q in [Vector2(-0.02, -0.012), Vector2(-0.08, 0.014), Vector2(-0.12, -0.01), Vector2(0.02, 0.012)]: ci.draw_circle(q, 0.009, _c(Color("#a35a86")))
	_hook(ci, Vector2(0.05, -0.02), 0.9)

## Home-made: a spoon with a red stripe, wobbling and flashing.
static func _spoon(ci: CanvasItem, now: float) -> void:
	var wob := sin(now * 5.0)
	ci.draw_line(Vector2(0.08, 0), Vector2(0.03, 0), _c(STEEL), 0.014, true)
	ci.draw_arc(Vector2(0.09, 0), 0.016, 0, TAU, 8, _c(STEEL), 0.01, true)
	Art.ellipse(ci, Vector2(-0.1, 0), 0.135, 0.06 + wob * 0.008, _c(STEEL))
	Art.ellipse(ci, Vector2(-0.1, 0), 0.122, 0.05 + wob * 0.008, _c(SILVER))
	ci.draw_line(Vector2(-0.04, -0.035), Vector2(-0.15, 0.035), _c(Color(CORAL, 0.9)), 0.022, true)
	# a glint that slides across as it wobbles
	ci.draw_circle(Vector2(-0.1 + wob * 0.07, -0.022), 0.02, _c(Color(1, 1, 1, 0.55 + 0.4 * absf(wob))))
	_treble(ci, Vector2(-0.235, 0))

## Home-made: a bottle-cap popper, a yellow bead body with a cup face that chugs the surface.
static func _popper(ci: CanvasItem, now: float) -> void:
	# a little bulge of water pushed ahead of the cup
	ci.draw_arc(Vector2(0.06, 0), 0.07 + 0.01 * sin(now * 4), -1.1, 1.1, 10, _c(Color(1, 1, 1, 0.45)), 0.014, true)
	Art.ellipse(ci, Vector2(-0.11, 0), 0.115, 0.06, _c(Art.shade(SUN, -0.3)))
	Art.ellipse(ci, Vector2(-0.11, 0), 0.105, 0.052, _c(SUN))
	ci.draw_line(Vector2(-0.18, -0.025), Vector2(-0.05, -0.025), _c(Color(1, 1, 1, 0.5)), 0.012)
	Art.ellipse(ci, Vector2(0.0, 0), 0.03, 0.075, _c(Art.shade(CORAL, -0.3)))
	Art.ellipse(ci, Vector2(0.006, 0), 0.022, 0.065, _c(CORAL))
	ci.draw_circle(Vector2(-0.04, -0.02), 0.012, _c(INK))
	ci.draw_circle(Vector2(-0.225, 0), 0.022, _c(Color("#13807b")))
	_treble(ci, Vector2(-0.1, 0.05))

## Home-made: a feather jig, a red head with white and yellow feathers that breathe in the water.
static func _jig(ci: CanvasItem, now: float) -> void:
	var breathe := 1.0 + 0.25 * sin(now * 4.5)
	for i in 9:
		var t := lerpf(-0.42, 0.42, i / 8.0) * breathe
		var ln := 0.24 + 0.03 * sin(i * 1.7)
		var col := Color("#f7f2e6") if i % 3 != 1 else Color("#e8b54a")
		ci.draw_line(Vector2(-0.03, 0), Vector2(-0.03, 0) + Vector2(-cos(t), sin(t)) * ln, _c(col), 0.022, true)
	ci.draw_circle(Vector2(0.0, 0), 0.055, _c(Art.shade(CORAL, -0.35)))
	ci.draw_circle(Vector2(0.0, 0), 0.047, _c(CORAL))
	ci.draw_circle(Vector2(-0.012, -0.018), 0.014, _c(Color(1, 1, 1, 0.7)))
	ci.draw_circle(Vector2(0.02, -0.01), 0.013, _c(Color.WHITE)); ci.draw_circle(Vector2(0.024, -0.01), 0.007, _c(INK))

## Home-made: the glow lure, a bead body full of glow-stick goo. After dark it lights up the water around it.
static func _glow(ci: CanvasItem, now: float, dark: float) -> void:
	var g := (0.75 + 0.25 * sin(now * 2.5)) * (0.35 + dark)
	ci.draw_circle(Vector2(-0.1, 0), 0.26, Color(0.6, 1.0, 0.35, 0.08 * g))
	ci.draw_circle(Vector2(-0.1, 0), 0.16, Color(0.6, 1.0, 0.35, 0.14 * g))
	ci.draw_line(Vector2(0.07, 0), Vector2(-0.3, 0), _c(STEEL), 0.012, true)
	for i in 3: ci.draw_circle(Vector2(0.03 - i * 0.05, 0), 0.026, _c(Color("#c8ff7a")))
	Art.ellipse(ci, Vector2(-0.19, 0), 0.065, 0.04, _c(Color("#a8f05a")))
	ci.draw_line(Vector2(-0.23, -0.014), Vector2(-0.16, -0.014), _c(Color(1, 1, 1, 0.6)), 0.01)
	_treble(ci, Vector2(-0.255, 0))
