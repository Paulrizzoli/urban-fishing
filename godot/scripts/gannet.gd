class_name Gannet
## The third town: Gannet Harbor, a big old harbor city up the northeast coast, a long coach ride from both
## Port Mullet and Ironwater. The city runs down the west side of the map on a grid of avenues and cross
## streets with a subway (the Harbor Line) under it. The harbor fills the east side: the inner harbor at the
## top, the fish market wharf and the ferry slip off the Harbor Walk, then the Narrows, where the huge Gannet
## Narrows suspension bridge crosses to Fort Kettle Island, and below it the outer harbor, the container port
## and the harbor mouth.
## Built by Town.build() when the save is in Gannet Harbor (Town.level == 2). Same map size as the others.
##
## Fishing spots (water regions): 30 Inner Harbor, 31 The Narrows, 32 Fish Market Wharf, 33 Container Port,
## 34 The Outfall, 35 Ferry Slip, 36 Rooftop Garden Pond, 37 Outer Harbor.
## Guarded zones: 30 the fish market wharf, 31 the container port, 32 the rooftop garden, 33 the bridge tower yard.

const T := Town.T
const HARBOR := 30
const NARROWS := 31
const MARKET := 32
const PORT := 33
const OUTFALL := 34
const FERRY := 35
const ROOF := 36
const OUTER := 37

const BRICK := ["#9a4e3e", "#a8604a", "#8a4636", "#b5735a", "#7f4a3c", "#a5574a", "#94604e", "#b0806a"]
const SHORE := 65            # the first column of harbor water along the seawall
## The Gannet Narrows Bridge: the whole width of the map, y0..y1, with its towers at these columns.
const BR_Y0 := 96
const BR_Y1 := 100
const TOWERS := [77, 95]
const PIERS := [6, 27, 48]   # the approach piers on land
## The container ship tied up at the port, in tiles.
const SHIP := Rect2(68, 139, 10, 22)
## The outfall pipe in the seawall.
const PIPE := Vector2(64.5, 123.0)
## The ferry slip between the two ferry piers.
const SLIP := Rect2(65, 64, 16, 9)

static func build() -> void:
	# ---------- the harbor: everything east of the seawall ----------
	Town.rect(SHORE, 0, Town.MW - 1, Town.MH - 1, T.WATER, HARBOR)
	# ---------- streets ----------
	# the avenues, top to bottom: Kestrel Ave, Commercial St and Harbor Ave along the waterfront
	for ax in [16, 38, 59]:
		Town.rect(ax, 0, ax + 1, Town.MH - 1, T.ROAD); Town.rect(ax - 1, 0, ax - 1, Town.MH - 1, T.WALK); Town.rect(ax + 2, 0, ax + 2, Town.MH - 1, T.WALK)
	# the Harbor Walk: a wide promenade along the top of the seawall
	Town.rect(62, 0, 64, Town.MH - 1, T.WALK)
	# the cross streets
	for y0 in [27, 57, 79, 111, 132, 164]:
		Town.rect(0, y0, 61, y0, T.WALK); Town.rect(0, y0 + 1, 61, y0 + 2, T.ROAD); Town.rect(0, y0 + 3, 61, y0 + 3, T.WALK)
	# ---------- the North End and downtown ----------
	_rooftop()
	_rowhouses(0, 0, 14, 26)
	Town.rect(41, 0, 57, 26, T.CONC)
	Town.sky(42, 2, 7, 7, "#6a8aa0", 18, "HARBOR TRUST", { "glass": true, "ant": true })
	Town.sky(51, 1, 6, 6, "#8a6a5a", 11)
	Town.sky(42, 14, 6, 6, "#9aa6ad", 14, "", { "glass": true })
	Town.sky(50, 13, 7, 7, "#3d6e8e", 22, "ONE GANNET PLACE", { "heli": true, "glass": true })
	# the financial district
	Town.rect(19, 31, 36, 56, T.CONC)
	Town.sky(20, 32, 7, 6, "#5b7f9a", 16, "", { "glass": true, "ant": true })
	Town.sky(29, 32, 7, 7, "#a8604a", 9, "CUSTOM HOUSE")
	Town.sky(20, 42, 6, 6, "#8c7c9c", 12)
	Town.sky(28, 42, 8, 6, "#2f5a7a", 20, "KETTLE BANK TOWER", { "glass": true, "logo": true })
	Town.bld(20, 51, 16, 4, "#c8b89a", "flat", "OLD STATE HOUSE")
	_rowhouses(0, 31, 14, 56)
	_market()
	# ---------- the ferry terminal and the middle of town ----------
	_rowhouses(0, 61, 14, 78)
	Town.rect(19, 61, 36, 78, T.CONC)
	Town.bld(20, 62, 9, 6, "#a8604a", "flat", "SEAMEN'S HOSTEL", { "motel": true, "home": true }); Town.set_t(24, 67, T.DOOR)
	Town.sky(31, 62, 5, 6, "#6f7f86", 10)
	Town.sky(20, 71, 7, 6, "#b5876a", 8)
	Town.sky(29, 70, 7, 7, "#5b98a6", 13, "", { "glass": true })
	_ferry()
	# ---------- the bridge and Narrows Park ----------
	_bridge()
	_rowhouses(0, 83, 14, 110)
	Town.rect(19, 83, 36, 110, T.CONC)
	Town.bld(20, 84, 8, 5, "#8a4636", "flat", "ST. BRENDAN'S")
	Town.bld(30, 84, 6, 6, "#9aa6ad", "flat")
	Town.decor.append({ "k": "parking", "x0": 20, "y0": 92, "x1": 35, "y1": 94 })
	Town.bld(20, 103, 7, 6, "#b5735a", "flat"); Town.bld(29, 103, 7, 6, "#a8604a", "flat", "KETTLE DINER")
	Town.rect(41, 83, 57, 110, T.CONC)
	Town.sky(42, 84, 6, 6, "#7a8a6a", 9); Town.sky(50, 84, 7, 7, "#6a8aa0", 12, "", { "glass": true })
	Town.decor.append({ "k": "parking", "x0": 42, "y0": 101, "x1": 56, "y1": 103 })
	Town.bld(42, 105, 15, 4, "#c8a46a", "flat", "NARROWS STATION")
	_narrows_park()
	_island()
	# ---------- south of the bridge: the outfall, the port, the station and the beach ----------
	_rowhouses(0, 115, 14, 131)
	_rowhouses(19, 115, 36, 131)
	_outfall()
	_rowhouses(0, 136, 14, 163)
	Town.rect(19, 136, 36, 163, T.CONC)
	Town.bld(20, 137, 16, 7, "#9aa6ad", "flat", "HARBOR COLD STORAGE")
	Town.bld(20, 147, 7, 6, "#8a4636", "flat"); Town.bld(29, 147, 7, 6, "#7f4a3c", "flat", "SAIL LOFT")
	Town.decor.append({ "k": "parking", "x0": 20, "y0": 156, "x1": 35, "y1": 162 })
	_port()
	_station()
	_rowhouses(0, 168, 14, 183)
	# Kettle Point Beach, at the bottom of the Harbor Walk
	Town.rect(41, 168, 64, 183, T.SAND)
	Town.rect(41, 168, 57, 170, T.GRASS)
	Town.trees([[43, 169], [48, 169], [53, 169]])
	Town.decor.append({ "k": "bench", "x": 46.0, "y": 170.4 }); Town.decor.append({ "k": "bench", "x": 51.0, "y": 170.4 })
	Town.labels.append({ "t": "KETTLE POINT BEACH", "x": 52.0, "y": 175.0 })
	# the harbor mouth: past the channel buoys it's open sea, skiff only
	for y in range(171, Town.MH):
		for x in range(SHORE + 4, Town.MW):
			if Town.tile[Town.idx(x, y)] == T.WATER: Town.tile[Town.idx(x, y)] = T.DEEP
	_regions()
	# street trees along the avenues, lamps along everything
	for y in range(2, Town.MH - 1, 7):
		if y >= BR_Y0 - 1 and y <= BR_Y1 + 1: continue
		for x in [15, 18, 37, 40]:
			if Town.tile[Town.idx(x, y)] == T.WALK and Town.hash2(x, y) < 0.5: Town.lamps.append(Vector2(x + 0.5, y + 0.5))
	for y in range(3, Town.MH, 8):
		if y >= BR_Y0 - 1 and y <= BR_Y1 + 1: continue
		Town.lamps.append(Vector2(63.0, y + 0.5))
	for y0 in [27, 57, 79, 111, 132, 164]:
		for x in range(4, 60, 9): Town.lamps.append(Vector2(x + 0.5, y0 + 0.5))
	Town.lamps = Town.lamps.filter(func(l): var t := Town.t_at(floori(l.x), floori(l.y)); return not Town.is_water_t(t) and t != T.BLD and t != T.FENCE and t != T.ROAD)
	Town.labels.append_array([{ "t": "INNER HARBOR", "x": 90.0, "y": 16.0 }, { "t": "OUTER HARBOR", "x": 90.0, "y": 128.0 }, { "t": "HARBOR MOUTH · SKIFF ONLY", "x": 90.0, "y": 177.0 },
		{ "t": "HARBOR WALK", "x": 63.5, "y": 20.0 }])
	Town.launch_k = [HARBOR, NARROWS, FERRY, OUTER, MARKET]
	Town.launch_s = [HARBOR, NARROWS, OUTER]

## A block of brick row houses, the city's own: narrow, tall and close together, in rows across the block.
static func _rowhouses(x0: int, y0: int, x1: int, y1: int) -> void:
	Town.rect(x0, y0, x1, y1, T.CONC)
	var y := y0 + 1
	while y + 3 <= y1:
		if y + 3 >= BR_Y0 - 1 and y <= BR_Y1 + 1: y += 5; continue   # nothing built under the bridge deck
		var x := x0 + 1
		while x + 3 <= x1:
			var w := 3 + int(Town.hash2(x, y) * 2.0)
			if x + w - 1 > x1 - 1: break
			Town.bld(x, y, w, 3, BRICK[(x * 3 + y) % BRICK.size()], "flat")
			x += w
		# a stoop-side sidewalk and a strip of street trees between the rows
		if y + 4 <= y1 and Town.hash2(y, x0) < 0.6: Town.set_t(x0 + 1 + int(Town.hash2(x0, y) * (x1 - x0 - 2)), y + 3, T.TREE)
		y += 5

## Skyline Commons: a rooftop garden with a pond, nine floors up on a parking garage. You ride the elevator
## up from the plaza on Pilot St (the gate in the parapet).
static func _rooftop() -> void:
	Town.rect(19, 0, 36, 26, T.CONC)
	Town.rect(20, 2, 35, 24, T.HWALL)
	Town.rect(21, 3, 34, 23, T.GRASS)
	Town.blob(27.5, 12.0, 4.4, 3.2, T.WATER, 1.3, ROOF)
	Town.rect(22, 18, 33, 18, T.PATH); Town.rect(22, 5, 22, 18, T.PATH); Town.rect(33, 5, 33, 18, T.PATH); Town.rect(22, 5, 33, 5, T.PATH)
	Town.rect(27, 19, 28, 23, T.PATH)
	Town.set_t(27, 24, T.GATE)
	Town.trees([[24, 21], [31, 21], [21, 3], [34, 3]])
	Town.bushes([[21, 10], [34, 10], [21, 15], [34, 15], [25, 21], [30, 21]])
	Town.decor.append({ "k": "bench", "x": 25.0, "y": 17.6 }); Town.decor.append({ "k": "bench", "x": 30.5, "y": 17.6 })
	Town.zrect(21, 3, 34, 23, 32); Town.zone[Town.idx(27, 24)] = 32
	Town.signs.append(Vector2(32.5, 25.6))
	Town.labels.append({ "t": "SKYLINE COMMONS", "x": 27.5, "y": 7.0 })

## The Gannet Fish Pier: the fish exchange on Harbor Ave, and the long wharf out into the harbor with
## the market sheds on it. The slip water all round the wharf is its own spot.
static func _market() -> void:
	Town.rect(41, 31, 57, 56, T.CONC)
	# the Gannet Fish Exchange (42, 32) and the Chowder House (44, 52) are Buyers, from data/buyers.json
	Town.bld(43, 46, 9, 5, "#2f6a5a", "shop", "PIER 6 BAIT & TACKLE"); Town.set_t(47, 50, T.DOOR)
	# the wharf, with its sheds
	Town.rect(SHORE, 35, 86, 43, T.DOCK)
	Town.bld(68, 37, 7, 4, "#e8e0cc", "flat", "", { "shed": true })
	Town.bld(77, 37, 7, 4, "#e8e0cc", "flat", "", { "shed": true })
	Town.zrect(SHORE, 35, 86, 43, 30)
	Town.signs.append(Vector2(63.0, 37.5))
	Town.labels.append({ "t": "FISH MARKET WHARF", "x": 76.0, "y": 33.0 })

## The ferry terminal on Harbor Ave and its two piers, with the slip between them.
static func _ferry() -> void:
	Town.rect(41, 61, 57, 78, T.CONC)
	Town.bld(43, 62, 13, 8, "#e8e0cc", "flat", "FERRY TERMINAL", { "ferry": true })
	Town.decor.append({ "k": "parking", "x0": 42, "y0": 72, "x1": 56, "y1": 77 })
	Town.rect(SHORE, 62, 81, 63, T.DOCK); Town.rect(SHORE, 73, 81, 74, T.DOCK)
	Town.labels.append({ "t": "FERRY SLIP", "x": 73.0, "y": 68.6 })

## The bridge: a huge suspension bridge across the Narrows, carried on over the city on approach spans.
## Like Ironwater's viaduct it's high enough to walk and paddle under, with the same bridge shade.
static func _bridge() -> void:
	Town.bridges.append({ "x0": 0, "x1": Town.MW - 1, "y0": BR_Y0, "y1": BR_Y1, "h": true, "high": true, "susp": true, "gx0": 81, "gx1": 98 })
	for px in PIERS: Town.rect(px, BR_Y0 + 1, px + 1, BR_Y1 - 1, T.BLD, 0)
	for tx in TOWERS: Town.rect(tx, BR_Y0 + 1, tx + 1, BR_Y1 - 1, T.BLD, 0)

## Narrows Park: a point of land under the west tower, with a public pier into the Narrows and the
## fenced tower yard right at the foot of the tower.
static func _narrows_park() -> void:
	Town.rect(SHORE - 3, 84, 80, 110, T.GRASS)
	Town.rect(62, 84, 64, 110, T.WALK)
	Town.rect(65, 104, 80, 104, T.PATH); Town.rect(65, 88, 80, 88, T.PATH); Town.rect(68, 88, 68, 104, T.PATH)
	Town.trees([[66, 85], [71, 85], [66, 92], [66, 108], [72, 108], [70, 92]])
	Town.bushes([[73, 86], [65, 95], [65, 101]])
	Town.decor.append({ "k": "bench", "x": 70.0, "y": 104.6 }); Town.decor.append({ "k": "bench", "x": 75.0, "y": 88.6 })
	# the tower yard, fenced, right under the bridge
	Town.rect(73, 91, 73, 105, T.FENCE); Town.rect(73, 91, 80, 91, T.FENCE); Town.rect(73, 105, 80, 105, T.FENCE)
	Town.rect(74, 92, 80, 104, T.CONC)
	Town.set_t(73, 102, T.GATE)
	Town.zrect(74, 92, 80, 104, 33); Town.zone[Town.idx(73, 102)] = 33
	Town.signs.append(Vector2(72.5, 101.4))
	# the public pier into the Narrows
	Town.rect(81, 107, 89, 108, T.DOCK)
	Town.labels.append({ "t": "NARROWS PARK", "x": 69.0, "y": 86.4 })
	Town.labels.append({ "t": "THE NARROWS", "x": 88.0, "y": 89.0 })

## Fort Kettle Island across the Narrows: an old star fort and a lighthouse. Only a boat gets you there.
static func _island() -> void:
	Town.blob(106, 99, 8.5, 21.0, T.SAND, 3.3)
	Town.blob(107, 99, 6.2, 17.5, T.GRASS, 3.3)
	for y in range(80, 118):
		for x in range(100, 112):
			if Town.tile[Town.idx(x, y)] == T.GRASS and Town.hash2(x * 5, y * 3) < 0.12 and (y < 92 or y > 106): Town.set_t(x, y, T.TREE if Town.hash2(y, x) < 0.4 else T.BUSH)
	Town.rect(103, 92, 109, 95, T.BLD, 0)
	Town.buildings.append({ "x": 103, "y": 92, "w": 7, "h": 4, "kind": "flat", "color": "#b8a88a", "label": "FORT KETTLE" })
	Town.rect(104, 84, 105, 85, T.BLD, 0)
	Town.decor.append({ "k": "lighthouse", "x": 105.0, "y": 85.0 })
	Town.labels.append({ "t": "FORT KETTLE ISLAND", "x": 106.0, "y": 110.0 })

## CSO 017: the combined sewer outfall. A big arched pipe in the seawall below the pump house.
static func _outfall() -> void:
	Town.rect(41, 115, 57, 131, T.CONC)
	Town.bld(43, 116, 12, 7, "#8a8f86", "flat", "HARBOR WATER AUTHORITY")
	Town.bld(43, 125, 6, 5, "#9a4e3e", "flat"); Town.bld(51, 125, 6, 5, "#a8604a", "flat")
	Town.labels.append({ "t": "CSO 017", "x": 68.0, "y": 119.4 })

## Gannet Marine Terminal: a fenced yard of stacked containers, cranes on the quay and a container ship
## tied up alongside. Harbor Ave stops at its gate.
static func _port() -> void:
	Town.rect(41, 136, 64, 163, T.CONC)
	Town.rect(59, 136, 61, 163, T.CONC)     # Harbor Ave ends at Port Rd; the yard takes the rest
	Town.rect(62, 136, 64, 163, T.CONC)
	Town.rect(40, 135, 40, 164, T.FENCE); Town.rect(40, 135, 64, 135, T.FENCE); Town.rect(40, 164, 64, 164, T.FENCE)
	Town.set_t(52, 135, T.GATE); Town.set_t(40, 158, T.GAP)
	Town.bushes([[39, 157], [39, 159]])
	# the stacks: rows of containers with lanes between them for the straddle carriers
	var cols := ["#c0392b", "#2b7ea6", "#3d8a4a", "#e3a23c", "#6c7178", "#8a4636", "#2f5a7a", "#d8d2c4"]
	var i := 0
	for y in [138, 143, 148, 153]:
		for x in [42, 49]:
			Town.bld(x, y, 6, 3, cols[i % cols.size()], "containers", "", { "seed": i })
			i += 1
	# the quay cranes straddle the apron along the water
	for cy in [140.0, 149.0, 158.0]: Town.decor.append({ "k": "crane", "x": 61.5, "y": cy })
	# the ship
	Town.rect(int(SHIP.position.x), int(SHIP.position.y), int(SHIP.end.x) - 1, int(SHIP.end.y) - 1, T.BLD, 0)
	Town.buildings.append({ "x": SHIP.position.x, "y": SHIP.position.y, "w": SHIP.size.x, "h": SHIP.size.y, "kind": "ship", "color": "#2f5a7a", "label": "" })
	Town.zrect(41, 136, 64, 163, 31); Town.zone[Town.idx(52, 135)] = 31; Town.zone[Town.idx(40, 158)] = 31
	Town.signs.append_array([Vector2(50.5, 134.4), Vector2(54.5, 134.4)])
	Town.labels.append({ "t": "GANNET MARINE TERMINAL", "x": 52.0, "y": 147.6 })

## Gannet Union Station, where the coaches come in, with the rail yard behind it.
static func _station() -> void:
	Town.rect(19, 168, 36, 183, T.CONC)
	Town.bld(20, 168, 16, 6, "#c8a46a", "flat", "UNION STATION")
	Town.rect(19, 175, 36, 175, T.WALK)

## Which spot each bit of harbor water belongs to.
static func _regions() -> void:
	for y in Town.MH:
		for x in Town.MW:
			var i := Town.idx(x, y)
			if not Town.is_water_t(Town.tile[i]):
				Town.region[i] = 0; continue
			if x < SHORE: continue
			var r := HARBOR
			if x <= 90 and y >= 27 and y <= 52: r = MARKET
			elif SLIP.has_point(Vector2(x, y)): r = FERRY
			elif x <= 74 and y >= 117 and y <= 129: r = OUTFALL
			elif x <= 81 and y >= 135 and y <= 164: r = PORT
			elif y >= 84 and y <= 112: r = NARROWS
			elif y > 112: r = OUTER
			Town.region[i] = r

# ---------- drawing ----------

## Things drawn on the ground once: the rooftop's raised edge and its shadow, the outfall pipe, rail tracks,
## yard markings at the port and the channel buoys at the harbor mouth.
static func draw_ground(ci: CanvasItem) -> void:
	# Skyline Commons sits nine floors up: a drop shadow off its south and east sides, glass railings
	var r := Rect2(20, 2, 16, 23)
	ci.draw_rect(Rect2(r.position.x + 0.6, r.end.y, r.size.x, 1.2), Color(0, 0, 0, 0.22))
	ci.draw_rect(Rect2(r.end.x, r.position.y + 0.6, 0.9, r.size.y + 0.6), Color(0, 0, 0, 0.18))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 0.1, r.size.x, 1.0), Color("#8a8f96"))   # the garage's front wall
	for k in range(int(r.size.x)):
		ci.draw_rect(Rect2(r.position.x + k + 0.15, r.end.y + 0.15, 0.7, 0.35), Color("#5a6068"))
	ci.draw_rect(Rect2(26.6, r.end.y - 0.1, 2.8, 1.0), Color("#3d6e8e"))   # the elevator lobby
	Art.text(ci, Vector2(28.0, r.end.y + 0.55), "ELEVATOR", 0.22, Color.WHITE)
	# the rail yard behind Union Station
	for ty in [177.0, 180.0]:
		for x in range(19, 37):
			ci.draw_rect(Rect2(x + 0.1, ty - 0.1, 0.25, 0.9), Color("#6b5034")); ci.draw_rect(Rect2(x + 0.6, ty - 0.1, 0.25, 0.9), Color("#6b5034"))
		ci.draw_rect(Rect2(19, ty, 18, 0.08), Color("#8b9196")); ci.draw_rect(Rect2(19, ty + 0.62, 18, 0.08), Color("#8b9196"))
	ci.draw_rect(Rect2(21, 174.85, 14, 0.08), Color("#e8c84a"))   # the coach bay
	# yard lines at the port: lanes between the stacks and the quay edge
	for y in [141.5, 146.5, 151.5, 156.5]: ci.draw_rect(Rect2(41.5, y, 15, 0.06), Color(1, 1, 1, 0.35))
	ci.draw_rect(Rect2(64.75, 136, 0.12, 28), Color("#e3b23c"))
	for y in range(137, 163, 3): ci.draw_rect(Rect2(64.2, y, 0.5, 0.35), Color("#3a3a3a"))   # bollards
	# the fish market: the cutting tables' drains, and a painted line along the wharf edge
	ci.draw_rect(Rect2(SHORE, 35.1, 22, 0.08), Color("#e3b23c", 0.8)); ci.draw_rect(Rect2(SHORE, 43.82, 22, 0.08), Color("#e3b23c", 0.8))
	# the outfall: an arched concrete headwall in the seawall with a grate
	var p := PIPE
	ci.draw_rect(Rect2(p.x - 0.9, p.y - 1.4, 1.4, 2.8), Color("#a8a293"))
	ci.draw_circle(Vector2(p.x + 0.1, p.y), 1.0, Color("#3a3a36"))
	ci.draw_circle(Vector2(p.x + 0.1, p.y), 0.8, Color("#1e1f1c"))
	for k in 5: ci.draw_line(Vector2(p.x - 0.6 + k * 0.35, p.y - 0.75), Vector2(p.x - 0.6 + k * 0.35, p.y + 0.75), Color("#5a5a52"), 0.07)
	# the channel buoys at the harbor mouth
	for x in range(70, 112, 4):
		ci.draw_circle(Vector2(x + 0.5, 170.6), 0.22, Color("#c0392b") if x % 8 == 2 else Color("#3d8a4a"))

## Moving water: the outfall plume, the tide rip through the Narrows and the wake behind the ferry.
static func draw_water(ci: CanvasItem, view: Rect2, t: float) -> void:
	if view.intersects(Rect2(64, 116, 12, 14)):
		var surge: float = 0.6 + 0.4 * Game.wx.rain
		ci.draw_circle(Vector2(PIPE.x + 1.2, PIPE.y), 1.1 * surge, Color(0.85, 0.82, 0.7, 0.35))
		for i in 70:
			var h1 := Town.hash2(i, 13)
			var h2 := Town.hash2(i * 3, 7)
			var life := 3.0 + h2 * 3.0
			var k := fmod(t / life + h1, 1.0)
			var a := h1 * 1.6 - 0.8
			var d: float = 0.8 + pow(k, 0.7) * (5.0 + h2 * 4.0) * surge
			var q := PIPE + Vector2(0.6, 0) + Vector2(cos(a) * d, sin(a) * d * 0.8)
			if q.x < SHORE: continue
			var rr := 0.12 + h2 * 0.2
			Art.ellipse(ci, q, rr * 1.6, rr * 0.6, Color(0.9, 0.88, 0.78, sin(k * PI) * 0.45))
	# the tide rip through the Narrows: streaks drifting south with the ebb
	if view.intersects(Rect2(80, 82, 20, 32)):
		for i in 50:
			var h1 := Town.hash2(i, 3)
			var h2 := Town.hash2(i * 5, 9)
			var y := 84.0 + fposmod(h2 * 28.0 + t * (1.2 + h1 * 0.8), 28.0)
			var x := 81.5 + h1 * 15.0
			if not Town.is_water_t(Town.t_at(floori(x), floori(y))): continue
			ci.draw_line(Vector2(x, y), Vector2(x + 0.05, y + 0.8 + h2 * 0.8), Color(1, 1, 1, 0.16), 0.05)
	var f := ferry_at(t)
	if f.moving and view.grow(4).has_point(f.p):
		for j in 10:
			var back: Vector2 = f.p - Vector2.from_angle(f.a) * (3.0 + j * 0.7)
			var side := Vector2.from_angle(f.a).orthogonal() * (0.5 + j * 0.25)
			var c := Color(1, 1, 1, 0.3 * (1.0 - j / 10.0))
			ci.draw_line(back + side, back + side * 1.2, c, 0.08); ci.draw_line(back - side, back - side * 1.2, c, 0.08)

## Where the harbor ferry is at time t (seconds): it sits in the slip for a while, then crosses the inner
## harbor and comes back. { p, a (heading), moving }
static func ferry_at(t: float) -> Dictionary:
	var cyc := 70.0
	var k := fmod(t, cyc) / cyc
	var dock := Vector2(SLIP.position.x + 8.5, SLIP.get_center().y)
	var away := Vector2(104.0, 52.0)
	if k < 0.35: return { "p": dock, "a": PI, "moving": false }
	if k < 0.65:
		var u := (k - 0.35) / 0.3
		var p := dock.lerp(Vector2(dock.x + 12, dock.y), clampf(u * 3.0, 0, 1)).lerp(away, clampf(u * 1.4 - 0.4, 0, 1))
		return { "p": p, "a": (away - dock).angle() if u > 0.3 else 0.0, "moving": true }
	var u2 := (k - 0.65) / 0.35
	var p2 := away.lerp(Vector2(dock.x + 12, dock.y), clampf(u2 * 1.4, 0, 1)).lerp(dock, clampf(u2 * 3.0 - 2.0, 0, 1))
	return { "p": p2, "a": (dock - away).angle() if u2 < 0.7 else PI, "moving": true }

## The ferry itself, a blunt white double-ender with a wheelhouse and a blue stripe.
static func draw_ferry(ci: CanvasItem, t: float) -> void:
	var f := ferry_at(t)
	var p: Vector2 = f.p
	var a: float = f.a
	var fw := Vector2.from_angle(a)
	var sd := fw.orthogonal()
	var L := 4.2
	var W := 1.6
	Art.ellipse(ci, p + Vector2(0.3, 0.4), L * 0.55, W * 0.6, Color(0, 0, 0, 0.18))
	var hull := PackedVector2Array([p + fw * L * 0.5 + sd * W * 0.3, p + fw * L * 0.42 + sd * W * 0.5, p - fw * L * 0.42 + sd * W * 0.5, p - fw * L * 0.5 + sd * W * 0.3,
		p - fw * L * 0.5 - sd * W * 0.3, p - fw * L * 0.42 - sd * W * 0.5, p + fw * L * 0.42 - sd * W * 0.5, p + fw * L * 0.5 - sd * W * 0.3])
	ci.draw_colored_polygon(hull, Color("#f4f2ea"))
	ci.draw_polyline(hull + PackedVector2Array([hull[0]]), Color("#2b5f8a"), 0.12)
	var deck := PackedVector2Array([p + fw * L * 0.3 + sd * W * 0.32, p - fw * L * 0.3 + sd * W * 0.32, p - fw * L * 0.3 - sd * W * 0.32, p + fw * L * 0.3 - sd * W * 0.32])
	ci.draw_colored_polygon(deck, Color("#dfe4e7"))
	for k in 5:
		var c := p + fw * (-L * 0.24 + k * L * 0.12)
		ci.draw_rect(Rect2(c - Vector2(0.14, 0.14), Vector2(0.28, 0.28)), Color("#8fc4dc"))
	ci.draw_circle(p, 0.32, Color("#2b5f8a"))
	ci.draw_circle(p + Vector2(0, -0.08), 0.18, Color("#e8c84a"))

## The quay cranes: tall blue gantries straddling the apron, booms out over the ship.
static func draw_crane(ci: CanvasItem, p: Vector2, t: float) -> void:
	var blue := Color("#2b6a9a")
	var dk := Color("#1f4a6a")
	var hgt := 6.0
	Art.ellipse(ci, p + Vector2(1.4, 0.4), 3.0, 0.6, Color(0, 0, 0, 0.2))
	for lx in [-1.6, 1.6]:
		for ly in [-0.9, 0.9]:
			ci.draw_line(p + Vector2(lx, ly), p + Vector2(lx, ly - hgt), blue if ly > 0 else dk, 0.22)
	ci.draw_line(p + Vector2(-1.6, 0.9 - hgt * 0.5), p + Vector2(1.6, 0.9 - hgt * 0.5), dk, 0.16)
	ci.draw_line(p + Vector2(-1.6, 0.9 - hgt), p + Vector2(1.6, 0.9 - hgt), blue, 0.3)
	# the boom out over the water, and the trolley running along it
	var b0 := p + Vector2(-2.6, -hgt + 0.2)
	var b1 := p + Vector2(9.0, -hgt + 0.2)
	ci.draw_line(b0, b1, blue, 0.34)
	ci.draw_line(b0 + Vector2(0, -0.4), b1 + Vector2(0, -0.1), dk, 0.08)
	ci.draw_line(p + Vector2(0, -hgt - 1.6), b1, dk, 0.06); ci.draw_line(p + Vector2(0, -hgt - 1.6), b0, dk, 0.06)
	ci.draw_line(p + Vector2(0, -hgt), p + Vector2(0, -hgt - 1.6), blue, 0.2)
	var tr := lerpf(1.0, 8.0, 0.5 + 0.5 * sin(t * 0.25 + p.y))
	ci.draw_rect(Rect2(p.x + tr - 0.35, b0.y - 0.2, 0.7, 0.45), Color("#e3b23c"))
	ci.draw_line(Vector2(p.x + tr, b0.y + 0.2), Vector2(p.x + tr, b0.y + 2.8), Color("#3a3a3a"), 0.04)
	ci.draw_rect(Rect2(p.x + tr - 0.6, b0.y + 2.8, 1.2, 0.5), Color("#c0392b"))   # a box on the spreader
	ci.draw_circle(p + Vector2(0, -hgt - 1.6), 0.12, Color(1, 0.25, 0.2, 0.6 + 0.4 * sin(t * 3.0)))

## The container ship alongside the quay: a dark hull with a red bottom stripe, stacks of boxes on deck and
## the white bridge house at the stern.
static func draw_ship(ci: CanvasItem, b: Dictionary) -> void:
	var r := Rect2(b.x, b.y, b.w, b.h)
	Art.soft_shadow(ci, r.grow(0.3), Vector2(0.5, 0.4))
	var hull := PackedVector2Array([Vector2(r.position.x, r.position.y + 2.5), Vector2(r.get_center().x, r.position.y - 0.5), Vector2(r.end.x, r.position.y + 2.5),
		Vector2(r.end.x, r.end.y - 0.4), Vector2(r.position.x, r.end.y - 0.4)])
	ci.draw_colored_polygon(hull, Color("#c0392b"))
	var top := PackedVector2Array()
	for q in hull: top.append(q + (r.get_center() - q) * 0.06 + Vector2(0, -0.4))
	ci.draw_colored_polygon(top, Color("#22313a"))
	ci.draw_colored_polygon(PackedVector2Array([top[0] + Vector2(0.3, 0.3), top[1] + Vector2(0, 0.6), top[2] + Vector2(-0.3, 0.3), top[3] + Vector2(-0.3, -0.3), top[4] + Vector2(0.3, -0.3)]), Color("#3a4a52"))
	var cols := ["#c0392b", "#2b7ea6", "#3d8a4a", "#e3a23c", "#6c7178", "#8a4636", "#d8d2c4", "#2f5a7a"]
	var y := r.position.y + 3.0
	var row := 0
	while y < r.end.y - 5.0:
		for c in 4:
			var cr := Rect2(r.position.x + 0.8 + c * 2.1, y - 0.5, 1.9, 1.7)
			var col := Color(cols[int(Town.hash2(row * 5 + c, 11) * cols.size())])
			ci.draw_rect(cr, col)
			ci.draw_rect(Rect2(cr.position, Vector2(cr.size.x, 0.18)), Art.shade(col, 0.25))
			for k in 4: ci.draw_line(Vector2(cr.position.x + 0.2 + k * 0.45, cr.position.y + 0.25), Vector2(cr.position.x + 0.2 + k * 0.45, cr.end.y - 0.1), Art.shade(col, -0.2), 0.04)
		y += 1.9; row += 1
	# the bridge house at the stern
	var bh := Rect2(r.position.x + 1.5, r.end.y - 4.6, r.size.x - 3.0, 3.2)
	ci.draw_rect(Rect2(bh.position + Vector2(0, -1.0), bh.size), Color("#f4f2ea"))
	ci.draw_rect(Rect2(bh.position + Vector2(0, bh.size.y - 1.0), Vector2(bh.size.x, 1.0)), Color("#d8d2c4"))
	for k in 6: ci.draw_rect(Rect2(bh.position.x + 0.4 + k * 1.15, bh.position.y - 0.6, 0.7, 0.4), Color("#2f5a7a"))
	ci.draw_rect(Rect2(bh.get_center().x - 0.4, bh.position.y - 2.2, 0.8, 1.3), Color("#c0392b"))   # the funnel
	Art.text(ci, Vector2(r.get_center().x, r.end.y - 0.9), "NORDHAVN", 0.32, Color.WHITE)

## A block of stacked containers, two high, in rows.
static func draw_containers(ci: CanvasItem, b: Dictionary) -> void:
	var cols := ["#c0392b", "#2b7ea6", "#3d8a4a", "#e3a23c", "#6c7178", "#8a4636", "#d8d2c4", "#2f5a7a"]
	var seed := int(b.get("seed", 0))
	Art.soft_shadow(ci, Rect2(b.x, b.y - 0.6, b.w, b.h + 0.6), Vector2(0.4, 0.3))
	for row in 3:
		for lv in 2:
			var col := Color(cols[int(Town.hash2(seed * 7 + row, lv * 3 + 1) * cols.size())])
			var y: float = b.y + row - lv * 0.55 + 0.05
			var cr := Rect2(b.x + 0.05, y, b.w - 0.1, 0.92)
			if lv == 1 and Town.hash2(seed + row, 5) < 0.3: continue
			ci.draw_rect(Rect2(cr.position.x, cr.end.y - 0.3, cr.size.x, 0.3), Art.shade(col, -0.3))
			ci.draw_rect(Rect2(cr.position, Vector2(cr.size.x, cr.size.y - 0.3)), col)
			var k := cr.position.x + 0.3
			while k < cr.end.x - 0.1:
				ci.draw_line(Vector2(k, cr.position.y + 0.05), Vector2(k, cr.end.y - 0.35), Art.shade(col, -0.15), 0.04); k += 0.35
			ci.draw_rect(Rect2(cr.position.x, cr.position.y, cr.size.x, 0.06), Art.shade(col, 0.3))

## The lighthouse on Fort Kettle Island, with its beam turning after dark.
static func draw_lighthouse(ci: CanvasItem, p: Vector2, t: float) -> void:
	Art.ellipse(ci, p + Vector2(0.6, 0.2), 1.2, 0.4, Color(0, 0, 0, 0.22))
	var hgt := 4.0
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.7, 0), p + Vector2(0.7, 0), p + Vector2(0.45, -hgt), p + Vector2(-0.45, -hgt)]), Color("#f4f2ea"))
	for k in 2:
		var y0 := -hgt * (0.25 + k * 0.4)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.66 + k * 0.1, y0), p + Vector2(0.66 - k * 0.1, y0), p + Vector2(0.62 - k * 0.1, y0 - 0.6), p + Vector2(-0.62 + k * 0.1, y0 - 0.6)]), Color("#c0392b"))
	ci.draw_rect(Rect2(p.x - 0.6, p.y - hgt - 0.15, 1.2, 0.2), Color("#22313a"))
	ci.draw_rect(Rect2(p.x - 0.35, p.y - hgt - 0.9, 0.7, 0.75), Color("#f6e7a0") if Game.darkness() > 0.3 else Color("#cfe8f4"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.45, -hgt - 0.9), p + Vector2(0.45, -hgt - 0.9), p + Vector2(0, -hgt - 1.4)]), Color("#c0392b"))

## The lighthouse beam (on the glow layer, after dark).
static func draw_beam(ci: CanvasItem, p: Vector2, t: float, a: float) -> void:
	if a <= 0.01: return
	var c := p + Vector2(0, -4.5)
	var ang := t * 0.8
	var dir := Vector2.from_angle(ang)
	var sd := dir.orthogonal()
	var far := 22.0
	var w := 2.6
	ci.draw_polygon(PackedVector2Array([c, c + dir * far + sd * w, c + dir * far - sd * w]),
		PackedColorArray([Color(1, 0.95, 0.75, 0.32 * a), Color(1, 0.95, 0.75, 0.0), Color(1, 0.95, 0.75, 0.0)]))
