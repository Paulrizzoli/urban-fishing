class_name Town
## The map of Port Mullet: tile types, water regions, private zones, buildings and street furniture.
## Built once at startup, ported from the browser version's buildTown().

const MW := 112
const MH := 184

enum T { GRASS, ROAD, WALK, WATER, BLD, FENCE, BUSH, FAIR, SAND, CONC, SFLOOR, SWATER, WALL, WARM, TREE, GATE, GRATE, PATH, DOOR, GAP, DOCK, HWALL, PGATE, HGATE, HIDE, RUNWAY, DEEP, PLAZA }

const BLOCK := [T.BLD, T.FENCE, T.HWALL, T.WALL, T.TREE, T.WATER, T.SWATER, T.WARM, T.DEEP]
const WATERS := [T.WATER, T.SWATER, T.WARM, T.DEEP]
const ROOFS := ["#e98a7b", "#5bb5a9", "#f1d9a8", "#9fd3c7", "#f3a6a0", "#c9b6e4", "#f6c86d", "#8cc0de"]

static var tile := PackedByteArray()
static var region := PackedByteArray()
static var zone := PackedByteArray()
static var floodable := PackedByteArray()
static var depth := PackedByteArray()
static var buildings: Array = []
static var labels: Array = []
static var signs: Array = []
static var lamps: Array = []
static var decor: Array = []
static var bridges: Array = []
static var driveways: Array = []   # { r: Rect2, d: Vector2i toward the street, car: bool }
static var built := false

static func idx(x: int, y: int) -> int: return y * MW + x
static func inb(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < MW and y < MH
static func t_at(x: int, y: int) -> int: return tile[idx(x, y)] if inb(x, y) else T.WALL
static func is_water_t(t: int) -> bool: return t == T.WATER or t == T.SWATER or t == T.WARM or t == T.DEEP

static func hash2(x: int, y: int) -> float:
	var h: int = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFFFF) / 4294967296.0

static func rect(x0: int, y0: int, x1: int, y1: int, t: int, reg: int = -1) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if inb(x, y):
				tile[idx(x, y)] = t
				if reg >= 0: region[idx(x, y)] = reg

static func ell(cx: float, cy: float, rx: float, ry: float, t: int, reg: int = -1) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and inb(x, y):
				tile[idx(x, y)] = t
				if reg >= 0: region[idx(x, y)] = reg

## An ellipse with a wobbly edge, for natural shapes like islands. seed picks the wobble.
static func blob(cx: float, cy: float, rx: float, ry: float, t: int, seed: float, reg: int = -1) -> void:
	for y in range(floori(cy - ry * 1.3), ceili(cy + ry * 1.3) + 1):
		for x in range(floori(cx - rx * 1.3), ceili(cx + rx * 1.3) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var a := atan2(dy, dx)
			var r := 1.0 + 0.1 * sin(2.0 * a + seed) + 0.07 * sin(3.0 * a + seed * 2.3) + 0.05 * sin(5.0 * a + seed * 0.7)
			if dx * dx + dy * dy <= r * r and inb(x, y):
				tile[idx(x, y)] = t
				if reg >= 0: region[idx(x, y)] = reg

static func zrect(x0: int, y0: int, x1: int, y1: int, z: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if inb(x, y): zone[idx(x, y)] = z

static func set_t(x: int, y: int, t: int) -> void: tile[idx(x, y)] = t

static func bld(x: int, y: int, w: int, h: int, color: String, kind := "house", label := "", extra := {}) -> Dictionary:
	rect(x, y, x + w - 1, y + h - 1, T.BLD)
	var b := { "x": x, "y": y, "w": w, "h": h, "color": color, "kind": kind, "label": label }
	b.merge(extra, true)
	buildings.append(b)
	return b

static func sky(x: int, y: int, w: int, h: int, color: String, ht: int, label := "", extra := {}) -> Dictionary:
	var e := { "ht": ht }
	e.merge(extra, true)
	return bld(x, y, w, h, color, "sky", label, e)

static func trees(pts: Array) -> void:
	for p in pts: set_t(p[0], p[1], T.TREE)

static func bushes(pts: Array) -> void:
	for p in pts: set_t(p[0], p[1], T.BUSH)

static func build() -> void:
	if built: return
	built = true
	var n := MW * MH
	tile.resize(n); region.resize(n); zone.resize(n); floodable.resize(n); depth.resize(n)
	tile.fill(T.GRASS); region.fill(0); zone.fill(0); floodable.fill(0); depth.fill(0)
	# canal and banks
	rect(0, 50, 111, 54, T.WATER, 2); rect(0, 49, 111, 49, T.WALK); rect(0, 55, 111, 55, T.WALK)
	rect(12, 50, 13, 51, T.DOCK); rect(28, 50, 29, 51, T.DOCK); rect(80, 53, 81, 54, T.DOCK); rect(101, 53, 102, 54, T.DOCK)
	# US-1
	rect(0, 34, 111, 36, T.ROAD); rect(0, 33, 111, 33, T.WALK); rect(0, 37, 111, 37, T.WALK)
	# Canal Rd with its bridge
	rect(40, 0, 42, 115, T.ROAD); rect(39, 0, 39, 115, T.WALK); rect(43, 0, 43, 115, T.WALK)
	bridges.append({ "x0": 39, "x1": 43, "y0": 50, "y1": 54 })
	# Plant Rd with its bridge
	rect(58, 37, 60, 84, T.ROAD); rect(57, 37, 57, 81, T.WALK); rect(61, 37, 61, 81, T.WALK)
	bridges.append({ "x0": 57, "x1": 61, "y0": 50, "y1": 54 })
	# NW neighborhood
	rect(0, 12, 38, 13, T.ROAD); rect(20, 0, 21, 32, T.ROAD)
	for x in [2, 8, 14, 24, 30]:
		bld(x, 2, 4, 3, ROOFS[(x * 3) % 8]); bld(x, 7, 4, 3, ROOFS[(x * 5 + 1) % 8])
	for x in [24, 30]:
		bld(x, 16, 4, 3, ROOFS[(x + 2) % 8]); bld(x, 22, 4, 3, ROOFS[(x + 5) % 8])
	for x in [2, 8, 14, 24, 30]: bld(x, 28, 4, 3, ROOFS[(x * 7 + 3) % 8])
	blob(10, 20.5, 6.2, 3.8, T.WATER, 0.5, 1)   # a natural pond, so a soft, uneven shape
	trees([[2, 16], [17, 16], [2, 25], [18, 24], [9, 26]]); bushes([[4, 16], [15, 25], [16, 17]])
	decor.append({ "k": "bench", "x": 12.0, "y": 25.3 }); decor.append({ "k": "bench", "x": 7.0, "y": 15.6 })
	labels.append({ "t": "MAPLE PARK POND", "x": 10.0, "y": 15.2 })
	# Lou's
	rect(44, 32, 56, 32, T.CONC); rect(54, 27, 60, 31, T.CONC)
	bld(45, 27, 8, 5, "#e2583e", "shop", "LOU'S BAIT & TACKLE"); set_t(48, 31, T.DOOR)
	decor.append({ "k": "parking", "x0": 54, "y0": 27, "x1": 60, "y1": 31 })
	# golf course
	rect(63, 1, 110, 31, T.FAIR)
	rect(62, 0, 62, 32, T.FENCE); rect(62, 32, 111, 32, T.FENCE); rect(62, 0, 111, 0, T.FENCE); rect(111, 0, 111, 32, T.FENCE)
	set_t(70, 32, T.GATE); set_t(104, 32, T.GAP)
	rect(102, 30, 103, 31, T.BUSH); rect(105, 30, 106, 31, T.BUSH); rect(103, 29, 105, 29, T.BUSH)
	bld(64, 25, 8, 5, "#f1e4c8", "club", "PELICAN POINT GOLF CLUB")
	ell(88, 14, 8.4, 5.2, T.WATER, 3)
	rect(77, 7, 99, 7, T.PATH); rect(77, 21, 99, 21, T.PATH); rect(77, 7, 77, 21, T.PATH); rect(99, 7, 99, 21, T.PATH); rect(72, 27, 77, 27, T.PATH); rect(77, 22, 77, 27, T.PATH); rect(70, 31, 70, 31, T.PATH)
	ell(70, 8, 2.6, 1.6, T.SAND); ell(104, 23, 2.2, 1.5, T.SAND); ell(83, 26, 2, 1.2, T.SAND)
	trees([[66, 5], [67, 14], [108, 14], [108, 25], [82, 29], [95, 27], [74, 18], [102, 4]])
	decor.append({ "k": "green", "x": 104.0, "y": 7.0 }); decor.append({ "k": "green", "x": 68.0, "y": 18.0 })
	zrect(63, 1, 110, 31, 1); zone[idx(70, 32)] = 1; zone[idx(104, 32)] = 1
	signs.append_array([Vector2(70.5, 33.4), Vector2(80.5, 9.6), Vector2(96.5, 18.4)])
	# office park
	rect(0, 39, 36, 47, T.CONC)
	bld(1, 39, 9, 5, "#5bb5a9", "office", "SUNRISE EXECUTIVE PARK"); bld(27, 39, 9, 5, "#f1e4c8", "office")
	ell(18, 43.5, 3.8, 2.3, T.WATER, 4)
	bushes([[12, 40], [24, 40], [12, 47], [24, 47], [14, 47], [22, 47]]); trees([[11, 43], [25, 43]])
	decor.append({ "k": "parking", "x0": 1, "y0": 45, "x1": 10, "y1": 47 }); decor.append({ "k": "parking", "x0": 27, "y0": 45, "x1": 35, "y1": 47 })
	zrect(0, 38, 36, 48, 2)
	signs.append(Vector2(18, 40.6))
	# Low Street floods on the king tide
	rect(0, 63, 36, 64, T.ROAD); rect(0, 62, 36, 62, T.WALK); rect(0, 65, 36, 65, T.WALK)
	for y in range(62, 66):
		for x in range(0, 37): floodable[idx(x, y)] = 1
	for x in [2, 8, 14, 20, 26, 32]:
		bld(x, 57, 4, 3, ROOFS[(x + 3) % 8]); bld(x, 68, 4, 3, ROOFS[(x * 3 + 2) % 8])
	labels.append({ "t": "LOW STREET", "x": 18.0, "y": 61.2 })
	# storm drain
	rect(44, 56, 56, 56, T.CONC)
	rect(44, 57, 56, 74, T.WALL); rect(45, 58, 55, 73, T.SFLOOR)
	rect(49, 59, 51, 72, T.SWATER, 5); rect(49, 65, 51, 65, T.SFLOOR); rect(45, 69, 47, 71, T.SWATER, 5)
	set_t(46, 57, T.GRATE)
	zrect(45, 57, 55, 73, 4)
	labels.append({ "t": "STORM DRAIN", "x": 50.5, "y": 56.6 })
	# power station
	rect(63, 57, 105, 74, T.CONC)
	rect(62, 56, 62, 75, T.FENCE); rect(62, 56, 106, 56, T.FENCE); rect(106, 56, 106, 75, T.FENCE); rect(62, 75, 106, 75, T.FENCE)
	set_t(62, 66, T.GATE); set_t(106, 72, T.GAP)
	bld(66, 59, 12, 8, "#9aa6ad", "plant", "TRI-COUNTY POWER STATION"); bld(81, 70, 5, 4, "#b8c1c6", "plant")
	ell(71.5, 71.2, 3.4, 2.8, T.BLD); buildings.append({ "x": 68, "y": 68, "w": 7, "h": 6, "kind": "tower", "color": "#9aa6ad", "label": "" })
	ell(95, 65, 8.2, 4.4, T.WARM, 6); rect(93, 57, 96, 61, T.WARM, 6)
	rect(107, 56, 111, 75, T.SAND)
	for y in range(57, 76):
		for x in range(107, 112):
			if (x == 107 or x >= 110 or hash2(x, y) < 0.35) and not (x == 108 and y > 57) and not (x == 107 and y == 72):
				set_t(x, y, T.TREE if hash2(y, x) < 0.25 else T.BUSH)
	rect(108, 56, 109, 75, T.SAND); set_t(107, 72, T.SAND)
	zrect(63, 57, 105, 74, 3); zone[idx(62, 66)] = 3; zone[idx(106, 72)] = 3
	signs.append_array([Vector2(61.5, 64.6), Vector2(90.5, 61.6), Vector2(94.5, 55.4)])
	labels.append({ "t": "MULLET CANAL", "x": 22.0, "y": 52.6 }); labels.append({ "t": "MANGROVES", "x": 109.5, "y": 63.0 })
	for x in range(4, MW, 9):
		lamps.append(Vector2(x + 0.5, 33.5)); lamps.append(Vector2(x + 4.5, 37.5))
	for y in range(3, MH - 70, 8):
		lamps.append(Vector2(39.5, y + 0.5)); lamps.append(Vector2(61.5, max(38, y) + 0.5))
	lamps.append_array([Vector2(49, 33.2), Vector2(18, 40), Vector2(18, 47), Vector2(85, 58), Vector2(104, 73), Vector2(64, 58)])
	# south side: Back Canal, Airport Blvd, Sunsplash Jungle, Heron Lakes, the airport
	rect(110, 55, 111, 77, T.WATER, 2)
	rect(93, 55, 96, 55, T.WATER, 2); rect(93, 56, 96, 56, T.WARM, 6)
	rect(93, 55, 96, 55, T.WALK)
	for x in range(93, 97): zone[idx(x, 56)] = 3
	rect(0, 78, 111, 80, T.WATER, 9); rect(0, 77, 109, 77, T.WALK); rect(0, 81, 111, 81, T.WALK)
	rect(0, 83, 111, 84, T.ROAD); rect(0, 82, 111, 82, T.WALK); rect(0, 85, 111, 85, T.WALK)
	rect(50, 81, 51, 85, T.WATER, 9); rect(79, 81, 80, 108, T.WATER, 9)
	rect(40, 78, 42, 85, T.ROAD); rect(39, 78, 39, 80, T.WALK); rect(43, 78, 43, 80, T.WALK)
	rect(58, 78, 60, 84, T.ROAD); rect(57, 78, 57, 80, T.WALK); rect(61, 78, 61, 80, T.WALK)
	rect(50, 83, 51, 84, T.ROAD); rect(50, 82, 51, 82, T.WALK); rect(50, 85, 51, 85, T.WALK)
	rect(79, 83, 80, 84, T.ROAD); rect(79, 82, 80, 82, T.WALK); rect(79, 85, 80, 85, T.WALK)
	bridges.append_array([{ "x0": 39, "x1": 43, "y0": 78, "y1": 80 }, { "x0": 57, "x1": 61, "y0": 78, "y1": 80 }, { "x0": 50, "x1": 51, "y0": 82, "y1": 85, "h": true }, { "x0": 79, "x1": 80, "y0": 82, "y1": 85, "h": true }, { "x0": 93, "x1": 96, "y0": 55, "y1": 55, "h": true, "foot": true }])
	labels.append({ "t": "BACK CANAL", "x": 26.0, "y": 79.6 })
	# Sunsplash Jungle Park
	rect(1, 87, 36, 114, T.GRASS)
	rect(0, 86, 37, 86, T.FENCE); rect(37, 86, 37, 115, T.FENCE); rect(0, 115, 37, 115, T.FENCE); rect(0, 86, 0, 115, T.FENCE)
	set_t(20, 86, T.PGATE)
	rect(20, 87, 20, 91, T.PATH); rect(4, 92, 29, 92, T.PATH); rect(4, 108, 29, 108, T.PATH); rect(4, 92, 4, 108, T.PATH); rect(29, 92, 29, 108, T.PATH); rect(29, 99, 33, 99, T.PATH)
	ell(16.5, 100, 10, 5.6, T.WATER, 10)
	ell(16.5, 100, 2.4, 1.9, T.BLD); buildings.append({ "x": 14, "y": 98, "w": 5, "h": 4, "kind": "volcano", "color": "#5c4632", "label": "" })
	bld(31, 95, 4, 3, "#9fd3c7", "bath"); set_t(32, 98, T.HIDE)
	bld(22, 87, 3, 2, "#f2b134", "booth")
	trees([[2, 90], [34, 90], [2, 112], [13, 113], [26, 113], [34, 108], [2, 100], [32, 104]])
	bushes([[6, 110], [7, 110], [22, 110], [32, 112], [33, 101], [34, 101]])
	zrect(1, 87, 36, 114, 5); zone[idx(20, 86)] = 5
	labels.append({ "t": "SUNSPLASH JUNGLE PARK", "x": 18.5, "y": 94.2 })
	signs.append_array([Vector2(9, 93.6), Vector2(24, 106.6)])
	for a in range(10): lamps.append(Vector2(16.5 + cos(a * TAU / 10) * 12.5, 100 + sin(a * TAU / 10) * 8))
	# Heron Lakes
	rect(45, 87, 77, 114, T.GRASS)
	rect(44, 86, 78, 86, T.HWALL); rect(44, 86, 44, 115, T.HWALL); rect(78, 86, 78, 115, T.HWALL); rect(44, 115, 78, 115, T.HWALL)
	set_t(61, 86, T.HGATE)
	rect(61, 87, 61, 90, T.ROAD)
	rect(47, 91, 75, 92, T.ROAD); rect(47, 110, 75, 111, T.ROAD); rect(47, 91, 48, 111, T.ROAD); rect(74, 91, 75, 111, T.ROAD)
	ell(61, 101, 8, 4.4, T.WATER, 11)
	rect(50, 86, 51, 99, T.WATER, 11); rect(50, 99, 54, 100, T.WATER, 11)
	rect(50, 91, 51, 92, T.ROAD); bridges.append({ "x0": 50, "x1": 51, "y0": 91, "y1": 92, "h": true, "road": true })
	for x in [53, 63, 69]: bld(x, 87, 5, 3, ROOFS[(x + 1) % 8])
	for x in [50, 57, 64, 70]: bld(x, 112, 5, 3, ROOFS[(x * 3) % 8])
	trees([[49, 94], [73, 94], [49, 108], [73, 108]]); bushes([[53, 95], [69, 95], [53, 107], [69, 107], [46, 100], [76, 100]])
	zrect(45, 87, 77, 114, 6); zone[idx(61, 86)] = 6; zone[idx(50, 86)] = 6; zone[idx(51, 86)] = 6
	labels.append({ "t": "HERON LAKES", "x": 61.0, "y": 95.2 })
	for x in [55, 66, 72]:
		lamps.append(Vector2(x, 93.2)); lamps.append(Vector2(x, 109.6))
	# the airport
	rect(83, 87, 110, 114, T.GRASS)
	rect(82, 86, 111, 86, T.FENCE); rect(82, 86, 82, 115, T.FENCE); rect(82, 115, 111, 115, T.FENCE); rect(111, 86, 111, 115, T.FENCE)
	set_t(96, 86, T.GATE); set_t(82, 103, T.GAP)
	rect(81, 86, 81, 105, T.WALK)
	rect(84, 88, 99, 91, T.CONC); rect(96, 87, 96, 87, T.CONC); rect(90, 92, 91, 96, T.RUNWAY)
	rect(84, 97, 110, 101, T.RUNWAY)
	rect(84, 106, 110, 108, T.WATER, 12); rect(81, 106, 83, 108, T.WATER, 12); rect(96, 102, 97, 105, T.WATER, 12)
	bld(84, 88, 6, 3, "#b8c1c6", "plant", "HANGAR 2"); bld(101, 88, 3, 3, "#dfe3e6", "atc")
	bushes([[83, 102], [83, 104], [84, 103]])
	zrect(83, 87, 110, 114, 7); zone[idx(96, 86)] = 7; zone[idx(82, 103)] = 7
	for y in range(106, 109): zone[idx(82, y)] = 7
	labels.append({ "t": "PORT MULLET REGIONAL AIRPORT", "x": 100.0, "y": 94.8 })
	signs.append(Vector2(90, 105.6))
	for x in range(85, 110, 4):
		lamps.append(Vector2(x, 96.6)); lamps.append(Vector2(x, 101.4))
	for x in [8, 30, 48, 70, 90, 104]: lamps.append(Vector2(x + 0.5, 82.5))
	_build_downtown()
	_build_driveways()
	_build_depth()

static func _build_downtown() -> void:
	rect(81, 109, 81, 115, T.WALK)
	rect(79, 109, 80, 157, T.WATER, 13)
	rect(0, 158, 111, 183, T.WATER, 14); rect(0, 171, 111, 183, T.DEEP, 15)
	rect(0, 116, 111, 116, T.WALK); rect(0, 117, 111, 118, T.ROAD); rect(0, 119, 111, 119, T.WALK)
	rect(0, 135, 111, 135, T.WALK); rect(0, 136, 111, 137, T.ROAD); rect(0, 138, 111, 138, T.WALK)
	rect(0, 154, 111, 154, T.WALK); rect(0, 155, 111, 156, T.ROAD); rect(0, 157, 111, 157, T.WALK)
	rect(40, 116, 42, 156, T.ROAD); rect(20, 117, 21, 156, T.ROAD); rect(96, 117, 97, 156, T.ROAD)
	for ab in [[120, 134], [139, 153]]:
		for x in [19, 22, 39, 43, 78, 81, 95, 98]: rect(x, ab[0], x, ab[1], T.WALK)
	bridges.append_array([{ "x0": 79, "x1": 80, "y0": 116, "y1": 119, "h": true }, { "x0": 79, "x1": 80, "y0": 135, "y1": 138, "h": true }, { "x0": 79, "x1": 80, "y0": 154, "y1": 157, "h": true }])
	rect(0, 157, 18, 160, T.SAND)
	rect(30, 158, 31, 166, T.DOCK); rect(26, 165, 35, 166, T.DOCK)
	rect(83, 158, 110, 158, T.DOCK)
	for x in [86, 91, 96, 101, 106]: rect(x, 159, x, 163, T.DOCK)
	zrect(82, 158, 111, 163, 9)
	# Bird Key: a rounded, lumpy island rather than a stretched ellipse
	blob(62, 165, 6.4, 3.3, T.SAND, 7.0)
	for y in range(160, 171):
		for x in range(54, 71):
			if tile[idx(x, y)] != T.SAND or hash2(x * 3, y * 5) >= 0.24: continue
			var inner := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0)]:
				if t_at(x + d.x, y + d.y) != T.SAND: inner = false
			if inner: set_t(x, y, T.BUSH)
	trees([[59, 164], [65, 165], [62, 166]])
	rect(0, 120, 18, 134, T.CONC)
	sky(1, 121, 7, 6, "#5bb5a9", 15, "SUNSHINE BANK", { "ant": true }); sky(10, 121, 7, 5, "#8cc0de", 9); sky(1, 129, 8, 5, "#e98a7b", 6, "HOTEL FLAMINGO", { "pool": true }); sky(11, 128, 6, 6, "#f6c86d", 11)
	rect(24, 122, 37, 122, T.PATH); rect(24, 133, 37, 133, T.PATH); rect(24, 122, 24, 133, T.PATH); rect(37, 122, 37, 133, T.PATH); rect(30, 120, 31, 121, T.PATH); rect(30, 134, 31, 134, T.PATH)
	ell(30.5, 127.5, 5.2, 3.6, T.WATER, 17)
	trees([[23, 120], [38, 120], [23, 134], [38, 134], [26, 123], [35, 132], [34, 123], [26, 132]])
	bushes([[25, 121], [36, 121], [25, 134], [36, 134], [23, 127], [38, 127]])
	labels.append({ "t": "BAYFRONT PARK", "x": 30.5, "y": 121.4 })
	rect(44, 120, 77, 134, T.PLAZA)
	sky(58, 121, 12, 6, "#7fb8d6", 16, "MARLOWE TOWER", { "ant": true, "glass": true, "logo": true })
	rect(48, 129, 73, 132, T.WATER, 16)
	trees([[47, 124], [53, 124], [74, 124], [46, 131], [76, 131]])
	bushes([[45, 127], [46, 127], [50, 127], [55, 127], [71, 127], [75, 127], [45, 133], [52, 134], [60, 134], [69, 134], [76, 133]])
	zrect(44, 120, 77, 134, 8)
	signs.append_array([Vector2(56, 128.5), Vector2(66, 128.5)])
	rect(82, 120, 94, 134, T.CONC); bld(83, 121, 11, 7, "#2b7ea6", "mega", "FINTASTIC! OUTDOORS"); set_t(88, 127, T.DOOR)
	decor.append({ "k": "parking", "x0": 83, "y0": 130, "x1": 93, "y1": 133 })
	rect(99, 120, 111, 134, T.CONC)
	sky(100, 121, 5, 5, "#9fd3c7", 10); sky(106, 121, 5, 5, "#c9b6e4", 12, "", { "ant": true }); sky(100, 128, 11, 5, "#f1e4c8", 7, "BAYVIEW CONDOS", { "pool": true })
	rect(0, 139, 18, 153, T.CONC)
	bld(1, 140, 9, 6, "#f4efe4", "flat", "CITY HALL"); sky(12, 140, 6, 6, "#9aa6ad", 10); sky(1, 148, 7, 5, "#c9b6e4", 7); sky(10, 148, 8, 5, "#5bb5a9", 5)
	rect(23, 139, 38, 153, T.CONC)
	sky(24, 140, 7, 7, "#3d6e8e", 20, "ONE MULLET PLACE", { "heli": true, "glass": true }); sky(33, 140, 5, 6, "#f3a6a0", 8); bld(24, 149, 14, 4, "#f1d9a8", "flat", "SEASIDE MARKET")
	rect(44, 139, 77, 153, T.CONC)
	sky(45, 140, 6, 6, "#8cc0de", 13); sky(53, 140, 6, 6, "#e98a7b", 9); sky(61, 140, 7, 6, "#9fd3c7", 17, "SKYLINE ONE", { "ant": true, "glass": true }); sky(70, 140, 7, 6, "#f6c86d", 8)
	bld(45, 148, 10, 5, "#b8c1c6", "flat", "PARKING"); bld(57, 148, 9, 5, "#f4efe4", "flat"); bld(68, 148, 9, 5, "#e2583e", "flat", "THE RIVER ROOM")
	rect(82, 139, 94, 153, T.CONC); rect(99, 139, 111, 153, T.CONC)
	bld(84, 140, 9, 5, "#f1e4c8", "marina", "MULLET BAY MARINA"); set_t(88, 144, T.DOOR)
	bld(100, 140, 11, 6, "#dfe3e6", "flat", "DRY STACK")
	decor.append({ "k": "parking", "x0": 83, "y0": 147, "x1": 93, "y1": 152 }); decor.append({ "k": "parking", "x0": 100, "y0": 148, "x1": 110, "y1": 152 })
	for x in range(3, MW, 8):
		lamps.append_array([Vector2(x + 0.5, 116.5), Vector2(x + 4.5, 119.5), Vector2(x + 0.5, 135.5), Vector2(x + 4.5, 138.5), Vector2(x + 0.5, 154.5), Vector2(x + 2.5, 157.4)])
	lamps.append_array([Vector2(30.5, 160), Vector2(30.5, 163), Vector2(26.6, 165.5), Vector2(35.4, 165.5), Vector2(47, 128.4), Vector2(75, 128.4), Vector2(47, 133.4), Vector2(75, 133.4)])
	for x in range(86, 107, 5): lamps.append(Vector2(x + 0.5, 158.5))
	for y in [111, 126, 145]: lamps.append(Vector2(81.5, y))
	labels.append_array([{ "t": "MULLET BAY", "x": 52.0, "y": 168.6 }, { "t": "OFFSHORE · SKIFF ONLY", "x": 52.0, "y": 177.0 }, { "t": "BIRD KEY", "x": 62.0, "y": 161.0 }, { "t": "MULLET BEACH", "x": 9.0, "y": 159.0 }, { "t": "MUNICIPAL PIER", "x": 30.8, "y": 168.1 }])
	# the home is the yellow house by Maple Park Pond
	for b in buildings:
		if b.x == 8 and b.y == 7:
			b.home = true; b.color = "#f6c86d"; b.label = "HOME"

## Every house gets a driveway to the nearest street, if one is close and nothing is in the way.
static func _build_driveways() -> void:
	var ok := [T.GRASS, T.WALK, T.CONC]
	for b in buildings:
		if b.kind != "house": continue
		var x: int = b.x
		var y: int = b.y
		var w: int = b.w
		var h: int = b.h
		var best = null
		# south and north run from the garage end (east side), west and east from the back half of the side wall
		var cands := [[Vector2i(0, 1), x + w - 2, y + h], [Vector2i(0, -1), x + w - 2, y - 1], [Vector2i(-1, 0), x - 1, y + h - 2], [Vector2i(1, 0), x + w, y + h - 2]]
		for c in cands:
			var d: Vector2i = c[0]
			var fx: int = c[1]
			var fy: int = c[2]
			var n := 0
			var found := false
			while n < 9:
				var cx: int = fx + d.x * n
				var cy: int = fy + d.y * n
				var tiles := [Vector2i(cx, cy), Vector2i(cx + (1 if d.y != 0 else 0), cy + (1 if d.x != 0 else 0))]
				var road := false
				var blocked := false
				for tl in tiles:
					var tt := t_at(tl.x, tl.y)
					if tt == T.ROAD: road = true
					elif not (tt in ok) or zone[idx(tl.x, tl.y)] != zone[idx(x, y)] and tt != T.WALK: blocked = true
				if road: found = true; break
				if blocked: break
				n += 1
			if found and n > 0 and (best == null or n < best[1]): best = [c, n]
		if best == null: continue
		var c: Array = best[0]
		var d: Vector2i = c[0]
		var n: int = best[1]
		var r: Rect2
		match d:
			Vector2i(0, 1): r = Rect2(x + w - 1.6, y + h, 1.2, n)
			Vector2i(0, -1): r = Rect2(x + w - 1.6, y - n, 1.2, n)
			Vector2i(-1, 0): r = Rect2(x - n, y + h - 1.45, n, 1.15)
			_: r = Rect2(x + w, y + h - 1.45, n, 1.15)
		driveways.append({ "r": r, "d": d, "car": hash2(x * 7, y * 3) < 0.55 and n >= 2 })

## Distance from shore for every water tile, for the shallow-to-deep color.
static func _build_depth() -> void:
	var q: Array[int] = []
	var n4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in MH:
		for x in MW:
			if not is_water_t(tile[idx(x, y)]): continue
			for d in n4:
				if inb(x + d.x, y + d.y) and not is_water_t(tile[idx(x + d.x, y + d.y)]):
					depth[idx(x, y)] = 1; q.append(idx(x, y)); break
	var k := 0
	while k < q.size():
		var i: int = q[k]; k += 1
		if depth[i] >= 9: continue
		var x := i % MW
		var y := i / MW
		for d in n4:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not inb(nx, ny): continue
			var j := idx(nx, ny)
			if is_water_t(tile[j]) and depth[j] == 0:
				depth[j] = depth[i] + 1; q.append(j)

static func in_bridge(x: int, y: int) -> bool:
	for b in bridges:
		if x >= b.x0 and x <= b.x1 and y >= b.y0 and y <= b.y1: return true
	return false
