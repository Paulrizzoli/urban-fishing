class_name Crafting
extends RefCounted
## Home-made lures. Parts lie around town (a glint on the ground you pick up with E, back
## every couple of days) and come out of junk you strip at Lou's. At the workbench at home
## they become four lures that fish like a bait and fall apart after a few catches.
## Save state: S.parts {part id: count}, S.lures {lure id: catches left}, S.picked {spot index: day}.

const PARTS := {
	"p_spoon": "Bent spoon", "p_caps": "Bottle caps", "p_beads": "Beads", "p_feather": "Gull feather",
	"p_wire": "Copper wire", "p_glow": "Glow stick" }

const LURES := [
	{ "id": "spoon", "n": "Spoon lure", "needs": { "p_spoon": 1, "p_wire": 1 }, "uses": 6,
		"ds": "A diner spoon with the handle cut off. Flashes like a baitfish. Snook, redfish, jacks, trout, snapper and the saltwater crowd chase it.",
		"likes": ["Snook", "Snook XL", "Redfish", "Jack Crevalle", "Spotted Seatrout", "Mangrove Snapper", "Ladyfish", "Barracuda", "Kingfish", "Tarpon", "Parking Lot Tarpon", "Pinfish", "Mahi-Mahi", "The Gray Ghost"] },
	{ "id": "popper", "n": "Bottle-cap popper", "needs": { "p_caps": 2, "p_beads": 1 }, "uses": 6,
		"ds": "Two caps that chug and spit across the top. Bass of every kind, peacocks, bowfin, snakeheads and cichlids hit it.",
		"likes": ["Largemouth Bass", "Peacock Bass", "Glowing Bass", "Bowfin", "Bullseye Snakehead", "Mayan Cichlid", "Oscar", "Florida Gar", "The Lunker of the 7th", "Snook"] },
	{ "id": "jig", "n": "Feather jig", "needs": { "p_feather": 1, "p_beads": 1 }, "uses": 8,
		"ds": "A gull feather tied on a bead head. Nothing loves it, nothing minds it: everything bites a bit better.",
		"likes": [] },
	{ "id": "glowlure", "n": "Glow lure", "needs": { "p_glow": 1, "p_wire": 1, "p_beads": 1 }, "uses": 5,
		"ds": "Glow-stick goo in a bead body. After dark everything comes to look. In daylight it's just a lure.",
		"likes": ["Glowing Bass", "Three-Eyed Tilapia", "Two-Headed Catfish", "Glow-in-the-Dark Shrimp", "The Isotope"] },
]

## Where parts turn up: [fishing spot (region) whose bank it's on, part]. Lou's is a fixed spot.
const SPOTS := [[1, "p_caps"], [2, "p_wire"], [9, "p_spoon"], [13, "p_spoon"], [17, "p_beads"],
	[14, "p_feather"], [3, "p_feather"], [10, "p_beads"], [6, "p_glow"], [12, "p_wire"], [11, "p_beads"], [16, "p_spoon"]]
const LOU_SPOT := Vector2(52.4, 33.4)
const RESPAWN_DAYS := 2

static var spots: Array = []   # [[Vector2 position, part id], ...] worked out once from the map

static func lure(id: String) -> Dictionary:
	for l in LURES:
		if l.id == id: return l
	return {}

static func is_lure(id: String) -> bool: return not lure(id).is_empty()

static func parts() -> Dictionary: return Game.S.get("parts", {})
static func count(p: String) -> int: return int(parts().get(p, 0))
static func left(id: String) -> int: return int(Game.S.get("lures", {}).get(id, 0))

static func can_make(l: Dictionary) -> bool:
	for p in l.needs:
		if count(p) < int(l.needs[p]): return false
	return true

static func make(id: String) -> void:
	var l := lure(id)
	if l.is_empty() or not can_make(l): return
	for p in l.needs: Game.S.parts[p] = count(p) - int(l.needs[p])
	if not Game.S.has("lures"): Game.S.lures = {}
	Game.S.lures[id] = left(id) + int(l.uses)
	Game.S.bait = id
	Game.save_game()

## How much a home-made lure on the line changes a fish's interest (like Game.bait_mul).
static func mul(f: Dictionary) -> float:
	var l := lure(Game.S.bait)
	match l.id:
		"jig": return 1.5
		"glowlure": return 2.3 if Game.time_band() == "night" or f.n in l.likes else 0.8
	return 2.3 if f.n in l.likes else 0.55

## A fish came in on the current bait: wear the lure down. Returns a message when it breaks.
static func wear(c: Dictionary) -> String:
	var id: String = Game.S.bait
	if not is_lure(id) or c.get("junk", false): return ""
	Game.S.lures[id] = maxi(0, left(id) - 1)
	if left(id) > 0: return ""
	Game.S.bait = "worms"
	return "Your %s finally falls apart. Back to worms. Make another at the workbench at home." % lure(id).n.to_lower()

# ---------- parts around town ----------

static func build_spots() -> void:
	spots = []
	var cands := {}
	for y in Town.MH:
		for x in Town.MW:
			var r: int = Town.region[Town.idx(x, y)]
			if r > 0 and Town.is_water_t(Town.tile[Town.idx(x, y)]):
				if not cands.has(r): cands[r] = []
				cands[r].append(Vector2i(x, y))
	for s in SPOTS:
		var r: int = s[0]
		if not cands.has(r): continue
		var c := Vector2.ZERO
		for t in cands[r]: c += Vector2(t)
		c /= cands[r].size()
		# the bank tile closest to the middle of the water, nudged by a hash so it's not always due north
		var best := Vector2(-1, -1); var bd := INF
		for t in cands[r]:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = t + d
				if not Town.inb(q.x, q.y) or _solid(q.x, q.y): continue
				var dd := Vector2(q).distance_to(c) + Town.hash2(q.x * 7, q.y * 13) * 3.0
				if dd < bd: bd = dd; best = Vector2(q) + Vector2(0.5, 0.5)
		if best.x >= 0: spots.append([best, s[1]])
	spots.append([LOU_SPOT, "p_caps"])

static func _solid(x: int, y: int) -> bool:
	var t: int = Town.tile[Town.idx(x, y)]
	return t in Town.BLOCK or t == Town.T.GRATE or t == Town.T.PGATE or t == Town.T.HGATE or t == Town.T.DOOR

static func available(i: int) -> bool:
	var p: Vector2 = spots[i][0]
	if not Unlocks.open_at(floori(p.x), floori(p.y)): return false
	return int(Game.S.get("picked", {}).get(str(i), -99)) + RESPAWN_DAYS <= int(Game.S.day)

## The part spot you're standing on, or -1.
static func near(pos: Vector2) -> int:
	if spots.is_empty(): build_spots()
	for i in spots.size():
		if pos.distance_to(spots[i][0]) < 0.85 and available(i): return i
	return -1

static func pick(i: int) -> String:
	var p: String = spots[i][1]
	if not Game.S.has("picked"): Game.S.picked = {}
	if not Game.S.has("parts"): Game.S.parts = {}
	Game.S.picked[str(i)] = int(Game.S.day)
	var n := 2 if p == "p_caps" else 1
	Game.S.parts[p] = count(p) + n
	var first: bool = not Game.S.get("found_part", false)
	Game.S.found_part = true
	Game.save_game()
	return "You found %s%s. (%s: %d)%s" % ["two " if n == 2 else "", PARTS[p].to_lower() if n == 2 else _a(PARTS[p]), PARTS[p], count(p),
		" Make lures from parts at the workbench at home." if first else ""]

static func _a(s: String) -> String:
	return ("an " if s[0].to_lower() in "aeiou" else "a ") + s.to_lower()

static func draw_spots(ci: CanvasItem) -> void:
	if spots.is_empty(): build_spots()
	var t := Time.get_ticks_msec() / 1000.0
	for i in spots.size():
		if not available(i): continue
		var p: Vector2 = spots[i][0]
		var k := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
		ci.draw_circle(p + Vector2(0, 0.08), 0.16, Color(0, 0, 0, 0.18))
		ci.draw_circle(p, 0.09, Color("#c9d3d8"))
		var s := 0.22 + 0.18 * k
		var col := Color(1.0, 0.92, 0.55, 0.6 + 0.4 * k)
		ci.draw_circle(p, 0.2 + 0.08 * k, Color(1.0, 0.95, 0.6, 0.18 * k))
		ci.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 0.06)
		ci.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 0.06)
		ci.draw_circle(p, 0.06, Color.WHITE)

# ---------- stripping junk ----------

const SALVAGE := [[["Bicycle", "Shopping Cart", "Scooter", "Deck Chair", "Animatronic", "Car Keys", "Retainer", "Selfie Stick", "Luggage Tag"], "p_wire"],
	[["Golf Balls", "Sunglasses", "Coins", "Penny", "Doubloon", "Gold Tooth", "Ring", "Rolex", "Peanuts"], "p_beads"],
	[["Phone", "Hard Hat", "VHS", "Weather Balloon", "Message in a Bottle"], "p_glow"],
	[["Paddle", "Valet Ticket", "Stock Certificate", "Violation Notice"], "p_spoon"]]

static func salvage_part(junk_name: String) -> String:
	for row in SALVAGE:
		for k in row[0]:
			if junk_name.contains(k): return row[1]
	return "p_caps"

static func salvage(c: Dictionary) -> String:
	var p := salvage_part(str(c.n))
	if not Game.S.has("parts"): Game.S.parts = {}
	Game.S.parts[p] = count(p) + 1
	Game.S.cooler.erase(c)
	Game.save_game()
	return "You strip the %s and keep %s." % [str(c.n).to_lower(), _a(PARTS[p])]
