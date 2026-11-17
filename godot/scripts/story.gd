class_name Story
extends RefCounted
## The two story acts (Lou's note, then Trent Marlowe), Lou's Wall of Fame plaques,
## the Mullet Bay Slam tournament, and the Port Mullet Gazette. All state lives in Game.S.

const DEBT := 5000

const SAGA := [
	{},
	{ "t": "Bad News in Boat Shoes", "goal": "Pay $200 toward Lou's note", "kind": "pay", "amt": 200,
		"intro": ["A man in boat shoes and a salmon-colored polo is leaning on Lou's counter. He doesn't buy anything.",
			"\"Chad Brickell, Brickell Coastal Development. Lou here borrowed against the shop back in '09, and the note came to me.\" He taps a folder. \"Five thousand dollars, or this becomes Mullet Pointe Luxury Residences. Ciao.\"",
			"Lou watches him go. \"I can't pay that. But you can catch fish.\" He slides a coffee can across the counter. It says THE NOTE in marker."],
		"done": "Lou counts the bills twice. \"Two hundred. It's a start. Chad called it 'adorable.'\"" },
	{ "t": "The Lunker Wall", "goal": "Catch Old Whiskers in Maple Park Pond (night)", "kind": "catch", "fish": "Old Whiskers", "reward": 500,
		"intro": ["\"Business is dead,\" Lou says. \"Nobody believes this town has big fish anymore. We need a legend on the wall.\"",
			"\"Old Whiskers. The catfish in Maple Park Pond. Night only. Catch him and every guy in the county comes in to buy whatever bait you used.\""],
		"done": "The photo of you and Old Whiskers goes up by the register. By lunch there's a line out the door. Lou drops $500 in the coffee can." },
	{ "t": "Neighborhood Watch", "goal": "Catch The Board President at Heron Lakes (day)", "kind": "catch", "fish": "The Board President", "reward": 500,
		"intro": ["\"Guess who lives in Heron Lakes,\" Lou says. \"Chad. He told the whole HOA meeting he's turning my shop into a parking lot for his condos.\"",
			"\"Their pond has a grass carp that's run that HOA since 1994. Go catch it. In Chad's own backyard. In broad daylight.\""],
		"done": "The Gazette runs your photo with the carp. The HOA fines Chad for \"letting a non-resident embarrass the board.\" His neighbors put $500 in Lou's can, out of spite." },
	{ "t": "Operation Hot Water", "goal": "Night raid: catch a mutant fish at the Power Station Outflow", "kind": "mutant", "reward": 1500,
		"intro": ["A woman in a lab coat is waiting at the counter. \"Dr. Oyelaran, from the university. I hear you go places you shouldn't.\"",
			"\"Something in the power station outflow is mutating. I need one specimen, caught at night, no questions asked. Fifteen hundred dollars.\" She sets a Geiger counter on the counter. \"Take this. If it starts screaming, leave.\"",
			"Lou leans in. \"Plant security takes his coffee break at 2 AM. They run a floodlight off the turbine hall at night. Come in through the mangroves, or paddle the culvert. And don't start glowing.\""],
		"done": "Dr. Oyelaran holds the jar up to the light. The fish waves at her. She pays $1,500 in cash and leaves very quickly." },
	{ "t": "Pay the Man", "goal": "Pay off the rest of Lou's note", "kind": "payoff",
		"intro": ["Lou empties the coffee can and counts it. \"We're close. Real close. Whatever's left is on us.\"",
			"\"Sell fish. Fill my orders. Tell some whoppers. Every dollar in that can is a dollar Chad doesn't get to keep.\""],
		"done": "Chad counts the money on the counter very slowly, like he's hoping some of it will disappear." },
	{ "t": "The Bet", "goal": "Beat Lou's 1987 record: land a fish over 142 lb", "kind": "big", "lb": 142,
		"intro": ["Chad doesn't leave. \"There's a late fee. A thousand dollars. It's in the fine print.\" It is not in the fine print.",
			"\"Or,\" he says, eyeing the tarpon over the register, \"a bet. Lou's famous 142-pounder. Everybody knows it was 80, tops. Land something over 142 pounds, on a line, in this town, and I tear up the note and leave Florida.\"",
			"Lou says quietly, \"It was 142.\" Then louder: \"Go get him something big, kid.\""],
		"done": "You slap the photo on the counter. Chad stares at it for a long time. Then he tears up the note, gets back into his boat shoes, and moves to Ohio." },
]
const SAGA_NEWS := ["", "Developer Seen Leaving Bait Shop; Lou Calls Him 'A Polo Shirt With Legs'", "Maple Park's 'Old Whiskers' Caught at Last; Bait Shop Sells Out",
	"HOA Board President Caught, Released; Board 'Will Be Reviewing This'", "University Scientist Pays Cash for 'Normal Fish, Totally Normal'", "Bait Shop Pays Off Its Note; Developer 'Weirdly Upset'"]

const ACT2 := [
	{},
	{ "t": "The Reel Deal", "goal": "Catch a fish in Mullet Bay, off the pier or the seawall downtown", "kind": "spot", "spot": 14, "reward": 150,
		"intro": ["Lou has a TV bolted over the counter now. A man with very white teeth and a shirt covered in sponsor logos holds a bass up to the camera. \"I'm Trent Marlowe, and this is REEL DEAL. This week: Port Mullet, Florida. Small town. Small fish. Small-time bait shop.\"",
			"\"He opened a megastore downtown,\" Lou says. \"FINTASTIC. Forty aisles. He says on TV that our legends were made up by a guy who sells worms.\"",
			"\"Downtown's south of the airport. Walk Canal Road or take the two-dollar bus out front. Go see the bay. Catch something off the Municipal Pier so I can tell people we fish downtown too.\""],
		"done": "Lou tapes your pier photo next to the register. \"Downtown fish. See? We go everywhere.\" He hands you $150 out of the till." },
	{ "t": "The Golden Arowana", "goal": "Catch the Golden Arowana in the Marlowe Tower pool", "kind": "catch", "fish": "The Golden Arowana", "reward": 400, "rep": 10,
		"intro": ["Trent's back on TV, standing at a reflecting pool at the foot of a glass tower. \"MARLOWE TOWER. And in my pool, the rarest fish in Florida: a Golden Arowana. Forty thousand dollars. No local yokel is ever touching it.\"",
			"Lou turns the TV off. \"You heard the man.\"",
			"\"The lobby guard goes home at 10 PM. After that it's one patrol and two cameras. In the daytime a suit gets you past the patrol, but not the lobby guy. Hide in the planters. Arowanas like lures.\""],
		"done": "The Gazette runs your photo with the arowana on the front page under the headline \"YOKEL.\" Lou has it framed. Somebody slips $400 under the shop door with a note: \"from a Marlowe Tower janitor.\"" },
	{ "t": "Sea Legs", "goal": "Buy the used skiff at Mullet Bay Marina", "kind": "gear", "gear": "skiff", "reward": 100,
		"intro": ["\"Trent does his big stuff offshore,\" Lou says. \"Sailfish. Mahi. He's got a boat with three engines and a hot tub.\"",
			"\"We need a boat. Not a kayak, a boat. The marina on the bay has a used skiff for four-fifty. Buy it and I'll put in a hundred for gas.\""],
		"done": "Lou walks all the way down to the marina just to look at it. He paints COFFEE CAN on the side and gives you $100 for gas." },
	{ "t": "The Mullet Bay Slam", "goal": "Win a Mullet Bay Slam at the marina", "kind": "tourney",
		"intro": ["\"There's a tournament at the marina every seventh day,\" Lou says. \"Trent fishes it every week, on camera, and he wins it every week. On camera.\"",
			"\"Sign up at the marina before noon on tournament day. Bring your best by 7 PM. Beat him.\""],
		"done": "Trent has to hand you the trophy on his own show. He smiles so hard a veneer cracks. Lou watches the clip eleven times." },
	{ "t": "Old Glory", "goal": "Catch Old Glory, the blue marlin, far offshore (daytime)", "kind": "catch", "fish": "Old Glory", "reward": 1000,
		"intro": ["Trent is furious on TV. \"Next week, LIVE: I land Old Glory. The marlin this whole town brags about. Eleven seasons I've been after her. This is MY week.\"",
			"Lou stands up. \"Then she's ours. Take the skiff way past the markers, in daylight. Squid, and the biggest rod you can carry. Lou's Bait & Tackle catches her first.\""],
		"done": "You come in with a photo of Old Glory next to the COFFEE CAN, and you let her go. Trent's live broadcast is forty minutes of empty ocean. Lou wins $1,000 betting against him at the VFW and gives it all to you." },
]
const ACT2_NEWS := ["", "Bait Shop Takes Downtown Pier 'By Storm,' Says Bait Shop", "Marlowe Tower Arowana Caught on Camera by Local Angler; Trent Marlowe 'Considering Options'",
	"Lou's Bait & Tackle Buys Boat, Names It After Coffee Can", "Local Angler Beats TV Star at Mullet Bay Slam; TV Star Blames 'Humidity'"]

# ---------- state ----------
static func fresh_state() -> Dictionary:
	return { "saga": { "ch": 0, "done": false, "paid_ch": 0, "left": DEBT, "finished": false, "fin_day": 0 },
		"act2": { "ch": 0, "done": false, "since": 0, "finished": false },
		"stats": { "catches": 0, "night": 0, "orders": 0, "full_fl": 0, "busts": 0, "storm": 0, "offshore": 0, "manhole": 0 },
		"ach": {}, "trophies": [], "tour": {} }

static func saga_cur() -> Dictionary:
	var ch := int(Game.S.saga.ch)
	return SAGA[ch] if ch >= 1 and ch < SAGA.size() else {}

static func act2_cur() -> Dictionary:
	var ch := int(Game.S.act2.ch)
	return ACT2[ch] if ch >= 1 and ch < ACT2.size() else {}

## The goal line for the top-left chip, or "" when there's no story right now.
static func goal_text() -> String:
	var S: Dictionary = Game.S.saga
	var c := saga_cur()
	if not c.is_empty():
		if S.done: return "Story: Lou's next job needs more of the map open" if _waiting() else "Story: head back to Lou's"
		if c.kind == "pay": return "Story: %s (%s of %s)" % [c.goal, Game.money(S.paid_ch), Game.money(c.amt)]
		if c.kind == "payoff": return "Story: %s, %s left" % [c.goal, Game.money(S.left)]
		return "Story: " + c.goal
	var a := act2_cur()
	if not a.is_empty(): return "Story: head back to Lou's" if Game.S.act2.done else "Act II: " + a.goal
	if Game.S.started and int(S.ch) == 0 and int(Game.S.day) >= 3: return "Lou called. Stop by the shop"
	if Game.S.saga.finished and int(Game.S.act2.ch) == 0 and int(Game.S.day) > int(Game.S.saga.fin_day): return "Lou wants you to see something on TV"
	return ""

## Lou's next job (Heron Lakes, then the power station) waits until that part of town is open.
static func _waiting() -> bool:
	var S: Dictionary = Game.S.saga
	if S.finished or not S.done: return false
	var nxt := int(S.ch) + 1
	return (nxt == 3 and Unlocks.step() < 3) or (nxt == 4 and Unlocks.step() < 4)

static func _complete(which: String) -> void:
	var S: Dictionary = Game.S[which]
	if S.done: return
	S.done = true
	Game.hint.emit("Story: Lou's next job needs more of the map open." if _waiting() else "Story: head back to Lou's.")
	Game.save_game()

static func on_catch(c: Dictionary) -> void:
	var c1 := saga_cur()
	if not c1.is_empty() and not Game.S.saga.done and not c.junk:
		if (c1.kind == "catch" and c.n == c1.fish) or (c1.kind == "mutant" and c.get("mutant", false) and int(c.spot) == 6) or (c1.kind == "big" and c.w > c1.lb):
			_complete("saga")
	var a := act2_cur()
	if not a.is_empty() and not Game.S.act2.done:
		if (a.kind == "catch" and c.n == a.fish) or (a.kind == "spot" and int(c.spot) == int(a.spot) and not c.junk): _complete("act2")
	var st: Dictionary = Game.S.stats
	st.catches += 1
	if Game.darkness() > 0.3: st.night += 1
	if Game.wx.storm: st.storm += 1
	if int(c.spot) == 15: st.offshore += 1
	if int(c.spot) == 8: st.manhole += 1
	if c.get("mutant", false) and not Game.S.get("mutant_news", false):
		Game.S.mutant_news = true
		Game.add_news(["Three-Eyed Fish Reported in Power Station Outflow; Plant 'Looking Into It'", "Angler Lands Fish That 'Looked Back at Him Twice'"].pick_random())
	if c.legend: Game.add_news("Local Angler Lands %d-lb '%s' at %s" % [roundi(c.w), c.n, Game.spots[int(c.spot)].name])

static func check() -> void:
	var S: Dictionary = Game.S.saga
	var c := saga_cur()
	if not c.is_empty() and not S.done:
		if (c.kind == "pay" and S.paid_ch >= c.amt) or (c.kind == "payoff" and S.left <= 0): _complete("saga")
	var a := act2_cur()
	if not a.is_empty() and not Game.S.act2.done:
		if (a.kind == "gear" and Game.S.gear.has(a.gear)) or (a.kind == "tourney" and Game.S.trophies.any(func(t): return int(t.place) == 1 and int(t.day) >= int(Game.S.act2.since))):
			_complete("act2")

static func pay(n: int) -> void:
	var S: Dictionary = Game.S.saga
	n = mini(n, mini(int(Game.S.cash), int(S.left)))
	if n <= 0 or saga_cur().is_empty(): return
	Game.S.cash -= n; S.left -= n; S.paid_ch += n
	check(); Game.save_game()

## If Lou has a story beat waiting, returns the card for it (and advances the story). Otherwise [].
static func scene() -> Array:
	var r := _saga_scene()
	if r.is_empty(): r = _act2_scene()
	return r

static func _saga_scene() -> Array:
	var S: Dictionary = Game.S.saga
	if not Game.S.started or S.finished: return []
	if int(S.ch) == 0:
		if int(Game.S.day) < 3: return []
		S.ch = 1; S.done = false; S.paid_ch = 0; Game.save_game()
		return _saga_card(0, 1)
	if not S.done or saga_cur().is_empty(): return []
	if _waiting(): return []
	var prev := int(S.ch)
	var c: Dictionary = SAGA[prev]
	if c.has("reward"): S.left = maxi(0, int(S.left) - int(c.reward))
	S.ch = prev + 1; S.done = false; S.paid_ch = 0
	if int(S.ch) >= SAGA.size():
		S.finished = true; S.fin_day = Game.S.day
		Game.add_news("Developer Tears Up Bait Shop's Note, Moves to Ohio; Lou 'Not Surprised'")
	else:
		Game.add_news(SAGA_NEWS[prev])
		if int(S.ch) == 4: Game.S.gear.geiger = 1
		if int(S.ch) == 5 and int(S.left) <= 0: S.done = true
	Game.save_game()
	return _saga_card(prev, 0 if S.finished else int(S.ch))

static func _saga_card(prev: int, next: int) -> Array:
	var S: Dictionary = Game.S.saga
	var parts := []
	if next: parts += [["h3", "Story · Chapter %d of %d" % [next, SAGA.size() - 1]], ["h2", SAGA[next].t]]
	else: parts += [["h3", "Story · The end"], ["h2", "Lou's Bait & Tackle is saved"]]
	parts.append(["pic", StoryArt.lou, 150])
	if prev: parts.append(["quote", SAGA[prev].done])
	if next:
		for p in SAGA[next].intro: parts.append(["p", p])
		parts.append(["goal", SAGA[next].goal, "%s still owed" % Game.money(S.left), float(DEBT - int(S.left)) / DEBT])
	else:
		parts.append(["p", "Lou hangs your photo next to his tarpon. The sign out front gets repainted: LOU'S BAIT, TACKLE & LEGENDS. Mullet Pointe Luxury Residences is never built. The coffee can stays on the counter, empty, for luck."])
		parts.append(["sub", "That's Act I. Come back tomorrow: somebody downtown has been saying things about Lou on television."])
	parts.append(["into", "note" if next else "sell"])
	return parts

static func _act2_scene() -> Array:
	var A: Dictionary = Game.S.act2
	if not Game.S.started or not Game.S.saga.finished or A.finished: return []
	if int(A.ch) == 0:
		if int(Game.S.day) <= int(Game.S.saga.fin_day): return []
		A.ch = 1; A.done = false; A.since = Game.S.day; Game.save_game()
		return _act2_card(0, 1)
	check()
	if not A.done: return []
	var prev := int(A.ch)
	var c: Dictionary = ACT2[prev]
	if c.has("reward"): Game.S.cash += int(c.reward)
	if c.has("rep"): Game.S.rep += int(c.rep)
	A.ch = prev + 1; A.done = false; A.since = Game.S.day
	if int(A.ch) >= ACT2.size():
		A.finished = true
		Game.add_news("REEL DEAL Cancelled; Former Host Now Works the Shrimp Tank at Lou's")
	else: Game.add_news(ACT2_NEWS[prev])
	Game.save_game()
	return _act2_card(prev, 0 if A.finished else int(A.ch))

static func _act2_card(prev: int, next: int) -> Array:
	var parts := []
	if next: parts += [["h3", "Act II · Chapter %d of %d" % [next, ACT2.size() - 1]], ["h2", ACT2[next].t]]
	else: parts += [["h3", "Act II · The end"], ["h2", "The real deal"]]
	parts.append(["pic", StoryArt.tv, 150])
	if prev: parts.append(["quote", ACT2[prev].done])
	if next:
		for p in ACT2[next].intro: parts.append(["p", p])
		parts.append(["goal", ACT2[next].goal, "", -1.0])
	else:
		parts.append(["p", "REEL DEAL is cancelled after the Old Glory episode. FINTASTIC! closes its doors. A week later, Trent Marlowe walks into Lou's in a plain T-shirt and asks if there's any work."])
		parts.append(["p", "Lou hands him an apron that says TRENT and points at the shrimp tank."])
		parts.append(["sub", "That's the end of Act II. The town, the bay and every legend in the journal are still out there."])
	parts.append(["into", "note" if next else "sell"])
	return parts

## The "Lou's note" tab in the shop.
static func note_parts(pay_cb: Callable) -> Array:
	var S: Dictionary = Game.S.saga
	var c := saga_cur()
	var paid := DEBT - int(S.left)
	if S.finished:
		var out := [["p", "The note is torn up and framed above the register, next to a photo of Chad's moving truck."]]
		var a := act2_cur()
		if Game.S.act2.finished: out += [["p", "Next to it: a framed REEL DEAL cancellation letter, and a name tag that says TRENT."], ["sub", "Both acts complete. Every legend in the journal is still out there."]]
		elif not a.is_empty(): out.append(["goal", "Act II, chapter %d: %s" % [int(Game.S.act2.ch), a.t], "Done!" if Game.S.act2.done else "In progress", -1.0, "Head back to Lou's" if Game.S.act2.done else a.goal])
		else: out.append(["sub", "Lou keeps glancing at the TV over the counter. Come back tomorrow."])
		return out
	if c.is_empty():
		return [["sub", "Lou seems worried about something. Come back in a bit." if int(Game.S.day) >= 3 else "Lou's counting the till and humming. Business as usual."]]
	var can := mini(int(Game.S.cash), int(S.left))
	var out := [["goal", "Chapter %d: %s" % [int(S.ch), c.t], "Done!" if S.done else "In progress", float(paid) / DEBT, goal_text().trim_prefix("Story: ")],
		["kv", [["Owed to Chad", Game.money(S.left)], ["Paid back", Game.money(paid)], ["Your cash", Game.money(Game.S.cash)]]]]
	if int(S.left) > 0:
		out.append(["sub", "Put cash in the coffee can. Every dollar goes to Chad."])
		out.append(["row", [["Pay " + Game.money(mini(50, can)), func(): pay_cb.call(50), can >= 1], ["Pay " + Game.money(mini(250, can)), func(): pay_cb.call(250), can >= 51],
			["Pay " + Game.money(can), func(): pay_cb.call(99999), can >= 1, "go"]]])
	else: out.append(["sub", "The note is paid off."])
	return out

# ---------- Lou's Wall of Fame ----------
static var _all_fish: Array = []
static func all_fish() -> Array:
	if _all_fish.is_empty():
		var seen := {}
		for k in Game.spots:
			for f in Game.spots[k].fish:
				if not seen.has(f.n): seen[f.n] = true; _all_fish.append(f)
	return _all_fish
static func legends_got() -> int: return all_fish().filter(func(f): return f.get("legend", false) and Game.S.journal.has(f.n)).size()
static func legends_all() -> int: return all_fish().filter(func(f): return f.get("legend", false)).size()
static func species_got() -> int: return all_fish().filter(func(f): return not f.get("junk", false) and Game.S.journal.has(f.n)).size()
static func junk_got() -> int: return all_fish().filter(func(f): return f.get("junk", false) and Game.S.journal.has(f.n)).size()

const ACH := [
	["first", "First Cast", "Land anything at all."],
	["leg1", "That's a Legend", "Land your first legend."],
	["leg10", "Lunker Hunter", "Land 10 different legends."],
	["legall", "Every Legend in Town", "Land every legend in the journal."],
	["species", "Marine Biologist", "Catch 40 different species."],
	["junk", "One Man's Trash", "Find 15 different kinds of junk."],
	["night", "Night Owl", "Land 25 fish after dark."],
	["orders", "Lou's Favorite", "Fill 10 of Lou's orders."],
	["liar", "Full Florida", "Get away with a full-Florida fish story."],
	["busted", "Frequent Trespasser", "Get busted 10 times."],
	["storm", "Lightning Rod", "Land a fish in a thunderstorm."],
	["blue", "Blue Water", "Land a fish offshore."],
	["champ", "Champion", "Win a Mullet Bay Slam."],
	["rich", "High Roller", "Hold $2,500 in cash."],
	["act1", "Lou's Is Saved", "Finish Act I: Lou's note."],
	["act2", "The Real Deal", "Finish Act II: Trent Marlowe."],
]

static func ach_ok(id: String) -> bool:
	var st: Dictionary = Game.S.stats
	match id:
		"first": return st.catches >= 1 or not Game.S.journal.is_empty()
		"leg1": return legends_got() >= 1
		"leg10": return legends_got() >= 10
		"legall": return legends_got() >= legends_all()
		"species": return species_got() >= 40
		"junk": return junk_got() >= 15
		"night": return st.night >= 25
		"orders": return st.orders >= 10
		"liar": return st.full_fl >= 1
		"busted": return int(Game.S.busts) >= 10
		"storm": return st.storm >= 1
		"blue": return st.offshore >= 1
		"champ": return Game.S.trophies.any(func(t): return int(t.place) == 1)
		"rich": return Game.S.cash >= 2500
		"act1": return Game.S.saga.finished
		"act2": return Game.S.act2.finished
	return false

## Returns newly earned plaques as [name, desc] pairs (and pays for them).
static func check_ach() -> Array:
	var out := []
	if not Game.S.started: return out
	for a in ACH:
		if not Game.S.ach.has(a[0]) and ach_ok(a[0]):
			Game.S.ach[a[0]] = Game.S.day; Game.S.cash += 50; Game.S.rep += 3
			out.append(a)
	return out

# ---------- the Mullet Bay Slam: every seventh day at the marina ----------
const TFMT := { "big": ["Big Fish", "Heaviest single fish wins."], "bag": ["Three-Fish Bag", "Your three heaviest fish, added up."], "junk": ["Junk Jamboree", "The three most valuable pieces of junk. Lou's idea."] }
const RIVALS := [["Trent Marlowe", 1.45], ["Big Earl", 1.1], ["Rosa Delgado", 1.0], ["Kyle from the Jet Ski Place", 0.7]]

static func tour_day(d: int) -> bool: return d % 7 == 6
static func tour_fmt(d: int) -> String: return ["big", "bag", "junk"][int(d / 7.0) % 3]
static func ordinal(n: int) -> String: return str(n) + ("st" if n == 1 else "nd" if n == 2 else "rd" if n == 3 else "th")
static func fmt_score(fmt: String, v: float) -> String: return Game.money(v) if fmt == "junk" else "%.1f lb" % v

static func tour_state() -> Dictionary:
	if Game.S.tour.is_empty() or int(Game.S.tour.day) != int(Game.S.day):
		Game.S.tour = { "day": Game.S.day, "signed": false, "at": 0.0, "done": false, "place": 0 }
	return Game.S.tour

static func tour_score(fmt: String) -> float:
	var at: float = Game.S.tour.at if not Game.S.tour.is_empty() and int(Game.S.tour.day) == int(Game.S.day) else 1e12
	var mine: Array = Game.S.cooler.filter(func(c): return int(c.get("day", 0)) == int(Game.S.day) and float(c.get("tm", 0)) >= at)
	if fmt == "junk":
		var v: Array = mine.filter(func(c): return c.junk).map(func(c): return float(c.value))
		v.sort(); v.reverse()
		return v.slice(0, 3).reduce(func(s, x): return s + x, 0.0)
	var w: Array = mine.filter(func(c): return not c.junk).map(func(c): return float(c.w))
	w.sort(); w.reverse()
	if fmt == "big": return w[0] if w.size() else 0.0
	return w.slice(0, 3).reduce(func(s, x): return s + x, 0.0)

static func rival_scores(day: int, fmt: String) -> Array:
	var n := int(day / 7.0)
	var base: float = 22.0 + n * 9 if fmt == "junk" else 14.0 + n * 6 if fmt == "bag" else 7.0 + n * 3.5
	var out := []
	for i in RIVALS.size():
		var v: float = base * RIVALS[i][1] * (0.65 + Town.hash2(day * 7 + i, 31) * 0.7)
		out.append({ "n": RIVALS[i][0], "v": float(roundi(v)) if fmt == "junk" else snappedf(v, 0.1) })
	return out

static func tour_chip() -> String:
	if not Game.S.started: return ""
	var d := int(Game.S.day)
	var h := Game.hour()
	if tour_day(d + 1) and h >= 12: return "Mullet Bay Slam tomorrow: " + TFMT[tour_fmt(d + 1)][0]
	if not tour_day(d): return ""
	var ts: Dictionary = Game.S.tour if not Game.S.tour.is_empty() and int(Game.S.tour.day) == d else {}
	var fmt := tour_fmt(d)
	if ts.get("done", false): return "Slam: you placed " + ordinal(int(ts.place)) if int(ts.place) else "Slam: over for today"
	if ts.get("signed", false): return "Slam (%s): %s. Weigh in at the marina by 7 PM" % [TFMT[fmt][0], fmt_score(fmt, tour_score(fmt))]
	return "Mullet Bay Slam today (%s). Sign up at the marina by noon" % TFMT[fmt][0] if h < 12 else "Slam sign-ups are closed"

static func slam_parts(sign_cb: Callable, weigh_cb: Callable) -> Array:
	var d := int(Game.S.day)
	if not tour_day(d):
		var nd := d + ((6 - d % 7) + 7) % 7
		var f := tour_fmt(nd)
		return [["p", "The Mullet Bay Slam runs every seventh day. Next one: day %d, %s. %s" % [nd, TFMT[f][0], TFMT[f][1]]],
			["sub", "Sign up here before noon that day for $20 and weigh in by 7 PM. Prizes: $400, $150 and $60, plus rep."]]
	var ts := tour_state()
	var fmt := tour_fmt(d)
	if ts.done: return [["p", ("You finished %s today." % ordinal(int(ts.place)) if int(ts.place) else "You didn't weigh anything in today.") + " The next Slam is in a week."]]
	if not ts.signed:
		if Game.hour() >= 12: return [["sub", "Sign-ups closed at noon. Trent is already doing interviews by the scale."]]
		return [["p", "Today's format: %s. %s" % [TFMT[fmt][0], TFMT[fmt][1]]], ["sub", "Entry is $20. Only fish you catch after you sign up count, so sign up first and then go fishing."],
			["row", [["Sign up ($20)", sign_cb, Game.S.cash >= 20, "go"]]]]
	return [["p", "You're signed up. Format: %s. %s" % [TFMT[fmt][0], TFMT[fmt][1]]],
		["kv", [["Your score", fmt_score(fmt, tour_score(fmt))], ["Weigh-in closes", "7:00 PM"], ["Trent says", "\"Cute.\""]]],
		["sub", "Weighing in ends your Slam for today. Your fish stay in your cooler afterward."],
		["row", [["Weigh in now", weigh_cb, Game.hour() < 19, "go"]]]]

static func sign_up() -> bool:
	if not tour_day(int(Game.S.day)) or Game.hour() >= 12 or Game.S.cash < 20: return false
	var ts := tour_state()
	if ts.signed: return false
	ts.signed = true; ts.at = Game.S.min; Game.S.cash -= 20; Game.save_game()
	return true

static func weigh_in() -> Array:
	var ts := tour_state()
	if not ts.signed or ts.done or Game.hour() >= 19: return []
	var fmt := tour_fmt(int(Game.S.day))
	var me := tour_score(fmt)
	var rows := rival_scores(int(Game.S.day), fmt)
	rows.append({ "n": "You", "v": me, "me": true })
	rows.sort_custom(func(a, b): return a.v > b.v)
	var place := 0
	for i in rows.size():
		if rows[i].get("me", false): place = i + 1
	ts.done = true; ts.place = place if me > 0 else 0
	var prize: int = [0, 400, 150, 60, 0, 0][int(ts.place)]
	var rep: int = [0, 15, 6, 3, 0, 0][int(ts.place)]
	Game.S.cash += prize; Game.S.rep += rep
	if int(ts.place): Game.S.trophies.append({ "day": Game.S.day, "fmt": fmt, "place": ts.place, "v": me })
	if int(ts.place) == 1: Game.add_news(["Local Angler Beats TV Star at Mullet Bay Slam; Trent Marlowe Blames 'Humidity'", "Upset at the Marina: Trent Marlowe Finishes Behind Guy With a Garage-Sale Cooler"].pick_random())
	else: Game.add_news("%s Wins Mullet Bay Slam; Local Angler Finishes %s" % [rows[0].n, ordinal(place)])
	check(); Game.save_game()
	var lb := rows.map(func(r): return [r.n, fmt_score(fmt, r.v), r.get("me", false)])
	var p := int(ts.place)
	return [["h3", "Mullet Bay Slam · day %d · %s" % [int(Game.S.day), TFMT[fmt][0]]], ["h2", "You won the Slam!" if p == 1 else "You finished " + ordinal(p) if p else "Nothing to weigh"],
		["lb", lb],
		["quote", "Trent Marlowe hands you the trophy on camera. His smile doesn't move at all." if p == 1 else "Trent waves to the camera with the trophy. The trophy is shaped like Trent." if p else "The weighmaster looks at your cooler, then at you. \"You know this is a fishing tournament?\""],
		["p", "Prize: %s and +%d rep. Your fish stay in your cooler." % [Game.money(prize), rep] if prize else "No prize this time. The next Slam is a week from today."]]

# ---------- the Route 1 bus ----------
const BUS := [["Lou's Bait & Tackle", Vector2(53.5, 33.5), "Sell, buy bait, talk to Lou."], ["Maple Park, by your house", Vector2(12.5, 11.5), "Home and a nap."],
	["Back Canal bridge", Vector2(44.5, 81.5), "Back Canal, Heron Lakes, Sunsplash Jungle, the airport."], ["Downtown, Flamingo Ave", Vector2(44.5, 119.5), "Bayfront Park, Marlowe Tower, FINTASTIC!"],
	["Mullet Bay Marina", Vector2(92.5, 154.5), "Boats, squid, the Slam, the pier and the bay."]]

static func bus_near(p: Vector2) -> int:
	for i in BUS.size():
		if p.distance_to(BUS[i][1]) < 1.4: return i
	return -1
