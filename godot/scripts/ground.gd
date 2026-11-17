class_name Ground
## Bakes the ground into one big texture: flat colors per tile, smooth shallow-to-deep water and soft grass variation.

const PX := 16   # texture pixels per tile

const WPAL := {
	1: ["#5fb3b0", "#2c7d93"], 2: ["#5ab5c4", "#21708f"], 3: ["#5fb5a6", "#2a7d8c"], 4: ["#7fd3c6", "#3a9ba6"], 5: ["#6f7a40", "#465024"], 6: ["#8fe2c6", "#3cb39a"],
	7: ["#5ab5c4", "#21708f"], 9: ["#5aaebb", "#25708a"], 10: ["#5ec8bd", "#26879a"], 11: ["#62b4a8", "#2e7f8e"], 12: ["#78a08e", "#3f6f60"], 13: ["#56acbc", "#226b88"],
	14: ["#74d6d4", "#2b93b6"], 15: ["#2378b0", "#0d3f78"], 16: ["#8ce6f2", "#38b6dc"], 17: ["#7fd2dc", "#3a9cbd"] }

static func base_color(x: int, y: int) -> Color:
	var T := Town.T
	var t: int = Town.tile[Town.idx(x, y)]
	match t:
		T.FAIR: return Color("#93cd66") if ((x >> 1) + (y >> 1)) % 2 else Color("#87c35c")
		T.ROAD: return Color("#4b5058")
		T.WALK, T.DOOR, T.PGATE, T.HGATE: return Color("#d8d1c1")
		T.CONC, T.BLD, T.GATE, T.GAP: return Color("#c4bfb3")
		T.PLAZA: return Color("#e8dcc4")
		T.SAND: return Color("#ecdcab")
		T.PATH, T.HIDE: return Color("#dccfab")
		T.DOCK: return Color("#b38758")
		T.RUNWAY: return Color("#3e4248")
		T.SFLOOR: return Color("#40433e")
		T.WALL: return Color("#2c2f2b")
		T.GRATE: return Color("#2a2c29")
		T.HWALL: return Color("#efe3cc")
		T.WATER, T.DEEP, T.SWATER, T.WARM: return Color(water_pal(x, y)[0])
	return Color("#7db35a")

static func water_pal(x: int, y: int) -> Array:
	var i := Town.idx(x, y)
	var reg: int = 6 if Town.tile[i] == Town.T.WARM else Town.region[i]
	return WPAL.get(reg, WPAL[2])

## Grass, trees and bushes sit on a soft textured lawn, unless they are planted in a plaza, on sand or on the fairway.
static func is_lawn(x: int, y: int) -> bool:
	var T := Town.T
	var t: int = Town.tile[Town.idx(x, y)]
	if t == T.GRASS: return true
	if t == T.TREE or t == T.BUSH: return under(x, y) == T.GRASS
	return false

static func under(x: int, y: int) -> int:
	var T := Town.T
	var c := {}
	var best: int = T.GRASS
	var bn := 1
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var v := Town.t_at(x + d.x, y + d.y)
		if v == T.PLAZA or v == T.SAND or v == T.CONC or v == T.FAIR:
			c[v] = c.get(v, 0) + 1
			if c[v] > bn: bn = c[v]; best = v
	return best

# ---------- coastlines ----------
# Where sand meets open water (beaches, Bird Key) the shoreline follows a smooth, gently wavy curve
# instead of the tile grid. Land is blurred over a few tiles and cut at the halfway mark, which
# rounds every corner while keeping straight shores where they were. Only the look changes:
# walking and boating still use the tiles.

const CSUB := 8                  # coast and water-mask pixels per tile
static var _land := PackedFloat32Array()   # blurred land, one value per tile center
static var _coast := {}          # Vector2i tile -> "sand" or "lawn", for tiles whose pixels follow the curve
## Natural ponds whose grassy banks follow a curve too. Man-made ones (Heron Lakes, the golf pond) keep their straight edges.
const NATURAL_PONDS := [1]
static var water_img: Image      # water color per tile (with a one-tile border), set by make_texture
static var water_tex: ImageTexture

## How much each spot is land, CSUB pixels per tile, for the shader to draw a smooth, anti-aliased shoreline.
static func make_coast_tex() -> ImageTexture:
	_build_coast()
	var img := Image.create(Town.MW, Town.MH, false, Image.FORMAT_L8)
	for y in Town.MH:
		for x in Town.MW:
			img.set_pixel(x, y, Color.BLACK if Town.is_water_t(Town.tile[Town.idx(x, y)]) else Color.WHITE)
	img.resize(Town.MW * CSUB, Town.MH * CSUB, Image.INTERPOLATE_NEAREST)
	for key in _coast:
		for j in CSUB:
			for i in CSUB:
				var f := clampf(land_at(Vector2(key.x + (i + 0.5) / CSUB, key.y + (j + 0.5) / CSUB)), 0.0, 1.0)
				img.set_pixel(key.x * CSUB + i, key.y * CSUB + j, Color(f, f, f))
	return ImageTexture.create_from_image(img)

static func _sandy(x: int, y: int) -> bool:
	var t := Town.t_at(x, y)
	if t == Town.T.SAND: return true
	return (t == Town.T.TREE or t == Town.T.BUSH) and under(x, y) == Town.T.SAND

static func _build_coast() -> void:
	if not _land.is_empty(): return
	var MW := Town.MW
	var MH := Town.MH
	var raw := PackedFloat32Array(); raw.resize(MW * MH)
	for i in MW * MH: raw[i] = 0.0 if Town.is_water_t(Town.tile[i]) else 1.0
	var wts := [0.054, 0.244, 0.403, 0.244, 0.054]   # gaussian, sigma about one tile
	var tmp := PackedFloat32Array(); tmp.resize(MW * MH)
	_land.resize(MW * MH)
	for y in MH:
		for x in MW:
			var v := 0.0
			for k in 5: v += wts[k] * raw[y * MW + clampi(x + k - 2, 0, MW - 1)]
			tmp[y * MW + x] = v
	for y in MH:
		for x in MW:
			var v := 0.0
			for k in 5: v += wts[k] * tmp[clampi(y + k - 2, 0, MH - 1) * MW + x]
			_land[y * MW + x] = v
	for y in MH:
		for x in MW:
			var t: int = Town.tile[Town.idx(x, y)]
			var wet := Town.is_water_t(t)
			var has_w := false
			var has_s := false
			var has_pond := false
			var has_lawn := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not Town.inb(x + dx, y + dy): continue
					if Town.is_water_t(Town.t_at(x + dx, y + dy)):
						has_w = true
						if Town.region[Town.idx(x + dx, y + dy)] in NATURAL_PONDS: has_pond = true
					elif _sandy(x + dx, y + dy): has_s = true
					elif is_lawn(x + dx, y + dy): has_lawn = true
			if (wet or t == Town.T.SAND) and has_w and has_s: _coast[Vector2i(x, y)] = "sand"
			elif has_pond and has_lawn and (t == Town.T.GRASS or (wet and Town.region[Town.idx(x, y)] in NATURAL_PONDS)):
				_coast[Vector2i(x, y)] = "lawn"

static func is_coast(x: int, y: int) -> bool:
	_build_coast()
	return _coast.has(Vector2i(x, y))

## How much a point (in tiles) is land, 0 to 1, with the coast at 0.5.
static func land_at(p: Vector2) -> float:
	_build_coast()
	var fx := clampf(p.x - 0.5, 0.0, Town.MW - 1.001)
	var fy := clampf(p.y - 0.5, 0.0, Town.MH - 1.001)
	var x0 := floori(fx)
	var y0 := floori(fy)
	var u := fx - x0
	var v := fy - y0
	var x1 := mini(x0 + 1, Town.MW - 1)
	var y1 := mini(y0 + 1, Town.MH - 1)
	var a := lerpf(_land[y0 * Town.MW + x0], _land[y0 * Town.MW + x1], u)
	var b := lerpf(_land[y1 * Town.MW + x0], _land[y1 * Town.MW + x1], u)
	# a gentle wobble so long shores aren't ruler-straight
	var w := sin(p.x * 1.7 + sin(p.y * 0.9) * 2.0) * 0.5 + sin(p.y * 2.3 + p.x * 0.6) * 0.5
	return lerpf(a, b, v) + w * 0.045

## "sand", "lawn" or "" for a tile that isn't on a curved coast.
static func coast_kind(x: int, y: int) -> String:
	_build_coast()
	return _coast.get(Vector2i(x, y), "")

## For a point on a coast tile: is it dry land? Elsewhere the tile decides.
static func dry_at(p: Vector2) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	if not is_coast(x, y): return not Town.is_water_t(Town.t_at(x, y))
	return land_at(p) >= 0.5

static func make_texture() -> ImageTexture:
	var MW := Town.MW
	var MH := Town.MH
	# 1. a flat color per tile
	var base := Image.create(MW, MH, false, Image.FORMAT_RGBA8)
	# masks must be the same size as the image they mask
	var gw := MW / 3 + 2
	var gh := MH / 3 + 2
	var wmask := Image.create(MW + 2, MH + 2, false, Image.FORMAT_RGBA8)
	var gmask := Image.create(gw * 3, gh * 3, false, Image.FORMAT_RGBA8)
	var water := Image.create(MW + 2, MH + 2, false, Image.FORMAT_RGBA8)
	water_img = water
	water.fill(Color("#74d6d4"))
	for y in MH:
		for x in MW:
			var t: int = Town.tile[Town.idx(x, y)]
			var c := base_color(x, y)
			if (t == Town.T.TREE or t == Town.T.BUSH) and not is_lawn(x, y):
				var u := under(x, y)
				c = Color("#e8dcc4") if u == Town.T.PLAZA else Color("#ecdcab") if u == Town.T.SAND else Color("#c4bfb3") if u == Town.T.CONC else Color("#8fc962")
			base.set_pixel(x, y, c)
			if Town.is_water_t(t):
				wmask.set_pixel(x + 1, y + 1, Color.WHITE)
				var pal := water_pal(x, y)
				var d: int = Town.depth[Town.idx(x, y)]
				var k := clampf((float(d if d > 0 else 9) - 1.0) / 4.5, 0.0, 1.0)
				water.set_pixel(x + 1, y + 1, Color(pal[0]).lerp(Color(pal[1]), k))
			elif is_lawn(x, y):
				gmask.set_pixel(x, y, Color.WHITE)
	# land next to the water borrows its neighbors' water color, so water drawn there by the coast blends in
	for y in MH:
		for x in MW:
			if Town.is_water_t(Town.tile[Town.idx(x, y)]) or not is_coast(x, y): continue
			var sum := Color(0, 0, 0, 0)
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if Town.inb(x + d.x, y + d.y) and Town.is_water_t(Town.t_at(x + d.x, y + d.y)):
					sum += water.get_pixel(x + d.x + 1, y + d.y + 1); n += 1
			if n > 0: water.set_pixel(x + 1, y + 1, sum / n)
	water_tex = ImageTexture.create_from_image(water)
	base.resize(MW * PX, MH * PX, Image.INTERPOLATE_NEAREST)
	wmask.resize((MW + 2) * PX, (MH + 2) * PX, Image.INTERPOLATE_NEAREST)
	gmask.resize(gw * 3 * PX, gh * 3 * PX, Image.INTERPOLATE_NEAREST)
	# 2. water colors interpolated smoothly between tile centers
	water.resize((MW + 2) * PX, (MH + 2) * PX, Image.INTERPOLATE_BILINEAR)
	base.blit_rect_mask(water, wmask, Rect2i(PX, PX, MW * PX, MH * PX), Vector2i.ZERO)
	# 3. big soft patches of light and dark lawn
	var grass := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	for y in gh:
		for x in gw:
			var h := Town.hash2(x * 11, y * 17)
			var h2 := Town.hash2(x + 99, y * 3)
			grass.set_pixel(x, y, Color8(int(110 + h * 26 - h2 * 10), int(168 + h * 24), int(78 + h2 * 24)))
	grass.resize(gw * 3 * PX, gh * 3 * PX, Image.INTERPOLATE_BILINEAR)
	base.blit_rect_mask(grass, gmask, Rect2i(0, 0, MW * PX, MH * PX), Vector2i.ZERO)
	# 4. smooth coastlines: sand and water swap pixels along the curve, with damp sand and a pale rim of shallows
	_build_coast()
	var sand := Color("#ecdcab")
	var damp := Color("#d6c08c")
	for key in _coast:
		var tx: int = key.x
		var ty: int = key.y
		var was_water := Town.is_water_t(Town.tile[Town.idx(tx, ty)])
		var lawn: bool = _coast[key] == "lawn"
		for j in PX:
			for i in PX:
				var f := land_at(Vector2(tx + (i + 0.5) / PX, ty + (j + 0.5) / PX))
				var px := tx * PX + i
				var py := ty * PX + j
				var rim := clampf(1.0 - (f - 0.5) / 0.09, 0.0, 1.0)
				if f >= 0.5 and lawn:
					# grass down to a muddy bank
					base.set_pixel(px, py, grass.get_pixel(px, py).lerp(Color("#6b7a44"), rim * 0.55))
				elif f >= 0.5:
					base.set_pixel(px, py, sand.lerp(damp, rim * 0.8))
				elif lawn:
					base.set_pixel(px, py, base.get_pixel(px, py) if was_water else water.get_pixel(px + PX, py + PX))
				else:
					var wc: Color = base.get_pixel(px, py) if was_water else water.get_pixel(px + PX, py + PX)
					base.set_pixel(px, py, wc.lerp(Color("#d9f4ea"), clampf(1.0 - (0.5 - f) / 0.06, 0.0, 1.0) * 0.45))
	return ImageTexture.create_from_image(base)

## A small texture that describes the water, for the water shader. One pixel per tile, sampled smoothly:
## red marks water, green is how far it is from shore (shallow to deep), blue marks the storm drain's murky water.
static func make_water_mask() -> ImageTexture:
	var img := Image.create(Town.MW, Town.MH, false, Image.FORMAT_RGBA8)
	for y in Town.MH:
		for x in Town.MW:
			var t: int = Town.tile[Town.idx(x, y)]
			if not Town.is_water_t(t):
				img.set_pixel(x, y, Color(0, 0, 0, 1)); continue
			var d: int = Town.depth[Town.idx(x, y)]
			var k := clampf((float(d if d > 0 else 9) - 1.0) / 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, k, 1.0 if t == Town.T.SWATER else 0.0, 1))
	# finer on the coasts, so the foam and the damp sand follow the curved shoreline
	img.resize(Town.MW * CSUB, Town.MH * CSUB, Image.INTERPOLATE_BILINEAR)
	_build_coast()
	for key in _coast:
		for j in CSUB:
			for i in CSUB:
				var px: int = key.x * CSUB + i
				var py: int = key.y * CSUB + j
				var f := land_at(Vector2(key.x + (i + 0.5) / CSUB, key.y + (j + 0.5) / CSUB))
				var c := img.get_pixel(px, py)
				c.r = clampf(0.5 + (0.5 - f) * 1.6, 0.0, 1.0)
				img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)

## What each tile's ground is made of, for the ground shader's surface texture. One pixel per tile, sampled sharply.
## 0 nothing, 1 lawn, 2 asphalt, 3 sidewalk and concrete, 4 sand, 5 water, 6 fairway, 7 dirt path, 8 plaza, 9 dock,
## 10 sand on a curved coast, 11 water on a curved coast, 12 lawn and 13 water on a curved pond bank
static func make_material_tex() -> ImageTexture:
	var T := Town.T
	var img := Image.create(Town.MW, Town.MH, false, Image.FORMAT_L8)
	for y in Town.MH:
		for x in Town.MW:
			var t: int = Town.tile[Town.idx(x, y)]
			if t == T.TREE or t == T.BUSH: t = Town.T.GRASS if is_lawn(x, y) else under(x, y)
			var m := 0
			match t:
				T.GRASS: m = 1
				T.ROAD, T.RUNWAY: m = 2
				T.WALK, T.CONC, T.DOOR, T.PGATE, T.HGATE, T.GATE, T.GAP, T.BLD: m = 3
				T.SAND: m = 4
				T.WATER, T.DEEP, T.SWATER, T.WARM: m = 5
				T.FAIR: m = 6
				T.PATH, T.HIDE: m = 7
				T.PLAZA: m = 8
				T.DOCK: m = 9
			img.set_pixel(x, y, Color8(m, m, m))
	# coast tiles: 10 sandy, 11 watery; the shader draws the curved shoreline across them
	_build_coast()
	for key in _coast:
		var m := 11 if Town.is_water_t(Town.tile[Town.idx(key.x, key.y)]) else 10
		if _coast[key] == "lawn": m += 2
		img.set_pixel(key.x, key.y, Color8(m, m, m))
	return ImageTexture.create_from_image(img)
