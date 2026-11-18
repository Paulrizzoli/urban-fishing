class_name Ironwater
## The second town: Ironwater, an old mill city on the Calder River, a long coach ride north of Port Mullet.
## The river comes out of Calder Reservoir over the Ironwater Dam, roars down the spillway into the tailwater,
## and runs south through town under three street bridges and the high I-90 viaduct.
## Built by Town.build() when the save is in Ironwater (Town.level == 1). Same map size as Port Mullet.
##
## Fishing spots (water regions): 20 Calder Reservoir, 21 the Spillway (tailwater), 22 Calder River,
## 23 the Mill Race, 24 the brewery cooling pond, 25 the ballpark splash pool, 26 Founders Park Pond.
## Guarded zones: 20 the boil below the dam gates, 21 the old woolen mill, 22 the brewery, 23 the ballpark.

const T := Town.T
const RES := 20
const SPILL := 21
const RIVER := 22
const RACE := 23
const BREW := 24
const SPLASH := 25
const FOUNDERS := 26

const ROOFS := ["#9a5a48", "#6f7f86", "#b5876a", "#7a8a6a", "#a86a5a", "#8c7c9c", "#c8a46a", "#6a8aa0"]

## The viaduct: x across the whole map, y0..y1. Under it the city carries on.
const VIA_Y0 := 92
const VIA_Y1 := 96
## The river's banks below the tailwater.
const RIVER_X0 := 48
const RIVER_X1 := 63

## The shore of the reservoir: water at or above this row.
static func shore(x: int) -> int:
	if x >= 27 and x <= 84: return 26
	var s := 15.0 + 3.0 * sin(x * 0.17 + 1.0) + 2.0 * sin(x * 0.07 + 0.4)
	# ease down to the dam at both ends
	if x < 27: s = lerpf(s, 26.0, clampf((x - 17) / 10.0, 0.0, 1.0))
	else: s = lerpf(s, 26.0, clampf((95 - x) / 10.0, 0.0, 1.0))
	return int(s)

## The tailwater's width: half the width of the river below the gates, in tiles.
static func tail_half(y: int) -> int:
	if y <= 44: return 12
	if y >= 52: return 8
	return 12 - int(round((y - 44) / 8.0 * 4.0))

static func build() -> void:
	# ---------- Calder Reservoir ----------
	for x in Town.MW:
		Town.rect(x, 0, x, shore(x), T.WATER, RES)
	# a lakeside park and boat ramp on the west shore, woods on the east
	Town.rect(16, 21, 17, 23, T.DOCK)
	Town.trees([[3, 24], [8, 27], [2, 30], [12, 29], [26, 30], [5, 21]])
	Town.bushes([[10, 23], [20, 27], [14, 25]])
	Town.decor.append({ "k": "bench", "x": 7.0, "y": 22.8 }); Town.decor.append({ "k": "bench", "x": 20.5, "y": 25.0 })
	for y in range(18, 32):
		for x in range(86, 112):
			if Town.tile[Town.idx(x, y)] != T.GRASS: continue
			if Town.hash2(x * 3, y * 7) < 0.3 and y < 30: Town.set_t(x, y, T.TREE if Town.hash2(y, x) < 0.5 else T.BUSH)
	Town.labels.append({ "t": "CALDER RESERVOIR", "x": 56.0, "y": 10.0 })
	Town.labels.append({ "t": "LAKESIDE PARK", "x": 10.0, "y": 26.4 })
	# ---------- the Ironwater Dam ----------
	Town.rect(27, 27, 84, 28, T.CONC)          # the crest walk: fish the reservoir off the top of the dam
	Town.rect(27, 29, 84, 30, T.WALL)          # the dam face, with the spillway gates in the middle
	Town.decor.append({ "k": "dam", "x0": 27, "x1": 84, "gx0": 44, "gx1": 67, "y": 29 })
	Town.labels.append({ "t": "IRONWATER DAM", "x": 36.0, "y": 27.6 })
	# ---------- the spillway and tailwater ----------
	for y in range(31, 53):
		var hw := tail_half(y)
		Town.rect(56 - hw, y, 55 + hw, y, T.WATER, SPILL if y <= 50 else RIVER)
	# the wing walls beside the boil, behind a fence: the best fishing on the river, and off limits
	Town.rect(38, 31, 43, 37, T.CONC); Town.rect(68, 31, 73, 37, T.CONC)
	Town.rect(37, 31, 37, 38, T.FENCE); Town.rect(37, 38, 43, 38, T.FENCE)
	Town.rect(74, 31, 74, 38, T.FENCE); Town.rect(68, 38, 74, 38, T.FENCE)
	Town.set_t(40, 38, T.GATE); Town.set_t(71, 38, T.GATE)
	Town.zrect(38, 31, 43, 37, 20); Town.zrect(68, 31, 73, 37, 20); Town.zrect(44, 31, 67, 37, 20)
	Town.zone[Town.idx(40, 38)] = 20; Town.zone[Town.idx(71, 38)] = 20
	Town.signs.append_array([Vector2(41.5, 39.4), Vector2(70.5, 39.4)])
	Town.labels.append({ "t": "THE SPILLWAY", "x": 56.0, "y": 41.5 })
	# ---------- Calder River, through town ----------
	Town.rect(RIVER_X0, 53, RIVER_X1, Town.MH - 1, T.WATER, RIVER)
	# river walks along both banks, all the way down
	for y in range(39, Town.MH):
		var hw := tail_half(y) if y < 53 else 8
		Town.set_t(56 - hw - 1, y, T.WALK); Town.set_t(56 + hw, y, T.WALK)
	# the public tailwater fishing pier
	Town.rect(45, 45, 48, 46, T.DOCK)
	Town.labels.append({ "t": "CALDER RIVER", "x": 56.0, "y": 140.0 })
	Town.labels.append({ "t": "TAILWATER PIER", "x": 46.5, "y": 44.0 })
	# ---------- streets ----------
	# Lakeshore Dr along the top, on both sides of the dam
	Town.rect(0, 33, 36, 34, T.ROAD); Town.rect(0, 32, 36, 32, T.WALK); Town.rect(0, 35, 36, 35, T.WALK)
	Town.rect(75, 33, 111, 34, T.ROAD); Town.rect(75, 32, 111, 32, T.WALK); Town.rect(75, 35, 111, 35, T.WALK)
	# River St (west bank) and Bank St (east bank)
	Town.rect(41, 39, 42, Town.MH - 1, T.ROAD); Town.rect(40, 39, 40, Town.MH - 1, T.WALK); Town.rect(43, 39, 43, Town.MH - 1, T.WALK)
	Town.rect(69, 39, 70, Town.MH - 1, T.ROAD); Town.rect(68, 39, 68, Town.MH - 1, T.WALK); Town.rect(71, 39, 71, Town.MH - 1, T.WALK)
	# 1st Ave and Bluff Ave
	Town.rect(12, 33, 13, Town.MH - 1, T.ROAD); Town.rect(11, 36, 11, Town.MH - 1, T.WALK); Town.rect(14, 36, 14, Town.MH - 1, T.WALK)
	Town.rect(98, 33, 99, Town.MH - 1, T.ROAD); Town.rect(97, 36, 97, Town.MH - 1, T.WALK); Town.rect(100, 36, 100, Town.MH - 1, T.WALK)
	# the cross streets, each with a low bridge over the river
	for row in [[57, "MILL ST"], [123, "MARKET ST"], [159, "FRONT ST"]]:
		var y0: int = row[0]
		Town.rect(0, y0, 111, y0, T.WALK); Town.rect(0, y0 + 1, 111, y0 + 2, T.ROAD); Town.rect(0, y0 + 3, 111, y0 + 3, T.WALK)
		Town.bridges.append({ "x0": RIVER_X0 - 1, "x1": RIVER_X1 + 1, "y0": y0, "y1": y0 + 3, "h": true })
	# the space between River St and the river walk is a strip of park, with trees and benches
	for y in range(53, Town.MH):
		for x in [44, 45, 46, 65, 66, 67]:
			if Town.tile[Town.idx(x, y)] != T.GRASS: continue
			if (y % 7 == 3) and (x == 45 or x == 66): Town.set_t(x, y, T.TREE)
	for y in [64, 80, 108, 132, 146, 168]:
		Town.decor.append({ "k": "bench", "x": 45.5, "y": y + 0.3 }); Town.decor.append({ "k": "bench", "x": 66.5, "y": y + 0.3 })
	# ---------- the I-90 viaduct, high over everything ----------
	Town.bridges.append({ "x0": 0, "x1": Town.MW - 1, "y0": VIA_Y0, "y1": VIA_Y1, "h": true, "high": true, "gx0": RIVER_X0, "gx1": RIVER_X1 + 1 })
	# its piers: two in the river, the rest on land between the streets
	for px in [6, 26, 34, 52, 59, 78, 88, 106]:
		Town.rect(px, VIA_Y0 + 1, px + 1, VIA_Y1 - 1, T.BLD, 0)
	Town.labels.append({ "t": "UNDER THE VIADUCT", "x": 56.0, "y": 98.4 })
	# ---------- west bank ----------
	_mill()
	_founders()
	_brewery()
	_station()
	# downtown west, between the viaduct and Market St
	Town.rect(15, 98, 39, 121, T.CONC)
	Town.sky(16, 99, 7, 6, "#8a6a5a", 12, "IRONWATER SAVINGS", { "ant": true })
	Town.sky(25, 100, 6, 5, "#6f7f86", 8)
	Town.sky(33, 99, 6, 6, "#a86a5a", 10, "", { "glass": true })
	Town.bld(16, 110, 10, 5, "#c8a46a", "flat", "CALDER HOTEL")
	Town.bld(28, 109, 10, 6, "#9a5a48", "flat", "RIVERVIEW MOTOR INN", { "motel": true, "home": true }); Town.set_t(32, 114, T.DOOR)
	Town.decor.append({ "k": "parking", "x0": 16, "y0": 117, "x1": 37, "y1": 120 })
	# under the viaduct on the west side: a park-and-ride lot
	Town.rect(15, 92, 39, 96, T.CONC)
	Town.decor.append({ "k": "parking", "x0": 16, "y0": 92, "x1": 25, "y1": 94 })
	# ---------- east bank ----------
	_visitor_center()
	_ballpark()
	# downtown east
	Town.rect(72, 98, 96, 121, T.CONC)
	Town.bld(73, 99, 9, 6, "#e8e0cc", "flat", "CITY HALL")
	Town.sky(84, 99, 6, 6, "#6a8aa0", 13, "CALDER TOWER", { "glass": true, "ant": true })
	Town.sky(91, 100, 5, 5, "#8c7c9c", 7)
	Town.bld(73, 110, 7, 5, "#b5876a", "flat", "DINER")
	Town.bld(82, 110, 14, 6, "#7a8a6a", "flat", "IRONWATER PUBLIC MARKET")
	Town.decor.append({ "k": "parking", "x0": 73, "y0": 117, "x1": 95, "y1": 120 })
	Town.rect(72, 92, 96, 96, T.CONC)
	Town.decor.append({ "k": "parking", "x0": 80, "y0": 92, "x1": 87, "y1": 94 })
	# old town row houses east of Bank St, south of Market St
	for y in [128, 134, 140, 146, 152]:
		for x in [73, 79, 85, 91]: Town.bld(x, y, 4, 3, ROOFS[(x + y) % 8])
	for y in [164, 170, 176]:
		for x in [73, 79, 85, 91]: Town.bld(x, y, 4, 3, ROOFS[(x * 3 + y) % 8])
	# houses on the outside streets
	for y in range(38, Town.MH - 4, 6):
		if y >= VIA_Y0 - 3 and y <= VIA_Y1 + 1: continue
		if abs(y - 58) < 4 or abs(y - 124) < 4 or abs(y - 160) < 4: continue
		Town.bld(3, y, 5, 3, ROOFS[(y * 5) % 8])
		Town.bld(103, y, 5, 3, ROOFS[(y * 7 + 3) % 8])
	# lamps along the river walks and streets
	for y in range(40, Town.MH, 8):
		if y >= VIA_Y0 - 1 and y <= VIA_Y1 + 1: continue
		Town.lamps.append(Vector2(43.5, y + 0.5)); Town.lamps.append(Vector2(68.5, y + 4.5))
		Town.lamps.append(Vector2(14.5, y + 2.5)); Town.lamps.append(Vector2(97.5, y + 6.5))
	for x in range(3, Town.MW, 9):
		Town.lamps.append(Vector2(x + 0.5, 32.5))
		for y0 in [57, 123, 159]: Town.lamps.append(Vector2(x + 4.5, y0 + 0.5))
	Town.lamps.append_array([Vector2(45.5, 44.6), Vector2(48.5, 44.6), Vector2(30.5, 27.3), Vector2(81.5, 27.3), Vector2(56.5, 27.3)])
	Town.lamps = Town.lamps.filter(func(l): var t := Town.t_at(floori(l.x), floori(l.y)); return not Town.is_water_t(t) and t != T.BLD and t != T.FENCE)
	Town.launch_k = [RES, SPILL, RIVER]
	Town.launch_s = [RES, RIVER]

## The old Halvorsen Woolen Mill, with the stone mill race running through it from the reservoir.
static func _mill() -> void:
	# the race comes out of the reservoir through a sluice, under Lakeshore Dr and into the mill
	Town.rect(24, shore(24) + 1, 26, 54, T.WATER, RACE)
	Town.rect(24, shore(24) + 1, 26, shore(24) + 1, T.WALL)
	Town.rect(24, 32, 26, 32, T.WALK); Town.rect(24, 33, 26, 34, T.ROAD); Town.rect(24, 35, 26, 35, T.WALK)
	Town.bridges.append({ "x0": 24, "x1": 26, "y0": 32, "y1": 35, "h": true })
	Town.rect(15, 37, 39, 37, T.FENCE); Town.rect(15, 55, 39, 55, T.FENCE); Town.rect(15, 37, 15, 55, T.FENCE); Town.rect(39, 37, 39, 55, T.FENCE)
	for x in range(24, 27): Town.set_t(x, 37, T.WATER); Town.set_t(x, 55, T.WATER)
	Town.rect(24, 55, 26, 56, T.WATER, RACE)
	Town.set_t(32, 55, T.GAP); Town.set_t(18, 37, T.GATE)
	Town.bld(28, 39, 10, 8, "#9a5a48", "flat", "HALVORSEN WOOLEN MILL", { "mill": true })
	Town.bld(16, 43, 6, 5, "#a86a5a", "flat", "", { "mill": true })
	Town.bld(28, 49, 7, 4, "#8a5a48", "flat", "", { "mill": true })
	Town.rect(16, 50, 22, 53, T.CONC)
	Town.decor.append({ "k": "wheel", "x": 27.0, "y": 43.0 })
	Town.bushes([[17, 39], [22, 39], [36, 53], [37, 48], [19, 54]])
	Town.trees([[16, 39], [38, 39]])
	Town.zrect(16, 38, 38, 54, 21); Town.zone[Town.idx(32, 55)] = 21; Town.zone[Town.idx(18, 37)] = 21
	Town.signs.append_array([Vector2(33.5, 56.4), Vector2(19.5, 36.4)])
	Town.labels.append({ "t": "THE MILL RACE", "x": 25.0, "y": 48.6 })

## Founders Park: a public pond next to Calder River Outfitters, open to everyone.
static func _founders() -> void:
	Town.blob(26, 72, 8.5, 5.0, T.WATER, 2.1, FOUNDERS)
	Town.trees([[17, 64], [35, 64], [16, 80], [36, 81], [26, 81]])
	Town.bushes([[20, 64], [32, 64]])
	Town.decor.append({ "k": "bench", "x": 22.0, "y": 79.6 }); Town.decor.append({ "k": "bench", "x": 30.5, "y": 64.2 })
	Town.labels.append({ "t": "FOUNDERS PARK POND", "x": 26.0, "y": 65.0 })
	# the outfitters and its lot, on River St
	Town.rect(24, 83, 39, 90, T.CONC)
	Town.bld(29, 83, 9, 5, "#3d6e5a", "shop", "CALDER RIVER OUTFITTERS"); Town.set_t(33, 87, T.DOOR)
	Town.decor.append({ "k": "parking", "x0": 25, "y0": 88, "x1": 38, "y1": 90 })

## Calder Brewing Co. and its cooling pond, where the carp eat spent grain and get enormous.
static func _brewery() -> void:
	Town.rect(15, 128, 39, 154, T.CONC)
	Town.rect(15, 127, 39, 127, T.FENCE); Town.rect(15, 155, 39, 155, T.FENCE); Town.rect(15, 127, 15, 155, T.FENCE); Town.rect(39, 127, 39, 155, T.FENCE)
	Town.set_t(39, 136, T.GATE); Town.set_t(15, 150, T.GAP)
	Town.bld(16, 129, 13, 7, "#8a4a3a", "flat", "CALDER BREWING CO.", { "brew": true })
	Town.bld(31, 129, 7, 5, "#b5876a", "flat", "TAPROOM")
	Town.ell(27, 146, 7.2, 4.4, T.WATER, BREW)
	Town.rect(16, 138, 22, 141, T.GRASS)
	Town.bushes([[16, 142], [17, 142], [37, 141], [37, 152], [16, 152], [17, 153]])
	Town.trees([[36, 138], [18, 139]])
	Town.zrect(16, 128, 38, 154, 22); Town.zone[Town.idx(39, 136)] = 22; Town.zone[Town.idx(15, 150)] = 22
	Town.signs.append_array([Vector2(40.5, 137.4), Vector2(27, 140.8)])
	Town.labels.append({ "t": "COOLING POND", "x": 27.0, "y": 140.4 })

## Ironwater Station, where the coach from Port Mullet pulls in.
static func _station() -> void:
	Town.rect(15, 164, 39, 183, T.CONC)
	Town.bld(18, 165, 14, 6, "#9a6a4a", "flat", "IRONWATER STATION")
	Town.decor.append({ "k": "parking", "x0": 33, "y0": 165, "x1": 38, "y1": 169 })
	Town.rect(15, 172, 39, 172, T.WALK)

## The dam visitor center on the east bank, where the river authority ranger works.
static func _visitor_center() -> void:
	Town.rect(76, 40, 95, 55, T.GRASS)
	Town.bld(80, 41, 10, 5, "#d8d2c4", "flat", "DAM VISITOR CENTER")
	Town.rect(78, 47, 92, 49, T.CONC)
	Town.decor.append({ "k": "parking", "x0": 79, "y0": 47, "x1": 91, "y1": 49 })
	Town.trees([[77, 52], [94, 52], [86, 53], [94, 42]])
	Town.bushes([[78, 41], [92, 44]])

## Riverhawks Field: a minor-league ballpark with a home-run splash pool past center field.
static func _ballpark() -> void:
	Town.rect(72, 61, 96, 61, T.FENCE); Town.rect(72, 90, 96, 90, T.FENCE); Town.rect(72, 61, 72, 90, T.FENCE); Town.rect(96, 61, 96, 90, T.FENCE)
	Town.rect(73, 62, 95, 89, T.FAIR)
	Town.set_t(84, 90, T.GATE); Town.set_t(72, 70, T.GAP)
	# the splash pool beyond the outfield wall, along the top
	Town.rect(76, 63, 92, 66, T.WATER, SPLASH)
	# the stands along the bottom, with the press box
	Town.bld(74, 85, 9, 4, "#6a8aa0", "flat", "", { "stands": true }); Town.bld(86, 85, 9, 4, "#6a8aa0", "flat", "", { "stands": true })
	Town.decor.append({ "k": "diamond", "x": 84.5, "y": 79.0 })
	Town.bushes([[73, 63], [94, 63], [73, 67], [95, 68]])
	Town.zrect(73, 62, 95, 89, 23); Town.zone[Town.idx(84, 90)] = 23; Town.zone[Town.idx(72, 70)] = 23
	Town.signs.append(Vector2(84.5, 91.4))
	Town.labels.append({ "t": "RIVERHAWKS FIELD", "x": 84.5, "y": 70.0 })
	Town.labels.append({ "t": "SPLASH POOL", "x": 84.0, "y": 67.6 })

# ---------- drawing ----------

## The dam: a pale concrete face with the crest railings, the spillway gates between their piers, and the
## river pouring through them in white sheets. Drawn on the ground, under people and boats.
static func draw_dam(ci: CanvasItem, view: Rect2, t: float) -> void:
	if not view.intersects(Rect2(26, 26, 60, 14)): return
	var conc := Color("#c9c3b4")
	var conc_dk := Color("#a8a293")
	# the face below the crest
	ci.draw_rect(Rect2(27, 29, 58, 2), conc_dk)
	ci.draw_rect(Rect2(27, 29, 58, 0.25), Color("#ddd7c8"))
	for x in range(27, 85, 3): ci.draw_line(Vector2(x, 29.3), Vector2(x, 31), Color(0, 0, 0, 0.08), 0.04)
	# crest railings, both sides of the walk
	for yy in [27.0, 28.86]:
		ci.draw_rect(Rect2(27, yy, 58, 0.14), Color("#8b9196"))
		var k := 27.25
		while k < 85: ci.draw_rect(Rect2(k, yy - 0.04, 0.07, 0.2), Color("#6c7178")); k += 0.75
	# the gates: piers every four tiles, steel gates hung between, water pouring under
	var gx0 := 44.0
	var gx1 := 68.0
	var x := gx0
	while x < gx1 - 0.1:
		# the water coming under the gate, white and churning
		var gw := Rect2(x + 0.55, 29.15, 2.9, 1.85)
		ci.draw_rect(gw, Color("#dfeff2"))
		for j in 7:
			var sx := x + 0.7 + j * 0.42
			var ph := fmod(t * 2.6 + j * 0.37 + x * 0.21, 1.0)
			ci.draw_line(Vector2(sx, 29.2 + ph * 1.6), Vector2(sx + 0.05, 29.55 + ph * 1.6), Color(1, 1, 1, 0.9 * (1.0 - ph)), 0.12)
			ci.draw_line(Vector2(sx + 0.2, 29.3 + fmod(ph + 0.5, 1.0) * 1.5), Vector2(sx + 0.22, 29.6 + fmod(ph + 0.5, 1.0) * 1.5), Color("#a8cfd8", 0.8), 0.07)
		# the gate itself, raised a little, with its hoist on the crest
		ci.draw_rect(Rect2(x + 0.5, 28.95, 3.0, 0.32), Color("#3e6f7c"))
		ci.draw_rect(Rect2(x + 0.5, 28.95, 3.0, 0.07), Color("#5f93a0"))
		ci.draw_rect(Rect2(x + 1.6, 27.35, 0.8, 0.5), Color("#2b4f5a"))
		# the pier on the left of the gate
		ci.draw_rect(Rect2(x - 0.05, 28.8, 0.6, 2.25), conc)
		ci.draw_rect(Rect2(x + 0.4, 28.8, 0.15, 2.25), conc_dk)
		x += 4.0
	ci.draw_rect(Rect2(gx1 - 0.05, 28.8, 0.6, 2.25), conc)
	# a line of buoys across the tailwater, below the restricted boil
	for bx in range(44, 68, 2):
		var bob := sin(t * 2.0 + bx) * 0.05
		ci.draw_circle(Vector2(bx + 0.5, 38.5 + bob), 0.17, Color("#f2f2ee"))
		ci.draw_circle(Vector2(bx + 0.5, 38.5 + bob), 0.09, Color("#e2583e"))
	ci.draw_line(Vector2(44, 38.5), Vector2(68, 38.5), Color(1, 1, 1, 0.25), 0.03)

## Foam in the boil below the gates, fading down the tailwater, and slow current lines down the river.
static func draw_water(ci: CanvasItem, view: Rect2, t: float) -> void:
	# the boil: white water churning out from under the gates
	if view.intersects(Rect2(42, 30, 28, 22)):
		# a bright churned band right under the gates, fading out downstream
		var n := 48
		for j in n:
			var xa := 44.0 + j * 0.5
			var w := 0.5 + 0.5 * sin(t * 3.1 + j * 0.9) * sin(t * 1.7 + j * 0.4)
			var top := Color(1, 1, 1, 0.62)
			var bot := Color(1, 1, 1, 0.0)
			var yb := 33.2 + w * 1.2
			ci.draw_polygon(PackedVector2Array([Vector2(xa, 31.0), Vector2(xa + 0.5, 31.0), Vector2(xa + 0.5, yb), Vector2(xa, yb)]), PackedColorArray([top, top, bot, bot]))
		# foam patches boiling up and drifting off down the tailwater
		for i in 220:
			var h1 := Town.hash2(i, 7)
			var h2 := Town.hash2(i * 3, 11)
			var h3 := Town.hash2(i * 7, 5)
			var life := 2.2 + h2 * 2.4
			var k := fmod(t / life + h1, 1.0)
			var y := 31.3 + pow(k, 0.75) * (6.0 + h2 * 12.0)
			var hw := float(tail_half(int(y)))
			var x := clampf(44.3 + h3 * 23.4 + (h2 - 0.5) * k * 2.5, 56.0 - hw + 0.3, 56.0 + hw - 0.3)
			var a := sin(k * PI) * (0.55 if y < 37.0 else 0.3)
			var r := (0.12 + h1 * 0.22) * (1.0 + (1.0 - k) * 0.6)
			Art.ellipse(ci, Vector2(x, y), r * 1.8, r * 0.55, Color(1, 1, 1, a))
			if i % 3 == 0: ci.draw_circle(Vector2(x + r * 1.4, y - r * 0.3), r * 0.3, Color(1, 1, 1, a * 0.8))
	# the current: thin streaks drifting down the river
	var y0 := maxf(40.0, view.position.y)
	var y1 := minf(float(Town.MH), view.end.y)
	if y1 <= y0: return
	for i in 60:
		var h1 := Town.hash2(i, 3)
		var h2 := Town.hash2(i * 5, 9)
		var span := float(Town.MH) - 40.0
		var y := 40.0 + fposmod(h2 * span + t * (0.9 + h1 * 0.6), span)
		if y < y0 or y > y1: continue
		var hw := float(tail_half(int(y))) if y < 53 else 8.0
		var x := 56.0 - hw + 0.6 + h1 * (hw * 2.0 - 1.2)
		if not Town.is_water_t(Town.t_at(floori(x), floori(y))) or Bridges.covered(Vector2(x, y)) >= 0: continue
		ci.draw_line(Vector2(x, y), Vector2(x + 0.04, y + 0.9 + h2 * 0.6), Color(1, 1, 1, 0.14), 0.05)

## The old waterwheel turning in the mill race.
static func draw_wheel(ci: CanvasItem, p: Vector2, t: float) -> void:
	var c := p + Vector2(-0.6, -0.4)
	var a := -t * 0.9
	Art.ellipse(ci, p + Vector2(-0.6, 1.1), 1.4, 0.35, Color(0, 0, 0, 0.2))
	ci.draw_rect(Rect2(p.x - 0.05, p.y - 1.4, 0.3, 2.4), Color("#5a4632"))   # the frame against the mill wall
	ci.draw_arc(c, 1.3, 0, TAU, 32, Color("#6b5034"), 0.16)
	ci.draw_arc(c, 0.9, 0, TAU, 28, Color("#7a5a3a"), 0.08)
	for i in 10:
		var d := Vector2.from_angle(a + i * TAU / 10)
		ci.draw_line(c, c + d * 1.3, Color("#6b5034"), 0.07)
		var tip := c + d * 1.3
		ci.draw_line(tip - d.orthogonal() * 0.22, tip + d.orthogonal() * 0.22, Color("#4a3624"), 0.14)
	ci.draw_circle(c, 0.18, Color("#3a2a1e"))
	# water spilling off the bottom paddles
	for j in 4:
		var k := fmod(t * 1.5 + j * 0.25, 1.0)
		ci.draw_circle(c + Vector2(0.3 + j * 0.25, 1.2 + k * 0.4), 0.07 * (1.0 - k), Color(1, 1, 1, 0.7 * (1.0 - k)))

## Ground details drawn once: the ballpark diamond and the rail tracks behind the station.
static func draw_ground(ci: CanvasItem) -> void:
	# Riverhawks Field: dirt infield, grass inside, bases, the mound and the foul lines
	var hp := Vector2(84.5, 83.0)   # home plate
	var s := 4.2
	var d := [hp, hp + Vector2(s, -s), hp + Vector2(0, -2 * s), hp + Vector2(-s, -s)]
	var dirt := Color("#c99a62")
	ci.draw_colored_polygon(PackedVector2Array([hp + Vector2(0, 0.9), hp + Vector2(s + 1.1, -s), hp + Vector2(0, -2 * s - 1.1), hp + Vector2(-s - 1.1, -s)]), dirt)
	ci.draw_colored_polygon(PackedVector2Array([hp + Vector2(0, -0.6), hp + Vector2(s - 0.6, -s), hp + Vector2(0, -2 * s + 0.6), hp + Vector2(-s + 0.6, -s)]), Color("#86c25c"))
	Art.ellipse(ci, hp + Vector2(0, -s), 0.6, 0.45, dirt)
	ci.draw_rect(Rect2(hp + Vector2(-0.12, -s - 0.05), Vector2(0.24, 0.08)), Color.WHITE)
	for b in d.slice(1): ci.draw_rect(Rect2(b - Vector2(0.18, 0.18), Vector2(0.36, 0.36)), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([hp + Vector2(-0.2, -0.1), hp + Vector2(0.2, -0.1), hp + Vector2(0.2, 0.1), hp + Vector2(0, 0.25), hp + Vector2(-0.2, 0.1)]), Color.WHITE)
	ci.draw_line(hp, hp + Vector2(10, -10), Color(1, 1, 1, 0.8), 0.07)
	ci.draw_line(hp, hp + Vector2(-10, -10), Color(1, 1, 1, 0.8), 0.07)
	# the outfield wall, in front of the splash pool
	ci.draw_rect(Rect2(74, 67.0, 21, 0.35), Color("#2b5a3a"))
	Art.text(ci, Vector2(84.5, 67.25), "410", 0.28, Color.WHITE)
	# the tracks behind Ironwater Station
	for ty in [176.0, 179.0]:
		for x in range(15, 40):
			ci.draw_rect(Rect2(x + 0.1, ty - 0.1, 0.25, 0.9), Color("#6b5034"))
			ci.draw_rect(Rect2(x + 0.6, ty - 0.1, 0.25, 0.9), Color("#6b5034"))
		ci.draw_rect(Rect2(15, ty, 25, 0.08), Color("#8b9196")); ci.draw_rect(Rect2(15, ty + 0.62, 25, 0.08), Color("#8b9196"))
	# the coach bay at the station
	ci.draw_rect(Rect2(20, 172.85, 12, 0.08), Color("#e8c84a"))
