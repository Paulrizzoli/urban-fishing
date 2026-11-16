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
	return ImageTexture.create_from_image(base)

## A small texture that marks the water, for the shimmer shader. One pixel per tile, sampled smoothly.
static func make_water_mask() -> ImageTexture:
	var img := Image.create(Town.MW, Town.MH, false, Image.FORMAT_L8)
	for y in Town.MH:
		for x in Town.MW:
			var t: int = Town.tile[Town.idx(x, y)]
			var v := 0.0
			if t == Town.T.WATER or t == Town.T.WARM or t == Town.T.DEEP: v = 1.0
			elif t == Town.T.SWATER: v = 0.35
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)
