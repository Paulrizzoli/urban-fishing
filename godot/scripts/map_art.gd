class_name MapArt
extends Node2D
## The big map's picture: streets with lane markings, building footprints with roofs and shadows, parks,
## water with the same rounded shores as the game, docks, bridges, fences and the private areas hatched in red.
## It's drawn once, the first time the map opens, into one texture (S pixels per tile), so the map itself
## only has to draw that one picture plus the labels and markers on top.

const S := 16                     # map pixels per tile

## Named streets: [name, from, to (tile centers along the middle of the road), width in tiles].
const STREETS := [
	["US-1", Vector2(0, 35.5), Vector2(112, 35.5), 3],
	["Canal Rd", Vector2(41.5, 0), Vector2(41.5, 157), 3],
	["Plant Rd", Vector2(59.5, 37), Vector2(59.5, 85), 3],
	["Maple Park Dr", Vector2(0, 13), Vector2(39, 13), 2],
	["Pond St", Vector2(21, 0), Vector2(21, 33), 2],
	["Low Street", Vector2(0, 64), Vector2(37, 64), 2],
	["Airport Blvd", Vector2(0, 84), Vector2(112, 84), 2],
	["Egret Circle", Vector2(47, 92), Vector2(76, 92), 2],
	["Egret Circle", Vector2(47, 111), Vector2(76, 111), 2],
	["Egret Circle", Vector2(48, 91), Vector2(48, 112), 2],
	["Egret Circle", Vector2(75, 91), Vector2(75, 112), 2],
	["Flamingo Ave", Vector2(0, 118), Vector2(112, 118), 2],
	["Second St", Vector2(0, 137), Vector2(112, 137), 2],
	["Bayshore Dr", Vector2(0, 156), Vector2(112, 156), 2],
	["Ocean Ave", Vector2(21, 117), Vector2(21, 157), 2],
	["Marina Way", Vector2(97, 117), Vector2(97, 157), 2],
]

const STREETS2 := [
	["Lakeshore Dr", Vector2(0, 34), Vector2(37, 34), 2], ["Lakeshore Dr", Vector2(75, 34), Vector2(112, 34), 2],
	["River St", Vector2(42, 39), Vector2(42, 184), 2], ["Bank St", Vector2(70, 39), Vector2(70, 184), 2],
	["1st Ave", Vector2(13, 33), Vector2(13, 184), 2], ["Bluff Ave", Vector2(99, 33), Vector2(99, 184), 2],
	["Mill St", Vector2(0, 59), Vector2(112, 59), 2], ["Market St", Vector2(0, 125), Vector2(112, 125), 2], ["Front St", Vector2(0, 161), Vector2(112, 161), 2],
	["I-90 Viaduct", Vector2(0, 94.5), Vector2(112, 94.5), 4],
]
const STREETS3 := [
	["Kestrel Ave", Vector2(17, 0), Vector2(17, 184), 2], ["Commercial St", Vector2(39, 0), Vector2(39, 184), 2], ["Harbor Ave", Vector2(60, 0), Vector2(60, 136), 2],
	["Pilot St", Vector2(0, 29), Vector2(62, 29), 2], ["Ferry St", Vector2(0, 59), Vector2(62, 59), 2], ["Wharf St", Vector2(0, 81), Vector2(62, 81), 2],
	["Tanner St", Vector2(0, 113), Vector2(62, 113), 2], ["Port Rd", Vector2(0, 134), Vector2(62, 134), 2], ["Union St", Vector2(0, 166), Vector2(62, 166), 2],
	["Gannet Narrows Bridge", Vector2(0, 98.5), Vector2(112, 98.5), 4],
]
static func streets() -> Array: return [STREETS, STREETS2, STREETS3][Town.level]

const C_GRASS := Color("#c3e3a3")
const C_FAIR_A := Color("#a7d888")
const C_FAIR_B := Color("#9dd07e")
const C_ROAD := Color("#6d737a")
const C_RUNWAY := Color("#5c6269")
const C_WALK := Color("#ebe4d4")
const C_CONC := Color("#ddd8cd")
const C_PLAZA := Color("#efe1c4")
const C_SAND := Color("#f2e0ae")
const C_DOCK := Color("#b88b5b")
const C_PATH := Color("#e4cf9b")
const C_WALL := Color("#857c71")
const C_DRAIN := Color("#5f5850")
const C_INK := Color("#22313a")

static var tex: Texture2D          # the finished picture, once it has been drawn
static var _water_mat: ShaderMaterial

## Draws the map picture into an offscreen viewport, keeps it as a texture and calls done.
## Only the first call does any work.
static func bake(host: Node, done: Callable) -> void:
	if tex != null:
		done.call(); return
	var vp := SubViewport.new()
	vp.size = Vector2i(Town.MW * S, Town.MH * S)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var art := MapArt.new()
	art.done = done
	art.vp = vp
	vp.add_child(art)
	host.add_child(vp)

var done: Callable
var vp: SubViewport

func _ready() -> void:
	scale = Vector2(S, S)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# the water, drawn with a shader so its shores are as smooth as the game's
	var water := _Water.new()
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(water)
	add_child(_Features.new())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.generate_mipmaps()
	MapArt.tex = ImageTexture.create_from_image(img)
	vp.queue_free()
	if done.is_valid(): done.call()

# ---------- the ground: a flat color per tile, in runs ----------

static func ground_color(x: int, y: int) -> Color:
	var T := Town.T
	var t := Town.t_at(x, y)
	if t == T.TREE or t == T.BUSH: t = T.GRASS if Ground.is_lawn(x, y) else Ground.under(x, y)
	elif t == T.BLD: t = T.CONC
	elif t == T.FENCE or t == T.HWALL or t == T.GAP or t == T.GATE: t = T.GRASS
	if Town.is_water_t(t):
		var k := Ground.coast_kind(x, y)
		return C_SAND if k == "sand" else C_GRASS if k == "lawn" else C_WALK
	match t:
		T.GRASS: return C_GRASS
		T.FAIR: return C_FAIR_A if ((x + y) / 3) % 2 == 0 else C_FAIR_B
		T.ROAD: return C_ROAD
		T.RUNWAY: return C_RUNWAY
		T.WALK, T.DOOR, T.GRATE: return C_WALK
		T.CONC: return C_CONC
		T.PLAZA: return C_PLAZA
		T.SAND: return C_SAND
		T.DOCK: return C_DOCK
		T.PATH, T.HIDE: return C_PATH
		T.WALL: return C_WALL
		T.SFLOOR: return C_DRAIN
		T.PGATE, T.HGATE: return C_PATH if t == T.PGATE else C_ROAD
	return C_GRASS

func _draw() -> void:
	for y in Town.MH:
		var x0 := 0
		var c0 := ground_color(0, y)
		for x in range(1, Town.MW + 1):
			var c := ground_color(x, y) if x < Town.MW else Color(0, 0, 0, 0)
			if c != c0:
				draw_rect(Rect2(x0, y, x - x0, 1), c0)
				x0 = x; c0 = c

# ---------- the water ----------

class _Water extends Node2D:
	func _ready() -> void:
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
uniform sampler2D mask : filter_linear;
void fragment() {
	vec4 m = texture(mask, UV);
	float w = m.r;
	float aa = fwidth(w) * 0.75 + 0.001;
	float a = smoothstep(0.5 - aa, 0.5 + aa, w);
	vec3 shallow = vec3(0.55, 0.80, 0.88);
	vec3 deep = vec3(0.17, 0.45, 0.64);
	float g = m.g;
	vec3 c = mix(shallow, deep, smoothstep(0.0, 1.0, g));
	if (m.b > 0.5) c = vec3(0.33, 0.39, 0.33);
	// a soft lighter band, then a crisp darker shoreline
	float band = 1.0 - smoothstep(0.5, 0.75, w);
	c = mix(c, vec3(0.70, 0.89, 0.93), band * 0.35);
	float edge = 1.0 - smoothstep(0.5 + aa, 0.5 + aa * 3.5, w);
	c = mix(c, vec3(0.16, 0.40, 0.55), edge * 0.85);
	// a thin ripple line following the shore a little way out
	float gw = fwidth(g) + 0.0005;
	float rip = 1.0 - smoothstep(0.0, gw * 1.2, abs(g - 0.09));
	c = mix(c, vec3(0.80, 0.93, 0.96), rip * 0.45 * step(0.62, w));
	COLOR = vec4(c, a);
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("mask", Ground.make_water_mask())
		material = mat

	func _draw() -> void:
		draw_rect(Rect2(0, 0, Town.MW, Town.MH), Color.WHITE)

# ---------- everything on top of the ground and water ----------

class _Features extends Node2D:
	const T := Town.T

	func _draw() -> void:
		_fairway()
		_lots()
		if Town.level == 0: _runway()
		_road_edges()
		_lanes()
		_paths()
		_docks()
		_bridges()
		_fences()
		_zones()
		_plants()
		_buildings()

	func line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
		draw_line(a, b, c, w, true)

	## Greens with their flags, and the sand traps get a darker rim.
	func _fairway() -> void:
		for d in Town.decor:
			if d.k == "green":
				var p := Vector2(d.x, d.y)
				draw_circle(p, 2.3, Color("#8bd16a"))
				draw_circle(p, 2.3, Color("#6fb653"), false, 0.12, true)
				line(p, p + Vector2(0, -1.4), C_INK, 0.1)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -1.4), p + Vector2(0.9, -1.15), p + Vector2(0, -0.9)]), Color("#e2583e"))
				draw_circle(p, 0.18, C_INK)

	## Parking lots with their bays, and every driveway.
	func _lots() -> void:
		for d in Town.decor:
			if d.k != "parking": continue
			var r := Rect2(d.x0, d.y0, d.x1 - d.x0 + 1, d.y1 - d.y0 + 1)
			draw_rect(r, Color("#b9b7b1"))
			var mid := r.position.y + r.size.y / 2
			line(Vector2(r.position.x + 0.3, mid), Vector2(r.end.x - 0.3, mid), Color(1, 1, 1, 0.8), 0.07)
			var x := r.position.x + 0.5
			while x < r.end.x - 0.2:
				line(Vector2(x, r.position.y + 0.25), Vector2(x, r.end.y - 0.25), Color(1, 1, 1, 0.8), 0.06)
				x += 1.0
		for dw in Town.driveways:
			draw_rect(dw.r, Color("#d4cfc4"))

	func _runway() -> void:
		var y := 99.5
		var x := 86.0
		while x < 108.5:
			draw_rect(Rect2(x, y - 0.1, 1.2, 0.2), Color(1, 1, 1, 0.9)); x += 2.2
		for e in [84.4, 109.0]:
			for i in 6: draw_rect(Rect2(e, 97.4 + i * 0.7, 0.6, 0.3), Color(1, 1, 1, 0.85))
		line(Vector2(84, 97.1), Vector2(111, 97.1), Color(1, 1, 1, 0.6), 0.08)
		line(Vector2(84, 101.9), Vector2(111, 101.9), Color(1, 1, 1, 0.6), 0.08)
		x = 90.95
		var yy := 92.2
		while yy < 96.6:
			draw_rect(Rect2(x, yy, 0.1, 0.5), Color("#f2c84b")); yy += 0.9

	## A light curb wherever a road meets something that isn't road.
	func _road_edges() -> void:
		var cur := Color("#f6f1e6")
		for y in Town.MH:
			for x in Town.MW:
				if Town.t_at(x, y) != T.ROAD and Town.t_at(x, y) != T.HGATE: continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Town.t_at(x + d.x, y + d.y)
					if n == T.ROAD or n == T.HGATE or not Town.inb(x + d.x, y + d.y): continue
					var a := Vector2(x, y) + (Vector2(1, 1) if d.x > 0 or d.y > 0 else Vector2.ZERO)
					var b := a - Vector2(0, 1) if d.x > 0 else a + Vector2(0, 1) if d.x < 0 else a - Vector2(1, 0) if d.y > 0 else a + Vector2(1, 0)
					var inset := Vector2(d) * -0.06
					line(a + inset, b + inset, cur, 0.1)

	## Dashed lines down the middle of each street, broken at the crossings.
	func _lanes() -> void:
		for s in MapArt.streets():
			var a: Vector2 = s[1]
			var b: Vector2 = s[2]
			var w: int = s[3]
			var horiz := absf(b.x - a.x) > absf(b.y - a.y)
			var mid: float = a.y if horiz else a.x
			var first := floori(mid - w / 2.0)
			var last := floori(mid + w / 2.0 - 0.01)
			var col := Color("#f2c84b") if w >= 3 else Color(1, 1, 1, 0.75)
			var from := int(minf(a.x, b.x) if horiz else minf(a.y, b.y))
			var to := int(maxf(a.x, b.x) if horiz else maxf(a.y, b.y))
			for i in range(from, to):
				if i % 2 == 1: continue
				var on := Vector2i(i, first) if horiz else Vector2i(first, i)
				var before := Vector2i(i, first - 1) if horiz else Vector2i(first - 1, i)
				var after := Vector2i(i, last + 1) if horiz else Vector2i(last + 1, i)
				if Town.t_at(on.x, on.y) != T.ROAD: continue
				if Town.t_at(before.x, before.y) == T.ROAD or Town.t_at(after.x, after.y) == T.ROAD: continue
				var p := Vector2(i + 0.5, mid) if horiz else Vector2(mid, i + 0.5)
				var d := Vector2(0.35, 0) if horiz else Vector2(0, 0.35)
				line(p - d, p + d, col, 0.11)

	## Footpaths get a dotted center line.
	func _paths() -> void:
		for y in Town.MH:
			for x in Town.MW:
				if Town.t_at(x, y) == T.PATH and (x + y) % 2 == 0:
					draw_circle(Vector2(x + 0.5, y + 0.5), 0.09, Color("#b99d62"))

	func _docks() -> void:
		var plank := Color("#8d6640")
		for y in Town.MH:
			for x in Town.MW:
				if Town.t_at(x, y) != T.DOCK: continue
				var vert := Town.t_at(x, y - 1) == T.DOCK or Town.t_at(x, y + 1) == T.DOCK
				var horiz := Town.t_at(x - 1, y) == T.DOCK or Town.t_at(x + 1, y) == T.DOCK
				for i in 3:
					var f := (i + 0.5) / 3.0
					if vert and not horiz: line(Vector2(x, y + f), Vector2(x + 1, y + f), plank, 0.05)
					else: line(Vector2(x + f, y), Vector2(x + f, y + 1), plank, 0.05)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if Town.t_at(x + d.x, y + d.y) == T.DOCK: continue
					var c := Vector2(x + 0.5, y + 0.5) + Vector2(d) * 0.5
					var side := Vector2(d.y, d.x) * 0.5
					line(c - side, c + side, Color("#6e4e30"), 0.09)

	## Railings along each side of a bridge.
	func _bridges() -> void:
		for br in Town.bridges:
			var r := Rect2(br.x0, br.y0, br.x1 - br.x0 + 1, br.y1 - br.y0 + 1)
			var col := Color("#3d4a52")
			if br.get("h", false):
				for yy in [r.position.y + 0.08, r.end.y - 0.08]:
					line(Vector2(r.position.x - 0.15, yy), Vector2(r.end.x + 0.15, yy), col, 0.16)
			else:
				for xx in [r.position.x + 0.08, r.end.x - 0.08]:
					line(Vector2(xx, r.position.y - 0.15), Vector2(xx, r.end.y + 0.15), col, 0.16)

	## Fences and walls as lines joining their posts; gates get a little orange bar.
	func _fences() -> void:
		for y in Town.MH:
			for x in Town.MW:
				var t := Town.t_at(x, y)
				var c := Vector2(x + 0.5, y + 0.5)
				if t == T.FENCE or t == T.HWALL:
					var col := Color("#55606a") if t == T.FENCE else Color("#c49a6c")
					var w := 0.13 if t == T.FENCE else 0.34
					var linked := false
					for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
						var n := Town.t_at(x + d.x, y + d.y)
						if n == t or n in [T.GATE, T.PGATE, T.HGATE]:
							linked = true
							line(c, c + Vector2(d) * 0.5, col, w)
					if not linked: draw_circle(c, w, col)
					if t == T.FENCE and (x + y) % 2 == 0: draw_circle(c, 0.11, col)
				elif t == T.GATE or t == T.PGATE or t == T.HGATE:
					var horiz := Town.t_at(x - 1, y) in [T.FENCE, T.HWALL] or Town.t_at(x + 1, y) in [T.FENCE, T.HWALL]
					var dd := Vector2(0.42, 0) if horiz else Vector2(0, 0.42)
					line(c - dd, c + dd, Color("#e8892f"), 0.2)

	## Private ground: a light red wash with diagonal hatching and a dashed red border.
	func _zones() -> void:
		var wash := Color(0.89, 0.25, 0.2, 0.10)
		var hatch := Color(0.80, 0.22, 0.18, 0.30)
		var edge := Color(0.78, 0.2, 0.16, 0.85)
		for y in Town.MH:
			for x in Town.MW:
				var z: int = Town.zone[Town.idx(x, y)]
				if z == 0: continue
				draw_rect(Rect2(x, y, 1, 1), wash)
				if (x + y) % 2 == 0: line(Vector2(x, y + 1), Vector2(x + 1, y), hatch, 0.08)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if Town.inb(x + d.x, y + d.y) and Town.zone[Town.idx(x + d.x, y + d.y)] == z: continue
					var c := Vector2(x + 0.5, y + 0.5) + Vector2(d) * 0.46
					var side := Vector2(d.y, d.x) * 0.25
					line(c - side, c + side, edge, 0.12)

	func _plants() -> void:
		for y in Town.MH:
			for x in Town.MW:
				var t := Town.t_at(x, y)
				var c := Vector2(x + 0.5, y + 0.5)
				var j := Vector2(Town.hash2(x, y) - 0.5, Town.hash2(y, x) - 0.5) * 0.18
				if t == T.TREE:
					draw_circle(c + j + Vector2(0.12, 0.16), 0.62, Color(0, 0, 0, 0.16))
					draw_circle(c + j, 0.62, Color("#4f8f45"))
					draw_circle(c + j + Vector2(-0.14, -0.14), 0.36, Color("#6aad55"))
					draw_circle(c + j, 0.62, Color("#3a6f35"), false, 0.07, true)
				elif t == T.BUSH:
					draw_circle(c + j + Vector2(0.08, 0.1), 0.4, Color(0, 0, 0, 0.14))
					draw_circle(c + j, 0.4, Color("#79b65a"))
					draw_circle(c + j + Vector2(-0.1, -0.1), 0.2, Color("#93c96f"))

	func _buildings() -> void:
		for b in Town.buildings:
			var r := Rect2(b.x, b.y, b.w, b.h)
			var col := Color(b.get("color", "#c9b9a0"))
			var kind: String = b.get("kind", "house")
			var ht := float(b.get("ht", 2 if kind != "house" else 1))
			match kind:
				"tower":   # the power station's cooling tower
					var c := r.get_center()
					draw_circle(c + Vector2(0.5, 0.6), 3.1, Color(0, 0, 0, 0.2))
					draw_circle(c, 3.1, Color("#b9c2c7"))
					draw_circle(c, 3.1, Color("#5d686f"), false, 0.14, true)
					draw_circle(c, 2.1, Color("#8d989f"))
					draw_circle(c + Vector2(0.4, 0.3), 1.5, Color("#6f7a81"))
					continue
				"volcano":
					var c := r.get_center()
					draw_circle(c + Vector2(0.3, 0.4), 2.4, Color(0, 0, 0, 0.2))
					draw_circle(c, 2.4, Color("#7a5a3c"))
					draw_circle(c, 1.5, Color("#5c4632"))
					draw_circle(c, 0.8, Color("#e2583e"))
					draw_circle(c, 0.45, Color("#f6c86d"))
					continue
			# shadow, longer for taller buildings
			var sh := clampf(ht * 0.09, 0.25, 1.4)
			draw_rect(Rect2(r.position + Vector2(sh, sh * 1.2), r.size), Color(0, 0, 0, 0.2))
			draw_rect(r, col)
			var dark := col.darkened(0.38)
			if kind == "house":
				# a hip roof: the far halves a touch darker, with a ridge
				var long_x := r.size.x >= r.size.y
				if long_x:
					draw_rect(Rect2(r.position.x, r.get_center().y, r.size.x, r.size.y / 2), col.darkened(0.12))
					line(Vector2(r.position.x + r.size.y / 2, r.get_center().y), Vector2(r.end.x - r.size.y / 2, r.get_center().y), col.lightened(0.3), 0.1)
					for e in [[r.position, r.position + Vector2(r.size.y / 2, r.size.y / 2)], [Vector2(r.position.x, r.end.y), r.position + Vector2(r.size.y / 2, r.size.y / 2)],
							[Vector2(r.end.x, r.position.y), Vector2(r.end.x - r.size.y / 2, r.get_center().y)], [r.end, Vector2(r.end.x - r.size.y / 2, r.get_center().y)]]:
						line(e[0], e[1], col.darkened(0.2), 0.06)
				else:
					draw_rect(Rect2(r.get_center().x, r.position.y, r.size.x / 2, r.size.y), col.darkened(0.12))
					line(Vector2(r.get_center().x, r.position.y + r.size.x / 2), Vector2(r.get_center().x, r.end.y - r.size.x / 2), col.lightened(0.3), 0.1)
				if b.get("home", false):
					draw_rect(r.grow(0.1), Color("#e2583e"), false, 0.14)
			else:
				# a flat roof with a parapet and some rooftop units
				draw_rect(r.grow(-0.35), col.lightened(0.12))
				draw_rect(r.grow(-0.35), col.darkened(0.15), false, 0.06)
				if kind == "sky":
					if b.get("glass", false):
						var gx := r.position.x + 0.8
						while gx < r.end.x - 0.6:
							line(Vector2(gx, r.position.y + 0.5), Vector2(gx, r.end.y - 0.5), Color(1, 1, 1, 0.25), 0.05); gx += 0.8
					if b.get("pool", false):
						draw_rect(Rect2(r.position + Vector2(0.8, 0.8), Vector2(minf(2.6, r.size.x - 1.6), 1.4)), Color("#6cc3dc"))
					if b.get("heli", false):
						var c := r.get_center()
						draw_circle(c, 1.6, Color("#4a5a63")); draw_circle(c, 1.6, Color("#f2c84b"), false, 0.1, true)
						line(c + Vector2(-0.5, -0.6), c + Vector2(-0.5, 0.6), Color.WHITE, 0.16)
						line(c + Vector2(0.5, -0.6), c + Vector2(0.5, 0.6), Color.WHITE, 0.16)
						line(c + Vector2(-0.5, 0), c + Vector2(0.5, 0), Color.WHITE, 0.16)
					if b.get("ant", false):
						draw_circle(r.position + Vector2(r.size.x - 1.1, 1.1), 0.28, Color("#e2583e"))
				elif r.size.x >= 4 and r.size.y >= 3:
					var u := Rect2(r.position + Vector2(r.size.x * 0.62, r.size.y * 0.3), Vector2(1.1, 0.8))
					draw_rect(u, col.darkened(0.25)); draw_rect(u.grow(-0.2), col.darkened(0.1))
			draw_rect(r, dark, false, 0.1)
