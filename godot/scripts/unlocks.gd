class_name Unlocks
## Every place in Port Mullet is open from day one. What keeps you out is gear or people:
##   - gear: waders and a flashlight for the storm drain, a pry bar for the manholes,
##     a kayak for the back channels and the skiff for offshore
##   - people: guards, staff, cameras and floodlights, each with their own hours, so a
##     guarded place is for when they're away, or for when you've got the right disguise.
## This file keeps the early-game teaching: Lou's tips and easy first orders while you're
## learning, Lou's sneaking lesson the first time you walk onto guarded ground, and a line
## about who's watching whenever you walk into a guarded place.
## Saves from before v0.9.26 still carry the old "unlock" step; nothing reads it any more.

## While you've caught fewer kinds of fish than this, or haven't filled an order yet,
## Lou gives tips in the Sell tab and keeps his orders easy.
const SPECIES_EARLY := 5
## Public water you can fish from day one with no gear and nobody chasing you off.
const EASY := [1, 2, 9, 13, 14, 17]
## Zones with guards, staff or cameras (golf course, office park, power station, Sunsplash,
## Heron Lakes, the airport, Marlowe Tower). The marina docks only count at night.
const GUARDED_ZONES := [1, 2, 3, 5, 6, 7, 8, 20, 21, 22, 23, 30, 31, 32, 33]

## Who's watching each guarded zone and when it's your turn. Shown when you walk in.
const WATCH := {
	1: "Pelican Point golf course. The groundskeeper drives his cart around 6 AM to 7 PM. Come after dark, or wear a golf polo from Lou's.",
	2: "Sunrise Executive Park. Security walks the koi plaza day and night, but sees less after dark. A lanyard from Lou's gets you past him 8 AM to 6 PM.",
	3: "The power station. A gate guard and cameras around the clock, and a floodlight 8 PM to 5 AM. Plant security takes his coffee break 2 to 2:30 AM. Watch the camera sweeps.",
	5: "Sunsplash Jungle. Open 9 AM to 6 PM for $8, and staff sweep the park at closing. A night guard walks it 7 PM to 6 AM. Hide in the restroom at closing and the lagoon is yours for a while.",
	6: "Heron Lakes. Slip in behind a resident's car, or paddle up the back channel. The HOA president walks the pond 7 AM to 9 PM.",
	7: "The airport. A gate guard and a patrol truck around the clock, and a tower spotlight 7 PM to 6 AM. When a jet comes over, nobody's watching.",
	8: "Marlowe Tower. A lobby guard until 10 PM, a patrol and cameras all night. A suit gets you past the patrol 8 AM to 6 PM.",
	9: "Mullet Bay Marina. The docks are private after 9 PM: a watchman and his dog walk them until 5 AM.",
	20: "The Ironwater Dam wing walls, right over the boil. Restricted. The ranger walks the west wall 6 AM to 9 PM, and cameras sweep both walls around the clock.",
	21: "The old Halvorsen Woolen Mill. A demolition site: the foreman walks it 7 AM to 5 PM (a lanyard gets you past him), and a watchman and his dog take over 9 PM to 5 AM.",
	22: "Calder Brewing. Security walks the cooling pond day and night. A lanyard passes for a tour badge 11 AM to 7 PM, and a camera watches the dock at night.",
	30: "The Gannet Fish Pier. The market runs 3 to 11 AM and the dockmaster walks the wharf (a lanyard passes for a buyer's badge). After eleven nobody minds you.",
	31: "Gannet Marine Terminal. Port police drive the quay day and night, and cameras ride the cranes. A lanyard passes for a port pass 7 AM to 7 PM. Watch the truck's lights.",
	32: "Skyline Commons rooftop garden. The attendant lets in anyone in a suit 8 AM to 8 PM, and security walks it 10 PM to 6 AM. From 8 to 10 at night and 6 to 8 in the morning, nobody's up here.",
	33: "The bridge tower yard. Restricted. A bridge authority officer walks it 6 AM to 10 PM, and a camera on the tower watches the yard all night.",
	23: "Riverhawks Field. The groundskeeper drives the outfield 7 AM to 5 PM (a polo gets you by), and security drives it 10 PM to 6 AM. Game time, 5 to 10 PM, nobody's looking.",
}

static func early() -> bool:
	return Story.species_got() < SPECIES_EARLY or int(Game.S.stats.orders) < 1

## True if you can fish this spot right now without gear you don't have or anyone to dodge.
static func spot_easy(sid: int) -> bool:
	return sid in EASY or (sid == 8 and Game.S.gear.has("prybar"))

## The "who's watching" line for walking into a zone right now, or "".
static func watch_note(z: int) -> String:
	if not WATCH.has(z): return ""
	if z == 30 and (Game.hour() < 3 or Game.hour() >= 11): return ""   # the fish market wharf is only watched during the market
	if z == 9:
		var h := Game.hour()
		if h < 21 and h >= 5: return ""
	return WATCH[z]

## Lou's sneaking lesson, the first time you walk onto guarded ground.
static func sneak_lesson(z: int, close: Callable) -> Array:
	return [["h3", "Lou's sneaking lesson"], ["h2", "\"Time you learned to sneak.\""],
		["p", "You remember what Lou told you. \"The good water is behind a fence. Every guard's got a cone where he's looking. Stay out of it.\""],
		["quote", "\"See the yellow cone in front of a guard? That's where he's looking. Walls, buildings and trees block it, and bushes hide you. A disguise from my shop gets you past most of them by day, and plenty of them go home at night.\""],
		["sub", WATCH.get(z, "") + " Get caught and you pay a fine that goes up every time."],
		["row", [["Got it", func(): close.call(), true, "hot"]]]]

const BAIT_WORDS := { "worms": "worms", "shrimp": "live shrimp", "lure": "a spinner lure", "hotdog": "hot dogs", "bread": "bread", "squid": "squid" }
const TIME_WORDS := { "day": "by day", "low": "at dawn and dusk", "night": "at night" }

## How Lou would tell you to catch a fish: where, on what, and when.
static func how_to_catch(f: Dictionary, sid: int) -> String:
	var where: String = "down a manhole (with a pry bar)" if sid == 8 else "in " + str(Game.spots[sid].name)
	var out := "%s: %s" % [f.n, where]
	var pref: Variant = Game.baitpref.get(f.n)
	if pref != null: out += ", on " + " or ".join(pref.map(func(b): return BAIT_WORDS.get(b, b)))
	if f.has("t"): out += ", " + " or ".join(f.t.map(func(b): return TIME_WORDS.get(b, b)))
	return out + "."

## Lou's pointers to fish you haven't caught yet on the easy public water, easiest first.
static func lou_tips(n := 4) -> Array:
	var seen := {}
	var lst := []
	for sid in Game.spots:
		if not spot_easy(sid): continue
		for f in Game.spots[sid].fish:
			if f.get("junk", false) or f.get("legend", false) or Game.S.journal.has(f.n) or seen.has(f.n): continue
			seen[f.n] = true
			lst.append([float(f.r) * (0.5 if f.has("t") else 1.0), how_to_catch(f, sid)])
	lst.sort_custom(func(a, b): return a[0] > b[0])
	return lst.slice(0, n).map(func(x): return x[1])

## Where and how to catch something that fills Lou's order, or "". Easy public water first.
static func order_tip(o: Dictionary) -> String:
	var best := []
	for sid in Game.spots:
		for f in Game.spots[sid].fish:
			if f.get("legend", false) or f.get("junk", false) or f.get("release", false): continue
			var score := float(f.r) + (1000.0 if spot_easy(sid) else 0.0)
			if Game.order_match(o, { "n": f.n, "junk": false, "w": float(f.w[1]) * 0.8, "spot": sid }) and (best.is_empty() or score > best[0]): best = [score, how_to_catch(f, sid)]
	return "" if best.is_empty() else best[1]
