class_name Buyers
extends RefCounted
## Fish buyers besides Lou and Dot: a restaurant and a fish market in each town, read from
## data/buyers.json so a new town only needs its own entries there.
##
## A restaurant ("restaurant") has a chef who buys only fish caught today, only species on
## today's menu, and only a few a day. Menu fish pay more than Lou, and the catch of the day
## pays most. A restaurant can have a fish fry day (fry_day: day % 7) with a longer menu,
## better pay and a bigger kitchen.
##
## A fish market ("market") buys any fish, at prices that change every morning. A price board
## by the door shows today's prices: a few species HOT, a few CHEAP, the rest about what Lou
## pays. Fish that aren't on the board pay offlist, and yesterday's catch pays dayold. Species
## in smoke (the smokehouse's rough fish) never go cheap.
##
## Lou and Dot stay the baseline: they buy everything, junk too, at the same price every day.

const DATA := "res://data/buyers.json"
const HOT_N := 3
const CHEAP_N := 3

static var _data := {}
static var _pp := {}    # town level -> { species: Lou's price per pound there }

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_data = d if d is Dictionary else { "_": true }
	return _data

## The buyers in the town you're in.
static func here() -> Array: return data().get(str(Town.level), [])

static func by_id(id: String) -> Dictionary:
	for b in here():
		if b.id == id: return b
	return {}

## Who buys at the same price every day in this town.
static func baseline() -> String: return "Dot" if Town.level == 1 else "Lou"

## The door is in the middle of the bottom row of the building.
static func door_tile(b: Dictionary) -> Vector2i:
	var r: Array = b.bld
	if b.has("door"): return Vector2i(int(b.door[0]), int(b.door[1]))
	return Vector2i(int(r[0]) + int(r[2]) / 2, int(r[1]) + int(r[3]) - 1)

## Where you stand to go in: just outside the door.
static func door(b: Dictionary) -> Vector2:
	var t := door_tile(b)
	return Vector2(t.x + 0.5, t.y + 1.4)

static func board_at(b: Dictionary) -> Vector2:
	return Vector2(float(b.board[0]), float(b.board[1])) if b.has("board") else Vector2(-99, -99)

## Puts this town's buyers on the map. Town.build() calls this once the town is laid out.
static func place() -> void:
	for b in here():
		var r: Array = b.bld
		Town.bld(int(r[0]), int(r[1]), int(r[2]), int(r[3]), b.color, b.style, String(b.name).to_upper(), { "buyer": b.id })
		var t := door_tile(b)
		Town.set_t(t.x, t.y, Town.T.DOOR)
		# no street lamp standing inside it, or in front of its door or its board
		var keep := Rect2(int(r[0]), int(r[1]), int(r[2]), int(r[3])).grow(0.5)
		Town.lamps = Town.lamps.filter(func(l): return not keep.has_point(l) and l.distance_to(door(b)) > 1.2 and l.distance_to(board_at(b)) > 1.2)

# ---------- hours ----------

static func open_now(b: Dictionary) -> bool:
	var h := Game.hour()
	return h >= float(b.hours[0]) and h < float(b.hours[1])

static func _clock(h: float) -> String:
	var hh := int(h) % 24
	return "%d %s" % [12 if hh % 12 == 0 else hh % 12, "AM" if hh < 12 else "PM"]

static func hours_text(b: Dictionary) -> String: return "%s to %s" % [_clock(b.hours[0]), _clock(b.hours[1])]

## Fish fry day at a restaurant that has one (the Tailrace's is Friday, the day before the Slam).
static func fry_day(b: Dictionary, day := -1) -> bool:
	if day < 0: day = int(Game.S.day)
	return b.has("fry_day") and day % 7 == int(b.fry_day)

static func days_to_fry(b: Dictionary) -> int:
	if not b.has("fry_day"): return -1
	return posmod(int(b.fry_day) - int(Game.S.day) % 7, 7)

# ---------- restaurants ----------

static func _salt(b: Dictionary) -> int: return absi(String(b.id).hash()) % 997

## Today's menu: a few species from the chef's list, different every day.
static func menu(b: Dictionary, day := -1) -> Array:
	if day < 0: day = int(Game.S.day)
	var pool: Array = b.menu.keys()
	var s := _salt(b)
	pool.sort_custom(func(x, y): return Town.hash2(day * 31 + s, String(x).hash() % 9973) < Town.hash2(day * 31 + s, String(y).hash() % 9973))
	var n := int(b.get("fry_dishes", 4)) if fry_day(b, day) else int(b.get("dishes_a_day", 4))
	return pool.slice(0, mini(n, pool.size()))

## The catch of the day: the one menu fish the chef needs most.
static func special(b: Dictionary, day := -1) -> String:
	var m := menu(b, day)
	if m.is_empty(): return ""
	if day < 0: day = int(Game.S.day)
	return m[int(Town.hash2(day * 17 + _salt(b), 3) * m.size()) % m.size()]

static func pay_mult(b: Dictionary, species: String) -> float:
	if species == special(b): return float(b.special)
	return float(b.fry_fresh) if fry_day(b) and b.has("fry_fresh") else float(b.fresh)

static func cap(b: Dictionary) -> int:
	return int(b.fry_cap) if fry_day(b) and b.has("fry_cap") else int(b.get("cap", 6))

## How many fish the kitchen has bought today.
static func bought(b: Dictionary) -> int:
	var st: Dictionary = Game.S.get("buyers", {}).get(b.id, {})
	return int(st.get("n", 0)) if int(st.get("day", 0)) == int(Game.S.day) else 0

static func room(b: Dictionary) -> int: return maxi(0, cap(b) - bought(b)) if b.kind == "restaurant" else 999

# ---------- markets ----------

## Lou's price per pound for each species in this town, for the board.
static func _price_per_lb(species: String) -> float:
	var lv := Town.level
	if not _pp.has(lv):
		var m := {}
		for sid in Game.spots:
			if (int(sid) >= 20) != (lv == 1): continue
			for f in Game.spots[sid].fish:
				if f.has("pp") and not m.has(f.n): m[f.n] = float(f.pp)
		_pp[lv] = m
	return float(_pp[lv].get(species, 0.0))

## Today's board: [[species, multiplier, "hot" | "cheap" | "", price per pound]], hot first.
static func board(b: Dictionary, day := -1) -> Array:
	if day < 0: day = int(Game.S.day)
	var fish: Array = b.get("board_fish", [])
	var s := _salt(b)
	var order := range(fish.size())
	order.sort_custom(func(i, j): return Town.hash2(day * 7 + s, i * 13 + 5) < Town.hash2(day * 7 + s, j * 13 + 5))
	var smoke: Array = b.get("smoke", [])
	var out := []
	for k in order.size():
		var i: int = order[k]
		var n: String = fish[i]
		var h := Town.hash2(day * 11 + i, s + 41)
		var m: float
		var tag := ""
		if k < HOT_N: m = 1.6 + 0.4 * h; tag = "hot"
		elif k >= order.size() - CHEAP_N: m = 0.45 + 0.2 * h; tag = "cheap"
		else: m = 0.85 + 0.3 * h
		if n in smoke and m < 1.1: m = 1.1; tag = ""
		m = snappedf(m, 0.05)
		out.append([n, m, tag, _price_per_lb(n) * m])
	var rank := { "hot": 0, "": 1, "cheap": 2 }
	out.sort_custom(func(x, y): return rank[x[2]] < rank[y[2]] or (rank[x[2]] == rank[y[2]] and x[1] > y[1]))
	return out

static func board_mult(b: Dictionary, species: String) -> float:
	for row in board(b):
		if row[0] == species: return row[1]
	return -1.0

# ---------- offers ----------

## What this buyer pays for a fish in your cooler: [price, why not / note]. Price 0 means no sale.
static func offer(b: Dictionary, c: Dictionary) -> Array:
	var base := baseline()
	if c.get("junk", false): return [0, "%s buys junk. Nobody else does." % base]
	if c.get("legend", false): return [0, "A legend. That goes on %s's wall, not on ice." % base]
	var today := int(c.get("day", 0)) == int(Game.S.day)
	if b.kind == "restaurant":
		if not (c.n in menu(b)): return [0, "Not on today's menu"]
		if not today: return [0, "Caught yesterday. %s only cooks today's catch." % b.who]
		var m := pay_mult(b, c.n)
		return [maxi(1, ceili(int(c.value) * m)), ("Catch of the day, %s×" if c.n == special(b) else "Fresh, on the menu, %s×") % _x(m)]
	var m := board_mult(b, c.n)
	var note := ""
	if m < 0:
		m = float(b.get("offlist", 0.7)); note = "Not on the board, %s×" % _x(m)
	else:
		var tag := ""
		for row in board(b):
			if row[0] == c.n: tag = row[2]
		note = ("HOT today, %s×" if tag == "hot" else "Cheap today, %s×" if tag == "cheap" else "Today's price, %s×") % _x(m)
	if not today:
		m *= float(b.get("dayold", 0.75)); note += ", day-old"
	return [maxi(1, roundi(int(c.value) * m)), note]

static func _x(m: float) -> String:
	var s := "%.2f" % m
	return s.trim_suffix("0").trim_suffix("0").trim_suffix(".")

## Everything in the cooler this buyer would take right now, best first, up to what the kitchen has room for.
static func takes(b: Dictionary) -> Array:
	var out := []
	for c in Game.S.cooler:
		var o := offer(b, c)
		if int(o[0]) > 0: out.append([c, int(o[0])])
	out.sort_custom(func(x, y): return x[1] > y[1])
	return out.slice(0, mini(out.size(), room(b)))

## Sells these cooler entries to b. Returns the total paid.
static func sell(b: Dictionary, cs: Array) -> int:
	var total := 0
	var n := 0
	for c in cs:
		if room(b) - n <= 0: break
		var o := offer(b, c)
		if int(o[0]) <= 0: continue
		total += int(o[0]); n += 1
		Game.S.cooler.erase(c)
	if n == 0: return 0
	Game.S.cash += total
	if not Game.S.has("buyers"): Game.S.buyers = {}
	var st: Dictionary = Game.S.buyers.get(b.id, {})
	if int(st.get("day", 0)) != int(Game.S.day): st = { "day": int(Game.S.day), "n": 0 }
	st.n = int(st.n) + n
	st.total = int(st.get("total", 0)) + total
	Game.S.buyers[b.id] = st
	return total

# ---------- talk ----------

static var _talk := {}

static func greeting(b: Dictionary) -> String: return b.greet.pick_random()

## What the chef or fishmonger says when you ask: a line about today if it fits, otherwise the next one.
static func talk_line(b: Dictionary) -> String:
	var i: int = int(_talk.get(b.id, -1)) + 1
	_talk[b.id] = i
	var ctx := []
	if b.kind == "restaurant":
		var sp := special(b)
		if sp != "": ctx.append("Today I need %s. %s. Bring me one caught today and I'll pay you %s times what %s does." % [sp.to_lower(), b.menu[sp], _x(float(b.special)), baseline()])
		if fry_day(b): ctx.append("It's Friday, hon. Fish fry. I'll take twice as many and pay better. Go!")
		elif b.has("fry_day"): ctx.append("Fish fry is Friday, %s. Bring walleye and perch." % ("tomorrow" if days_to_fry(b) == 1 else "in %d days" % days_to_fry(b)))
	else:
		var bd := board(b)
		if bd.size() > 0: ctx.append("%s is hot today. Everybody's calling for it. %s, though? I'm drowning in it." % [bd[0][0], bd[bd.size() - 1][0]])
	if i % 3 == 2 and not ctx.is_empty(): return ctx.pick_random()
	return b.talk[(i - i / 3) % b.talk.size()]
