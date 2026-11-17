class_name Unlocks
## The town opens up in four steps, so a new player isn't dropped into the whole map at once.
##   1. Home waters: home, Lou's, Maple Park Pond and Mullet Canal (everything north of the
##      canal road), but not the golf course or the koi plaza.
##   2. Catch 5 kinds of fish and fill one of Lou's orders: the public water opens (Back Canal,
##      Low Street, downtown, the river, Bayfront Park, Mullet Bay and the marina).
##   3. Catch 10 kinds of fish: Lou's sneaking lesson, and the golf course, the koi pond and
##      Heron Lakes open.
##   4. Land a fish from a guarded spot: everything else (power station, storm drain,
##      Sunsplash, the airport, Marlowe Tower and offshore).
## Game.S.unlock holds the step. Saves from before this existed load fully open.

const LAST := 4
const SPECIES_2 := 5
const SPECIES_3 := 10
const GUARDED := [3, 4, 11]              # Pelican Point, the koi pond, Heron Lakes
## spot (region id) -> the step that opens it
const SPOT_STEP := { 1: 1, 2: 1, 3: 3, 4: 3, 5: 4, 6: 4, 7: 2, 8: 4, 9: 2, 10: 4, 11: 3, 12: 4, 13: 2, 14: 2, 15: 4, 16: 4, 17: 2 }
const NEWS := ["", "", "Road Crews Reopen Canal Road; Downtown 'Technically Reachable Again'",
	"Golf Course Groundskeeper Reports 'Shadowy Figure With Tackle Box'", "Last 'Road Closed' Sign Removed; Port Mullet Fully Open, Officials Confirm"]

static var need: PackedByteArray = PackedByteArray()

static func step() -> int: return int(Game.S.get("unlock", LAST))

## The step each tile opens at, worked out once from the town's zones.
static func _build() -> void:
	need.resize(Town.MW * Town.MH)
	for y in Town.MH:
		for x in Town.MW:
			var i := Town.idx(x, y)
			var z: int = Town.zone[i]
			var s := 1 if y < 58 else 2
			if z in [1, 2, 6]: s = 3
			elif z in [3, 4, 5, 7, 8]: s = 4
			if Town.tile[i] == Town.T.DEEP: s = 4
			need[i] = s

static func need_at(x: int, y: int) -> int:
	if need.is_empty(): _build()
	if not Town.inb(x, y): return 1
	return need[Town.idx(x, y)]

static func open_at(x: int, y: int) -> bool: return need_at(x, y) <= step()
static func open_p(p: Vector2) -> bool: return open_at(floori(p.x), floori(p.y))
static func spot_open(spot: int) -> bool: return int(SPOT_STEP.get(spot, 1)) <= step()

## What the player has to do to open the next part of town, or "" when it's all open.
static func goal() -> String:
	match step():
		1:
			var got := Story.species_got()
			var parts := []
			if got < SPECIES_2: parts.append("catch %d kinds of fish (%d/%d)" % [SPECIES_2, got, SPECIES_2])
			if int(Game.S.stats.orders) < 1: parts.append("fill one of Lou's orders")
			return "To open more of town: " + " and ".join(parts)
		2: return "To open more of town: catch %d kinds of fish (%d/%d)" % [SPECIES_3, Story.species_got(), SPECIES_3]
		3: return "To open the whole town: land a fish at the golf course, the koi pond or Heron Lakes"
	return ""

## Short form for the top-left chip.
static func chip() -> String:
	match step():
		1:
			var got := Story.species_got()
			if got < SPECIES_2: return "Map: catch %d kinds of fish (%d/%d)" % [SPECIES_2, got, SPECIES_2]
			if int(Game.S.stats.orders) < 1: return "Map: fill one of Lou's orders"
		2: return "Map: catch %d kinds of fish (%d/%d)" % [SPECIES_3, Story.species_got(), SPECIES_3]
		3: return "Map: land a fish where the guards are"
	return ""

## Records a guarded catch; the step itself moves on in ready().
static func on_catch(c: Dictionary) -> void:
	if int(c.spot) in GUARDED: Game.S.guarded_catch = true

## True when the player has earned the next step.
static func ready() -> bool:
	match step():
		1: return Story.species_got() >= SPECIES_2 and int(Game.S.stats.orders) >= 1
		2: return Story.species_got() >= SPECIES_3
		3: return Game.S.get("guarded_catch", false)
	return false

## Moves to the next step and returns the card that announces it.
static func advance(close: Callable) -> Array:
	Game.S.unlock = step() + 1
	var s := step()
	Game.add_news(NEWS[s])
	Game.save_game()
	var ok := [["Let's go", func(): close.call(); Game.hint.emit("The map (M) shows what's open now."), true, "hot"]]
	match s:
		2: return [["h3", "Map unlocked · Lou's Bait & Tackle"], ["h2", "\"You know your baits now.\""],
			["p", "Lou leans on the counter. \"Five kinds of fish and an order filled. Not bad. The road crews just pulled the barricades off Canal Road, so the rest of the public water is yours.\""],
			["quote", "\"Worms catch a bit of everything. Bread for mullet, tilapia and koi. Hot dogs for catfish. Lures for bass. Live shrimp for snook, tarpon and redfish. Press B to switch.\""],
			["sub", "Open now: Back Canal, Low Street at king tide, the Downtown River, Bayfront Park, Mullet Bay, the pier and the marina. Take the $2 bus out front if it's too far to walk."],
			["row", ok]]
		3: return [["h3", "Map unlocked · Lou's Bait & Tackle"], ["h2", "\"Time you learned to sneak.\""],
			["p", "\"Ten kinds of fish. Now the good water is behind a fence. Start with Pelican Point, the golf course. The groundskeeper's got a cone where he's looking. Stay out of it.\""],
			["quote", "\"See the yellow cone in front of a guard? That's where he's looking. Walls, buildings and trees block it, and bushes hide you. A golf polo gets you past him by day, and he goes home at 7 PM.\""],
			["sub", "Open now: Pelican Point Lake, the Sunrise koi pond and Heron Lakes. Get caught and you pay a fine that goes up every time."],
			["row", ok]]
		4: return [["h3", "Map unlocked · the whole town"], ["h2", "\"Nobody saw a thing.\""],
			["p", "\"You fished a guarded pond and walked out with the fish,\" Lou says. \"Then you're ready for the rest of it.\""],
			["quote", "\"The power station, the storm drain, the theme park, the airport, the tower downtown, and blue water offshore. Bring the right gear for each one. I sell most of it.\""],
			["sub", "Every road is open. Waders and a flashlight for the storm drain, a Geiger counter for the outflow, the skiff for offshore."],
			["row", ok]]
	return []

## Barricades on the edge of the closed part of town: striped sawhorses on land, a buoy line on water.
static func draw_barriers(ci: CanvasItem, view: Rect2) -> void:
	if step() >= LAST: return
	var x0 := maxi(0, floori(view.position.x)); var x1 := mini(Town.MW - 1, ceili(view.end.x))
	var y0 := maxi(0, floori(view.position.y)); var y1 := mini(Town.MH - 1, ceili(view.end.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if open_at(x, y): continue
			var t: int = Town.tile[Town.idx(x, y)]
			var water := Town.is_water_t(t)
			if not water and t in Town.BLOCK: continue
			var edge := false
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				if not Town.inb(nx, ny) or not open_at(nx, ny): continue
				var nt: int = Town.tile[Town.idx(nx, ny)]
				if Town.is_water_t(nt) == water and (water or not (nt in Town.BLOCK)): edge = true
			if not edge: continue
			if water:
				ci.draw_line(Vector2(x, y + 0.5), Vector2(x + 1, y + 0.5), Color(1, 1, 1, 0.8), 0.04)
				for k in 2: ci.draw_circle(Vector2(x + 0.25 + k * 0.5, y + 0.5), 0.13, Color("#f2873a"))
			else:
				var r := Rect2(x + 0.06, y + 0.32, 0.88, 0.3)
				ci.draw_rect(Rect2(x + 0.12, y + 0.55, 0.08, 0.35), Color("#5a4632"))
				ci.draw_rect(Rect2(x + 0.8, y + 0.55, 0.08, 0.35), Color("#5a4632"))
				ci.draw_rect(r, Color("#f4efe4"))
				for k in 3: ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 0.1 + k * 0.3, y + 0.62), Vector2(x + 0.25 + k * 0.3, y + 0.32), Vector2(x + 0.38 + k * 0.3, y + 0.32), Vector2(x + 0.23 + k * 0.3, y + 0.62)]), Color("#e2583e"))
				ci.draw_rect(r, Color("#22313a"), false, 0.03)

## The closed part of town as a grey overlay for the map.
static func map_overlay() -> ImageTexture:
	var img := Image.create(Town.MW, Town.MH, false, Image.FORMAT_RGBA8)
	for y in Town.MH:
		for x in Town.MW:
			if not open_at(x, y): img.set_pixel(x, y, Color(0.28, 0.3, 0.33, 0.72))
	return ImageTexture.create_from_image(img)
