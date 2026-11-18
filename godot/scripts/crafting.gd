class_name Crafting
extends RefCounted
## Home-made lures. Parts lie around town (a glint on the ground you pick up with E, back
## every couple of days) and come out of junk you strip at Lou's. At the workbench at home
## they become four lures that fish like a bait and fall apart after a few catches.
## Save state: S.parts {part id: count}, S.lures {lure id: catches left}, S.picked {spot index: day}.

const PARTS := {
	"p_spoon": "Bent spoon", "p_caps": "Bottle caps", "p_beads": "Beads", "p_feather": "Gull feather",
	"p_wire": "Copper wire", "p_glow": "Glow stick",
	"p_glass": "Fiberglass blank", "p_graphite": "Graphite shaft", "p_reel": "Rusty spinning reel", "p_bigreel": "Old baitcaster reel",
	"p_cork": "Wine corks", "p_foam": "Pool noodle" }

## A home-built rod is one blank, one reel and one grip. t: how fast tension builds (lower is
## better), r: how fast you reel, hook: extra time to set the hook, lvl: which shop rod it counts as
## (a home rod is never the garage-sale rod, so legends bite as well as on a bought one).
const ROD_SLOTS := [
	["blank", "Blank", [
		{ "id": "p_glass", "n": "Fiberglass", "t": 0.82, "lvl": 1, "ds": "Bendy and forgiving." },
		{ "id": "p_graphite", "n": "Graphite", "t": 0.68, "lvl": 2, "ds": "Light and stiff. Tension builds much slower." }]],
	["reel", "Reel", [
		{ "id": "p_reel", "n": "Spinning reel", "r": 1.22, "hook": 0.1, "ds": "Cleaned up, it spins fine." },
		{ "id": "p_bigreel", "n": "Baitcaster", "r": 1.42, "hook": 0.25, "ds": "Winds in fast, and you get longer to set the hook." }]],
	["grip", "Grip", [
		{ "id": "", "n": "Duct tape", "ds": "Free. It's a grip." },
		{ "id": "p_cork", "n": "Cork", "r": 0.06, "needs": 3, "ds": "Three wine corks. A little faster reeling." },
		{ "id": "p_foam", "n": "Foam", "t": -0.04, "ds": "Cut from a pool noodle. A little less tension." }]],
]

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
	[14, "p_feather"], [3, "p_feather"], [10, "p_beads"], [6, "p_glow"], [12, "p_wire"], [11, "p_beads"], [16, "p_spoon"],
	# rod parts (v0.9.9)
	[2, "p_glass"], [9, "p_glass"], [3, "p_graphite"], [13, "p_graphite"], [14, "p_reel"], [12, "p_reel"],
	[16, "p_bigreel"], [6, "p_bigreel"], [17, "p_cork"], [13, "p_cork"], [10, "p_foam"], [11, "p_foam"]]
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
	var seen := {}
	for s in SPOTS:
		var r: int = s[0]
		var k: int = seen.get(r, 0); seen[r] = k + 1   # a second spot on the same water goes elsewhere on the bank
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
				if k > 0 and spots.any(func(sp): return Vector2(q).distance_to(sp[0]) < 3.0): continue
				var dd := Vector2(q).distance_to(c) + Town.hash2(q.x * 7 + k * 31, q.y * 13 + k * 17) * (3.0 + k * 40.0)
				if dd < bd: bd = dd; best = Vector2(q) + Vector2(0.5, 0.5)
		if best.x >= 0: spots.append([best, s[1]])
	spots.append([LOU_SPOT, "p_caps"])

static func _solid(x: int, y: int) -> bool:
	var t: int = Town.tile[Town.idx(x, y)]
	return t in Town.BLOCK or t == Town.T.GRATE or t == Town.T.PGATE or t == Town.T.HGATE or t == Town.T.DOOR

static func available(i: int) -> bool:
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
	var n := 2 if p in ["p_caps", "p_cork"] else 1
	Game.S.parts[p] = count(p) + n
	var first: bool = not Game.S.get("found_part", false)
	Game.S.found_part = true
	Game.save_game()
	return "You found %s%s. (%s: %d)%s" % ["two " if n == 2 else "", PARTS[p].to_lower() if n == 2 else _a(PARTS[p]), PARTS[p], count(p),
		" Make lures and rods from parts at the workbench at home." if first else ""]

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
	[["Phone", "Hard Hat", "VHS", "Weather Balloon"], "p_glow"],
	[["Message in a Bottle"], "p_cork"], [["Paddle"], "p_glass"],
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

# ---------- home-built rods ----------

static func slot_opt(slot: int, id: String) -> Dictionary:
	for o in ROD_SLOTS[slot][2]:
		if o.id == id: return o
	return {}

static func opt_need(o: Dictionary) -> int: return 0 if o.id == "" else int(o.get("needs", 1))
static func has_opt(o: Dictionary) -> bool: return count(o.id) >= opt_need(o) if o.id != "" else true

## The rod a pick of [blank id, reel id, grip id] makes.
static func rod_stats(pick: Array) -> Dictionary:
	var b := slot_opt(0, pick[0]); var rl := slot_opt(1, pick[1]); var g := slot_opt(2, pick[2])
	return { "t": float(b.get("t", 1.0)) + float(g.get("t", 0.0)), "r": float(rl.get("r", 1.0)) + float(g.get("r", 0.0)),
		"hook": float(rl.get("hook", 0.0)), "lvl": int(b.get("lvl", 1)),
		"blank": pick[0], "reel": pick[1], "grip": pick[2],
		"name": "Home-built %s rod" % str(b.get("n", "")).to_lower() }

static func can_build(pick: Array) -> bool:
	for i in 3:
		var o := slot_opt(i, pick[i])
		if o.is_empty() or not has_opt(o): return false
	return true

static func build_rod(pick: Array) -> void:
	if not can_build(pick): return
	for i in 3:
		var o := slot_opt(i, pick[i])
		if o.id != "": Game.S.parts[o.id] = count(o.id) - opt_need(o)
	Game.S.homerod = rod_stats(pick)
	Game.S.use_home = true
	Game.save_game()

## "Tension builds 32% slower · reels 42% faster", compared with the garage-sale rod.
static func stat_text(st: Dictionary) -> String:
	var out := ["Tension builds %d%% slower" % roundi((1.0 - float(st.t)) * 100), "reels %d%% faster" % roundi((float(st.r) - 1.0) * 100)]
	if float(st.get("hook", 0)) >= 0.2: out.append("more time to hook")
	return " · ".join(out)
