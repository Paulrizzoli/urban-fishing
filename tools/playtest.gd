extends Node
## The playtest bot (not part of the game): plays the real game through key presses and button clicks,
## the way a player would, and prints what happens and anything that looks wrong ("ISSUE").
## tools/playtest.sh runs it as an autoload in a copy of the project; see that file for the scenarios.
## usage: tools/playtest.sh <godot binary> <scenario> [args]

const FPS := 20.0
var M = null
var issues: Array = []
var last_hint := ""
var catches := {}      # spot -> [names]
var spot_tries := {}   # spot -> casts
var events := {}
var scen := ""

func L(s: String) -> void:
	var S: Dictionary = Game.S
	print("PT [%s d%d %s $%d c%d/%d] %s" % [Town.NAMES[Town.level] if Town.level < 3 else "?", int(S.get("day", 0)), Game.clock_text() if S.has("min") else "", int(S.get("cash", 0)), S.get("cooler", []).size(), int(S.get("cooler_cap", 0)), s])
func ISSUE(s: String) -> void: issues.append(s); L("!!! ISSUE: " + s)
func ev(k: String, n := 1) -> void: events[k] = int(events.get(k, 0)) + n

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt="): scen = a.substr(5)
	if scen == "": set_process(false); return
	Game.toast.connect(func(t, m): L("TOAST %s: %s" % [m, t]))
	Game.hint.connect(func(t): L("HINT " + t))
	_run.call_deferred()

func _process(_dt: float) -> void:
	if M == null or not is_instance_valid(M) or M.hud == null: return
	var h: String = M.hud.hint.text if M.hud.hint.visible else ""
	if h != last_hint and h != "": L("flash: " + h)
	last_hint = h

func fr(n := 1) -> void:
	for i in n: await get_tree().process_frame
func secs(s: float) -> void: await fr(maxi(1, int(s * FPS)))

func key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func tap(k: int) -> void:
	key(k, true); await fr(2); key(k, false); await fr(1)

func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree(): out.append(c)
		_buttons(c, out)
func buttons() -> Array:
	var out := []; _buttons(get_tree().root, out); return out
func click(prefix: String, quiet := false) -> bool:
	for b in buttons():
		if b.text.begins_with(prefix):
			if b.disabled:
				if not quiet: L("button '%s' is disabled" % b.text)
				return false
			b.emit_signal("pressed"); await fr(3); return true
	if not quiet: L("no button '%s' (have: %s)" % [prefix, ", ".join(buttons().map(func(b): return b.text))])
	return false

func _labels(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Label and c.is_visible_in_tree() and c.text != "": out.append(c.text)
		elif c is RichTextLabel and c.is_visible_in_tree(): out.append(c.text)
		_labels(c, out)
func card_text() -> String:
	var out := []; _labels(M.hud.card_box, out); return " | ".join(out)

func scene_ready() -> void:
	while true:
		var cs = get_tree().current_scene
		if cs != null and is_instance_valid(cs) and cs.get("fishing") != null and cs.get("hud") != null and cs.is_node_ready():
			if cs != M:
				M = cs
				M.fishing.message.connect(func(t): L("fishmsg: " + t))
			return
		await fr()

## Deal with whatever card is open. Returns the title text.
func popups(max_n := 6) -> void:
	for i in max_n:
		await fr(2)
		if not M.hud.is_open(): return
		var txt := card_text()
		L("CARD: " + txt.substr(0, 300))
		var done := false
		for b in ["Go fishing", "Let's fish", "Walk it off", "Ouch", "Got it", "Into the shop", "OK", "Okay", "Nice", "Back outside", "Close", "Back"]:
			if await click(b, true): done = true; ev("card:" + b); break
		if not done:
			var bs := buttons().filter(func(b): return not b.disabled)
			L("  unknown card, buttons: " + ", ".join(bs.map(func(b): return b.text)))
			key(KEY_ESCAPE, true); await fr(2); key(KEY_ESCAPE, false); await fr(2)

func ptile() -> Vector2i: return Vector2i(floori(M.player.position.x), floori(M.player.position.y))

## Walk to p (clicking there). Re-clicks after bumps; reports getting stuck.
func walk(p: Vector2, timeout := 90.0, why := "", stop_on_card := false) -> bool:
	var t := 0.0
	var last = M.player.position
	var still := 0.0
	var tries := 0
	M.player.walk_to(p)
	if M.player.path.is_empty() and M.player.position.distance_to(p) > 1.2:
		L("no path to %s %s from %s" % [str(p), why, str(M.player.position)]); return false
	while t < timeout:
		await fr(); t += 1.0 / FPS
		if M.hud.is_open():
			if stop_on_card and M.player.position.distance_to(p) < 3.0: return true
			await popups(); M.player.walk_to(p)
		if M.player.position.distance_to(p) < 0.6: return true
		if M.player.path.is_empty():
			if M.player.position.distance_to(p) < 1.3: return true
			tries += 1
			if tries > 40: break
			M.player.walk_to(p)
		if M.player.position.distance_to(last) < 0.02: still += 1.0 / FPS
		else: still = 0.0; last = M.player.position
		if still > 4.0:
			ISSUE("stuck walking to %s %s at %s (tile %s)" % [str(p), why, str(M.player.position), Town.t_at(ptile().x, ptile().y)])
			return false
	L("walk to %s %s gave up at %s" % [str(p), why, str(M.player.position)])
	return M.player.position.distance_to(p) < 1.3

func teleport(p: Vector2) -> void:
	M.player.position = p; M.player.path.clear(); Game.S.x = p.x; Game.S.y = p.y
	M.cam.position = p * Game.TS; M.cam.reset_smoothing()
	await fr(3)

## Land tiles to stand on to fish spot sid, nearest by walking first (or straight line if teleporting).
func stands(sid: int, walking := true, max_n := 6) -> Array:
	var tiles: Array = M.fishing.regtiles.get(sid, [])
	if tiles.is_empty(): return []
	var cand := {}
	for v in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = v.x + dx
				var y: int = v.y + dy
				if not Town.inb(x, y) or Town.is_water_t(Town.t_at(x, y)) or not M.player.walkable(x, y) or Town.t_at(x, y) == Town.T.ROAD: continue
				cand[Vector2i(x, y)] = true
	var lst: Array = cand.keys()
	var here := ptile()
	lst.sort_custom(func(a, b): return Vector2(a).distance_squared_to(here) < Vector2(b).distance_squared_to(here))
	var out := []
	var g: AStarGrid2D = M.player.walk_grid
	for c in lst.slice(0, 400):
		if not walking: out.append(Vector2(c) + Vector2(0.5, 0.5))
		else:
			var pth := g.get_id_path(here, c)
			if pth.size() > 0 or c == here: out.append([pth.size(), Vector2(c) + Vector2(0.5, 0.5)])
		if out.size() >= 60: break
	if walking:
		out.sort_custom(func(a, b): return a[0] < b[0])
		out = out.map(func(a): return a[1])
	# spread them out: not all on one tile
	var picked := []
	for p in out:
		if picked.all(func(q): return q.distance_to(p) > 3.0): picked.append(p)
		if picked.size() >= max_n: break
	return picked

func best_bait(sid: int) -> String:
	var owned: Array = Game.owned_baits().map(func(b): return b.id)
	var score := {}
	for f in Game.spots[sid].fish:
		if f.get("junk", false) or f.get("legend", false): continue
		if Game.S.journal.has(f.n): continue
		var pref = Game.baitpref.get(f.n)
		if pref == null: continue
		for b in pref:
			if b in owned: score[b] = float(score.get(b, 0.0)) + float(f.r)
	var best := String(Game.S.bait)
	var bs := -1.0
	for b in score:
		if score[b] > bs: bs = score[b]; best = b
	return best

func set_bait(b: String) -> void:
	for i in 10:
		if Game.S.bait == b: return
		await tap(KEY_B)
	if Game.S.bait != b: ISSUE("B never got to bait " + b)

## One cast. Returns the landed catch name, or "".
func cast_once(wait_max := 40.0) -> String:
	var F = M.fishing
	if M.hud.is_open(): await popups()
	if F.state != "idle": F.cancel()
	await fr(2)
	if M.near != "fish": L("not by fishable water (near=%s)" % M.near); return "!nowater"
	if Game.S.cooler.size() >= Game.S.cooler_cap: return "!full"
	await tap(KEY_F)
	if F.state != "power": L("F did not start a cast (state %s)" % F.state); return "!nocast"
	# steer the marker a little with the arrows sometimes, like a player would
	if randf() < 0.3:
		key(KEY_UP, true); await secs(0.2); key(KEY_UP, false)
	var t := 0.0
	while t < 6.0:
		await fr(); t += 1.0 / FPS
		if absf(F.power - F.green) < 0.03: break
	var mk: Vector2 = F.tgt.pos if F.tgt != null else Vector2.ZERO
	var pw: float = F.power
	await tap(KEY_F)
	if F.state != "wait":
		var land: Vector2 = M.player.position + Vector2.from_angle(F.aim) * (Fishing.MINR + pw * (F.reach() - Fishing.MINR))
		L("dry cast from %s marker %s (tile %d, water %s) power %.2f green %.2f lands ~%s tile %d" % [str(M.player.position), str(mk), Town.t_at(floori(mk.x), floori(mk.y)), F.is_water(mk), pw, F.green, str(land), Town.t_at(floori(land.x), floori(land.y))])
		ev("cast_dry"); return "!dry"
	ev("cast")
	t = 0.0
	var tw := 0
	var hooked := false
	while t < wait_max:
		await fr(); t += 1.0 / FPS
		if M.hud.is_open(): await popups(); return "!card"
		if F.state == "idle": return "!lost"
		if F.state == "wait" and ((t > 7 and tw == 0) or (t > 15 and tw == 1)):
			tw += 1; ev("twitch"); await tap(KEY_RIGHT if tw == 1 else KEY_LEFT)
		if F.state == "bite":
			await secs(randf_range(0.15, 0.35))
			key(KEY_F, true); await fr(2)
			if F.state == "reel": hooked = true; ev("hooked"); break
			key(KEY_F, false)
	if not hooked:
		F.cancel(); key(KEY_F, false); return "!nobite"
	# the fight
	var holding := true
	var lr := 0
	t = 0.0
	while F.state == "reel" and t < 90:
		await fr(); t += 1.0 / FPS
		var want: bool = F.tension < 0.55
		if want != holding: key(KEY_F, want); holding = want
		var w := 0
		if F.ang > 0.2: w = -1
		elif F.ang < -0.2: w = 1
		if w != lr:
			if lr == -1: key(KEY_LEFT, false)
			if lr == 1: key(KEY_RIGHT, false)
			if w == -1: key(KEY_LEFT, true)
			if w == 1: key(KEY_RIGHT, true)
			lr = w
	key(KEY_F, false); key(KEY_LEFT, false); key(KEY_RIGHT, false)
	await fr(4)
	if M.pending_catch != null and M.hud.is_open():
		var c: Dictionary = M.pending_catch
		ev("landed")
		var keep: bool = not c.release and Game.S.cooler.size() < Game.S.cooler_cap
		if keep: await click("Into the cooler")
		elif c.release: await click("Let it go")
		else: await click("Release it")
		if M.hud.is_open(): await popups()
		return String(c.n) + (" (junk)" if c.junk else "") + " %.1flb $%d" % [float(c.w), int(c.value)]
	ev("escaped")
	return "!escaped"

func fish_spot(sid: int, casts: int, walking := true) -> int:
	var sp: Dictionary = Game.spots.get(sid, {})
	var st := stands(sid, walking)
	if st.is_empty(): L("spot %d %s: nowhere to stand%s" % [sid, sp.get("name", "?"), " on foot" if walking else ""]); return -1
	var got := 0
	var b := best_bait(sid)
	await set_bait(b)
	for p in st:
		if walking:
			if not await walk(p, 120.0, "to fish %s" % sp.name): continue
		else: await teleport(p)
		# face the water
		var best := Vector2.ZERO
		for k in 16:
			var d := Vector2.from_angle(k * TAU / 16)
			if M.fishing.region_at(M.player.position + d * 2.5) == sid: best = d; break
		if best != Vector2.ZERO: M.player.face = best.angle()
		var per := ceili(float(casts) / st.size()) + 1
		for i in per:
			if Game.S.cooler.size() >= Game.S.cooler_cap: return got
			var r := await cast_once()
			spot_tries[sid] = int(spot_tries.get(sid, 0)) + 1
			if not r.begins_with("!"):
				got += 1
				if not catches.has(sid): catches[sid] = []
				catches[sid].append(r)
				L("CATCH at %d %s: %s" % [sid, sp.name, r])
			elif r in ["!nowater", "!nocast"]: break
			else: L("cast at %d: %s" % [sid, r])
			if Player.zone_of(M.player.position) != 0 and M.hud.is_open(): await popups()
			casts -= 1
			if casts <= 0: return got
	return got

func shadows_in(sid: int) -> int:
	return M.fishing.shadows.filter(func(s): return s.reg == sid and not s.leaving).size()

## Sell everything at the town's tackle shop (walking in through the door).
func sell_at_shop() -> void:
	var door: Vector2 = M.lou_door
	M.shop_tab = "sell"
	if not await walk(door, 200.0, "to the tackle shop", true): ISSUE("couldn't walk to the tackle shop door"); return
	await fr(5)
	if not M.hud.is_open(): ISSUE("walking into the shop door didn't open it"); M.open_shop(); await fr(3)
	for i in 3:
		var tx := card_text()
		if "First time" in tx or "Lou's note" in tx or tx.find("Sell everything") < 0 and Game.S.cooler.size() > 0:
			L("SHOP CARD: " + tx.substr(0, 400))
			if await click("Into the shop", true): continue
			if not "Sell" in tx: await click("Back outside", true); M.shop_tab = "sell"; M.open_shop(); await fr(3)
	if Game.S.cooler.size() > 0:
		var before := int(Game.S.cash)
		if await click("Sell everything"): L("SOLD at shop for $%d" % (int(Game.S.cash) - before)); ev("sold_shop")
	# today's order
	if Town.level == 0:
		M.shop_tab = "order"; M.open_shop(); await fr(3)
		L("ORDER: " + card_text().substr(0, 250))
		if await click("Hand it over", true): L("filled Lou's order"); ev("order")
	await buy_gear()
	M.shop_tab = "sell"
	await click("Back outside", true)
	await popups()
	await walk_off(door)

const WISH := ["bread", "hotdog", "bait", "lure", "cooler", "rod1", "squid", "kayak", "rod2", "cooler", "rod3"]
func buy_gear() -> void:
	for gid in WISH:
		var g = Game.gear.filter(func(x): return x.id == gid)
		if g.is_empty(): continue
		g = g[0]
		if gid != "cooler" and Game.S.gear.has(gid): continue
		if gid == "cooler" and Game.S.cooler_cap >= Game.cooler_max(): continue
		var here_ok: bool = not g.has("where") or (Town.level == 2 and g.where == "marina")
		if not here_ok: continue
		if g.get("req") != null and not Game.S.gear.has(g.req): continue
		if int(Game.S.cash) - int(g.price) < (15 if Town.level == 0 and species(0) < 6 else 60): continue
		M._buy(gid, int(g.price), g.has("where"))
		await fr(3)
		L("BOUGHT %s for $%d" % [g.n, int(g.price)]); ev("buy")

func sell_at_buyers() -> void:
	for bd in Buyers.here():
		if Game.S.cooler.is_empty(): return
		var d: Vector2 = Buyers.door(bd)
		if not Buyers.open_now(bd): L("%s is closed now" % bd.name); continue
		M.buyer_tab = "sell"
		if not await walk(d, 200.0, "to " + bd.name, true): ISSUE("couldn't walk to %s" % bd.name); continue
		await fr(5)
		if not M.hud.is_open(): ISSUE("walking into %s's door didn't open it (at %s, door %s)" % [bd.name, str(M.player.position), str(d)]); M.open_buyer(bd.id); await fr(3)
		var tx := card_text()
		L("BUYER %s: %s" % [bd.name, tx.substr(0, 350)])
		var before := int(Game.S.cash)
		if await click("Sell all", true): L("SOLD at %s for $%d" % [bd.name, int(Game.S.cash) - before]); ev("sold_" + bd.id)
		else: L("  nothing %s would take: %s" % [bd.who, ", ".join(Game.S.cooler.map(func(c): return c.n))])
		await click("Back outside", true)
		await walk_off(d)

## Step a couple of tiles away from a door so it can open again next time.
func walk_off(d: Vector2) -> void:
	for o in [Vector2(0, 2.2), Vector2(0, -2.2), Vector2(2.2, 0), Vector2(-2.2, 0)]:
		var q: Vector2 = d + o
		if M.player.walkable(floori(q.x), floori(q.y)) and not Town.is_water_t(Town.t_at(floori(q.x), floori(q.y))):
			await walk(q, 15.0); return

func bus_stop_near() -> int:
	var bl := Story.bus_list()
	var bi := 0
	var bd := INF
	for i in bl.size():
		var pth: Array = M.player.walk_grid.get_id_path(ptile(), Vector2i(bl[i][1]))
		if pth.size() > 0 and pth.size() < bd: bd = pth.size(); bi = i
	return bi

func take_coach(to: int) -> bool:
	var i := bus_stop_near()
	var stop: Vector2 = Story.bus_list()[i][1]
	if not await walk(stop, 200.0, "to the bus stop " + Story.bus_list()[i][0]): ISSUE("couldn't reach bus stop"); return false
	await fr(3)
	if M.near != "bus": ISSUE("at the bus stop but near=%s" % M.near); return false
	await tap(KEY_E)
	await fr(3)
	L("BUS CARD: " + card_text().substr(0, 600))
	var fare: int = M.COACHES["%d-%d" % [Town.level, to]][0]
	var old = M
	if not await click("Ride (%s)" % Game.money(fare)):
		ISSUE("coach to %s not available: %s" % [Town.NAMES[to], card_text().substr(0, 200)])
		await click("Walk instead", true); return false
	for k in 200:
		await fr()
		var cs = get_tree().current_scene
		if cs != old and cs != null: break
	await scene_ready()
	await fr(10)
	L("ARRIVED in %s at %s" % [Town.NAMES[Town.level], str(M.player.position)])
	await popups()
	return Town.level == to

func species(lv: int) -> int: return M._species_in(lv)

func town_spots(lv: int) -> Array:
	var out := []
	for sid in Game.spots:
		if Town.spot_town(int(sid)) == lv and Fishing.SHCOUNT.has(int(sid)) and int(sid) != 7 and int(sid) != 8: out.append(int(sid))
	return out

## ---------- scenarios ----------
func _run() -> void:
	await scene_ready()
	await fr(10)
	L("scenario " + scen)
	match scen:
		"journey": await journey()
		"spots": await all_spots()
		"cars": await cars()
		"traffic": await traffic()
		"probe": await probe()
		"reach": await reach()
		"boats": await boats()
	L("EVENTS " + JSON.stringify(events))
	for sid in catches: L("CATCHES %d %s: %s" % [sid, Game.spots[sid].name, ", ".join(catches[sid])])
	L("SPOT TRIES " + JSON.stringify(spot_tries))
	L("ISSUES (%d):" % issues.size())
	for s in issues: L("  - " + s)
	get_tree().quit()

func new_game() -> void:
	if M.menu.title_open:
		L("title: " + ", ".join(buttons().map(func(b): return b.text)))
		var old = M
		await click("New game")
		await fr(5)
		if M.hud.is_open() and "slot" in card_text().to_lower(): L("SLOTS: " + card_text()); await click("Slot 1", true)
		for k in 120:
			await fr()
			if get_tree().current_scene != old: break
		await scene_ready(); await fr(20)
	L("start at %s, intro: %s" % [str(M.player.position), card_text().substr(0, 200)])
	await popups()

func journey() -> void:
	await new_game()
	var plan := { 0: [1, 2, 9, 13, 14, 17, 3, 11], 1: [26, 22, 21, 20, 24, 25, 23], 2: [30, 35, 31, 32, 37, 34, 33, 36] }
	var goal := { 0: M.COACH_SPECIES, 1: M.COACH_SPECIES_GH, 2: 8 }
	for lv in [0, 1, 2]:
		var round_ := 0
		while species(lv) < goal[lv] and round_ < 3:
			round_ += 1
			for sid in plan[lv]:
				if species(lv) >= goal[lv]: break
				var stall: bool = spot_tries.get(sid, 0) >= 24
				if stall: continue
				L("== spot %d %s (shadows %d), species here so far %d/%d, rod %s, bait %s" % [sid, Game.spots[sid].name, shadows_in(sid), species(lv), goal[lv], Game.rod().name, Game.S.bait])
				await fish_spot(sid, 6)
				if Game.S.cooler.size() >= Game.S.cooler_cap - 0:
					await sell_at_buyers()
					await sell_at_shop()
		L("== %s done: %d kinds (goal %d), day %d" % [Town.NAMES[lv], species(lv), goal[lv], int(Game.S.day)])
		if species(lv) < goal[lv]: ISSUE("couldn't reach %d kinds in %s after 3 rounds (%d)" % [goal[lv], Town.NAMES[lv], species(lv)])
		await sell_at_buyers()
		await sell_at_shop()
		if lv < 2:
			if Game.S.cash < M.COACHES["%d-%d" % [lv, lv + 1]][0]: ISSUE("can't afford the coach out of %s ($%d)" % [Town.NAMES[lv], Game.S.cash]); Game.S.cash += 50
			if not await take_coach(lv + 1): ISSUE("coach to town %d failed" % (lv + 1)); Game.S.level = lv + 1; return
	# and home again
	await take_coach(0)

func all_spots() -> void:
	# every spot in every town, teleporting in, with all the gear, a few casts each
	await new_game()
	for g in Game.gear: Game.S.gear[g.id] = 1
	Game.S.cooler_cap = 30; Game.S.cash = 5000; Game.S.started = true; Game.S.sneak_lesson = true
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--town="): only = int(a.substr(7))
	for lv in [0, 1, 2]:
		if only >= 0 and lv != only: continue
		if Town.level != lv:
			Game.S.level = lv; var p: Vector2 = Story.bus_list(lv)[0][1]; Game.S.x = p.x; Game.S.y = p.y; Game.S.coach_in = true
			Game.save_game(); Game.skip_title = true
			var old = M
			get_tree().reload_current_scene()
			for k in 200:
				await fr()
				if get_tree().current_scene != old: break
			await scene_ready(); await fr(10); await popups()
		await secs(6)
		for sid in town_spots(lv):
			Game.S.cooler = []
			for h in [9.0, 22.0]:
				Game.S.min = floorf(Game.S.min / 1440.0) * 1440.0 + h * 60.0
				for w in M.guards.watchers: w.alert = 0
				await secs(2)
				L("== spot %d %s at %s: shadows %d/%d" % [sid, Game.spots[sid].name, Game.clock_text(), shadows_in(sid), Fishing.SHCOUNT[sid]])
				if shadows_in(sid) == 0: ISSUE("no fish shadows at spot %d %s" % [sid, Game.spots[sid].name])
				if stands(sid, false).is_empty(): L("spot %d %s has no shore to fish from: the boats scenario fishes it from the skiff" % [sid, Game.spots[sid].name]); break
				var n := await fish_spot(sid, 5, false)
				if n <= 0: ISSUE("no catch at spot %d %s at %s in %d casts" % [sid, Game.spots[sid].name, Game.clock_text(), int(spot_tries.get(sid, 0))])
				if M.hud.is_open(): await popups()

func cars() -> void:
	# stand in busy streets in each town and see what the cars do; check where you end up
	await new_game()
	for lv in [0, 1, 2]:
		await goto_town(lv, Story.bus_list(lv)[0][1])
		# where busted players get walked out to
		for z in M.guards.exits:
			var e: Vector2 = M.guards.exits[z]
			var t := Vector2i(floori(e.x), floori(e.y))
			var bad := ""
			if not M.player.walkable(t.x, t.y): bad = "not walkable"
			elif Town.is_water_t(Town.t_at(t.x, t.y)): bad = "water"
			elif Player.zone_of(e) == int(z): bad = "still inside the zone"
			elif M.player.walk_grid.get_id_path(t, Vector2i(Story.bus_list()[0][1])).is_empty(): bad = "can't walk to the coach stop from there"
			L("bust exit %s zone %s %s %s" % [Town.NAMES[lv], str(z), str(e), bad if bad != "" else "ok"])
			if bad != "": ISSUE("%s: busted at zone %s puts you at %s, %s" % [Town.NAMES[lv], str(z), str(e), bad])
		# road tiles the traffic drives, a few spread out
		var roads := []
		for c in M.traffic.cars: roads.append(c.position)
		roads = roads.slice(0, 5)
		for rp in roads:
			var b0 := int(Game.S.get("bumps", 0)); var k0 := int(Game.S.get("knockdowns", 0))
			var tp := Vector2(floorf(rp.x) + 0.5, floorf(rp.y) + 0.5)
			await teleport(tp)
			for i in 40:
				await secs(1)
				if M.hud.is_open():
					L("car card: " + card_text().substr(0, 200)); await popups()
				var pt := ptile()
				if M.player.sink(M.player.position, 0.0) > 0.05 and Town.t_at(pt.x, pt.y) != Town.T.ROAD: ISSUE("%s: inside a parked car at %s" % [Town.NAMES[lv], str(M.player.position)])
				if Town.is_water_t(Town.t_at(pt.x, pt.y)) and not M.player.in_boat(): ISSUE("%s: a car put you in the water at %s" % [Town.NAMES[lv], str(M.player.position)])
				if Town.t_at(pt.x, pt.y) != Town.T.ROAD:
					await teleport(tp)
			var b1 := int(Game.S.get("bumps", 0)) - b0; var k1 := int(Game.S.get("knockdowns", 0)) - k0
			L("street %s %s: %d bumps, %d knockouts in 40 s" % [Town.NAMES[lv], str(tp), b1, k1]); ev("bumps", b1); ev("knockouts", k1)

## Let the traffic in each town drive for a while with nobody in the street, and look for cars that
## never get out: every car should reach a dead end or the map edge and pull in somewhere new.
func traffic() -> void:
	await new_game()
	var mins := 8.0
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--mins="): mins = float(x.substr(7))
	for lv in [0, 1, 2]:
		await goto_town(lv, Story.bus_list(lv)[0][1])
		Game.quality = 2
		await secs(2)
		# park the player out of the way: on the coach stop's sidewalk, never in a lane
		var oldest := 0.0
		var t := 0.0
		var stuck_s := {}
		while t < mins * 60.0:
			await secs(10); t += 10.0
			if M.hud.is_open(): await popups()
			for c in M.traffic.cars:
				if not c.visible: continue
				if c.speed < 0.1 and not c.leaving: stuck_s[c] = float(stuck_s.get(c, 0.0)) + 10.0
				else: stuck_s[c] = 0.0
		var groups := {}
		var n := 0
		for c in M.traffic.cars:
			if not c.visible: continue
			n += 1
			oldest = maxf(oldest, c.age)
			if c.age > 240.0:
				var k := "%d,%d" % [int(c.position.x) / 8 * 8, int(c.position.y) / 8 * 8]
				groups[k] = int(groups.get(k, 0)) + 1
			if float(stuck_s.get(c, 0.0)) >= 30.0: ISSUE("%s: a car has stood still for %ds at %s" % [Town.NAMES[lv], int(stuck_s[c]), str(c.position)])
		var old_n := 0
		for k in groups: old_n += int(groups[k])
		L("traffic %s: %d cars out, oldest %ds, %d older than 4 min %s" % [Town.NAMES[lv], n, int(oldest), old_n, JSON.stringify(groups)])
		if old_n > 2: ISSUE("%s: %d of %d cars have been driving for over 4 minutes without getting out, around %s" % [Town.NAMES[lv], old_n, n, JSON.stringify(groups)])

func goto_town(lv: int, p: Vector2) -> void:
	Game.S.started = true; Game.S.sneak_lesson = true
	Game.S.level = lv; Game.S.x = p.x; Game.S.y = p.y; Game.S.coach_in = false
	Game.S.iw_seen = true; Game.S.gh_seen = true
	Game.save_game(); Game.skip_title = true
	var old = M
	get_tree().reload_current_scene()
	for k in 200:
		await fr()
		if get_tree().current_scene != old: break
	await scene_ready(); await fr(10); await popups()

func _v(s: String) -> Vector2:
	var a := s.split(","); return Vector2(float(a[0]), float(a[1]))

## --lv=1 --from=x,y --to=x,y : walk there and log where you go
func probe() -> void:
	var lv := 0; var a := Vector2.ZERO; var b := Vector2.ZERO
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--lv="): lv = int(x.substr(5))
		if x.begins_with("--from="): a = _v(x.substr(7))
		if x.begins_with("--to="): b = _v(x.substr(5))
	await goto_town(lv, a)
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--h="): Game.S.min = floorf(Game.S.min / 1440.0) * 1440.0 + float(x.substr(4)) * 60.0
	await secs(3)
	await teleport(a)
	L("at %s tile %s solid=%s walkable=%s" % [str(M.player.position), str(ptile()), M.player.walk_grid.is_point_solid(ptile()), M.player.walkable(ptile().x, ptile().y)])
	M.player.walk_to(b)
	L("path %s" % str(M.player.path.slice(0, 12)))
	for i in 200:
		await fr(5)
		if i % 4 == 0: L("pos %s path left %d hud %s title %s fish %s boat %s collides %s sink %.2f" % [str(M.player.position), M.player.path.size(), M.hud.is_open(), M.menu.title_open, M.fishing.state, M.player.in_boat(), M.player.collides(M.player.position), M.player.sink(M.player.position, 0.0)])
		if M.player.path.is_empty(): break
	L("end %s" % str(M.player.position))
	for o in Obstacles.parked:
		if o[0].distance_to(M.player.position) < 3: L("parked car %s ang %.2f" % [str(o[0]), o[1]])
	for c in M.traffic.cars:
		if c.position.distance_to(M.player.position) < 6: L("traffic car %s vis %s fade %.2f L %.2f" % [str(c.position), c.visible, c.fade, c.L])
	for d in [Vector2(0, 0.25), Vector2(0, 0.5), Vector2(0.2, 0.4)]:
		L("sink at +%s: %.3f collides %s" % [str(d), M.player.sink(M.player.position + d, 0.0), M.player.collides(M.player.position + d)])
	for dy in range(-3, 4):
		var row := ""
		for dx in range(-4, 5):
			var t := ptile() + Vector2i(dx, dy)
			row += "%2d%s " % [Town.t_at(t.x, t.y), "*" if M.player.walk_grid.is_point_solid(t) else " "]
		L("tiles " + row)

## Every door, bus stop and buyer in each town reachable on foot from the coach stop?
func reach() -> void:
	await new_game()
	for lv in [0, 1, 2]:
		var p0: Vector2 = Story.bus_list(lv)[0][1]
		await goto_town(lv, p0)
		var g: AStarGrid2D = M.player.walk_grid
		var pts := { "shop": M.lou_door, "home": M.home_door }
		if lv == 0: pts["marina"] = M.marina_door; pts["fin"] = Fintastic.DOOR; pts["oldtimer"] = M.oldtimer_at
		pts["talker"] = M.rosa_at
		for bs in Story.bus_list(): pts["bus " + bs[0]] = bs[1]
		for bd in Buyers.here():
			pts["buyer " + bd.name] = Buyers.door(bd)
			if bd.has("board"): pts["board " + bd.name] = Buyers.board_at(bd)
		for k in pts:
			var q: Vector2 = pts[k]
			var t := Vector2i(floori(q.x), floori(q.y))
			var ok := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var u := t + Vector2i(dx, dy)
					if g.region.has_point(u) and not g.is_point_solid(u) and g.get_id_path(ptile(), u).size() > 0 and Vector2(u) + Vector2(0.5, 0.5) - q == Vector2(u) + Vector2(0.5, 0.5) - q: ok = true
			L("reach %s %s: %s" % [Town.NAMES[lv], k, "ok" if ok else "NO"])
			if not ok: ISSUE("%s: can't walk to %s at %s from the coach stop" % [Town.NAMES[lv], k, str(q)])
		# and actually walk to each one
		for k in pts:
			var q: Vector2 = pts[k]
			await teleport(p0)
			if not await walk(q, 300.0, k, true): ISSUE("%s: walk to %s failed, ended at %s" % [Town.NAMES[lv], k, str(M.player.position)])
			if M.hud.is_open(): await popups()

## Fishing from the skiff: offshore in Port Mullet, the deep end of the Outer Harbor in Gannet Harbor.
func boats() -> void:
	await new_game()
	for g in Game.gear: Game.S.gear[g.id] = 1
	Game.S.cooler_cap = 30
	for job in [[0, 15], [2, 37], [0, 14], [1, 22]]:
		var lv: int = job[0]; var sid: int = job[1]
		await goto_town(lv, Story.bus_list(lv)[0][1])
		for g in Game.gear: Game.S.gear[g.id] = 1
		Game.S.cooler = []
		var tiles: Array = M.fishing.regtiles.get(sid, []).filter(func(v): return Player.boatable(v.x, v.y, "skiff"))
		tiles.shuffle()
		Game.S.boat = true; Game.S.boat_kind = "skiff"
		var got := 0
		for k in 4:
			await teleport(Vector2(tiles[k]) + Vector2(0.5, 0.5))
			await secs(2)
			for i in 3:
				var r := await cast_once()
				L("skiff at %d %s: %s" % [sid, Game.spots[sid].name, r])
				if not r.begins_with("!"): got += 1
		if got == 0: ISSUE("nothing caught from the skiff at %d %s" % [sid, Game.spots[sid].name])
		# and back to land with K
		Game.S.boat = false
