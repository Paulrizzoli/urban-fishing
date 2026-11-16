class_name Weather
extends CanvasLayer
## Sun, clouds, rainy days and afternoon thunderstorms. Game.wx holds the current weather;
## this layer draws the screen-space part: the grey of an overcast day, falling rain,
## lightning, and a soft vignette. Raindrop rings on the water are drawn in the world (ripples()).

var flash := 0.0
var node: Control
var vignette: GradientTexture2D

static func kind(day: int) -> String:
	if day <= 2: return "sunny"
	var r := Town.hash2(int(Town.hash2(day, 41) * 1e6), day * 7 + 3)
	return "sunny" if r < 0.42 else "cloudy" if r < 0.62 else "storm" if r < 0.86 else "rain"

static func compute(day: int, h: float) -> Dictionary:
	var k := kind(day)
	var rain := 0.0
	var cloud := 0.6 if k == "cloudy" else 0.1 if k == "sunny" else 0.3
	var storm := false
	if k == "storm":
		if h > 12.5 and h < 18: cloud = 0.9
		if h > 13.5 and h < 17.5:
			rain = minf(1.0, minf((h - 13.5) * 2, (17.5 - h) * 2)); storm = rain > 0.6
	if k == "rain":
		cloud = 0.85
		if h > 8 and h < 19: rain = maxf(0.0, minf(0.75, minf(h - 8, 19 - h)) * (0.55 + 0.45 * sin(h * 1.7)))
	return { "k": k, "rain": rain, "cloud": cloud, "storm": storm }

static func label() -> String:
	var wx: Dictionary = Game.wx
	if wx.rain > 0.05: return "Thunderstorm" if wx.storm else "Raining"
	return { "sunny": "Sunny", "cloudy": "Cloudy", "storm": "Storms at 1:30 PM" if Game.hour() < 13.5 else "Clearing up", "rain": "Rain on and off" }[wx.k]

static func forecast_news(day: int) -> String:
	match kind(day):
		"storm": return ["Forecast: Afternoon Thunderstorms, 1:30 to 5:30; Fish Expected to 'Go Nuts'", "Storms This Afternoon; Guards Plan to 'Mostly Stand Under Awnings'"].pick_random()
		"rain": return ["Forecast: Rain All Day; Old-Timer Calls It 'Perfect'", "Soggy Day Ahead; Bait Shop Expects Rush on Ponchos"].pick_random()
	return ""

func _ready() -> void:
	layer = 2
	node = Control.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.draw.connect(_draw_screen)
	add_child(node)
	vignette = GradientTexture2D.new()
	vignette.width = 256; vignette.height = 256
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5); vignette.fill_to = Vector2(1.08, 1.08)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.04, 0.08, 0.16, 0), Color(0.04, 0.08, 0.16, 0), Color(0.04, 0.08, 0.16, 0.3)])
	vignette.gradient = g

func _process(dt: float) -> void:
	if flash > 0: flash = maxf(0, flash - dt * 2.5)
	if Game.wx.storm and randf() < dt * 0.1: flash = 1.0
	node.queue_redraw()

func _draw_screen() -> void:
	var wx: Dictionary = Game.wx
	var vs := node.size
	var dk := Game.darkness()
	var t := Time.get_ticks_msec() / 1000.0
	var dim: float = wx.cloud * 0.09 + wx.rain * 0.16
	if dim > 0.02 and dk < 0.6: node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.16, 0.22, 0.29, dim * (1 - dk)))
	if wx.rain > 0.03:
		var col := Color(0.78, 0.86, 0.94, 0.3 * wx.rain + 0.12)
		var n := int(260 * wx.rain)
		var pts := PackedVector2Array()
		for i in n:
			var sp := 900.0 + Town.hash2(i, 3) * 400
			var x := fmod(Town.hash2(i, 1) * (vs.x + 100) + t * 120, vs.x + 100) - 50
			var y := fmod(Town.hash2(i, 2) * (vs.y + 60) + t * sp, vs.y + 60) - 30
			pts.append(Vector2(x, y)); pts.append(Vector2(x - 5, y + 20))
		if pts.size(): node.draw_multiline(pts, col, 1.5)
	if flash > 0: node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.92, 0.94, 1, 0.55 * flash * flash))
	node.draw_texture_rect(vignette, Rect2(Vector2.ZERO, vs), false)

## Raindrop rings on open water and drifting cloud shadows, in world tile coordinates.
static func ripples(ci: CanvasItem, view: Rect2) -> void:
	var wx: Dictionary = Game.wx
	var t := Time.get_ticks_msec() / 1000.0
	var dk := Game.darkness()
	# cloud shadows sliding across town
	var a: float = (0.05 + wx.cloud * 0.09) * (1 - dk * 1.8)
	if a > 0.01:
		var span := Town.MW + 50.0
		for i in 14:
			var cx := fmod(Town.hash2(i, 1) * span + t * (0.5 + Town.hash2(i, 3) * 0.4), span) - 25
			var cy := Town.hash2(i, 2) * Town.MH
			if cx < view.position.x - 12 or cx > view.end.x + 12 or cy < view.position.y - 10 or cy > view.end.y + 10: continue
			for j in 4:
				var o := Vector2((Town.hash2(i, j + 10) - 0.5) * 9, (Town.hash2(i, j + 20) - 0.5) * 4)
				var r := 3 + Town.hash2(i, j + 30) * 3.5
				for k in 4: ci.draw_circle(Vector2(cx, cy) + o, r * (1.0 - k * 0.22), Color(0.08, 0.14, 0.22, a * 0.3))
	if wx.rain <= 0.05: return
	for k in int(90 * wx.rain):
		var ph := t * 1.5 + k * 0.37
		var cyc := floori(ph)
		var f := ph - cyc
		var rx := view.position.x + Town.hash2(k, cyc) * view.size.x
		var ry := view.position.y + Town.hash2(cyc, k + 7) * view.size.y
		if not Town.is_water_t(Town.t_at(floori(rx), floori(ry))): continue
		ci.draw_set_transform(Vector2(rx, ry), 0, Vector2(1, 0.5))
		ci.draw_arc(Vector2.ZERO, 0.08 + f * 0.35, 0, TAU, 16, Color(1, 1, 1, 0.55 * (1 - f)), 0.04)
	ci.draw_set_transform(Vector2.ZERO)
