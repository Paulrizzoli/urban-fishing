extends Node
## Autoload "Game": the save file, the clock and the shared fish and gear data.

signal news(text: String)
signal hint(text: String)
signal new_day

var hoa_open := false
var orders: Array = []
var tips2: Array = []

const SAVE_PATH := "user://urban_fishing_save.json"
const TS := 32.0                      # pixels per tile
const MINUTES_PER_SECOND := 4.0       # one game hour every 15 seconds

var S: Dictionary = {}                # the save state
var spots: Dictionary = {}            # region id (int) -> spot data
var gear: Array = []
var rods: Array = []
var baitpref: Dictionary = {}
var baits: Array = []
var tips: Array = []
var font_display: Font = preload("res://fonts/LilitaOne-Regular.ttf")
var font_body: Font = preload("res://fonts/AtkinsonHyperlegible-Regular.ttf")
var font_bold: Font = preload("res://fonts/AtkinsonHyperlegible-Bold.ttf")

func _ready() -> void:
	Town.build()
	spots = {}
	var raw: Dictionary = _load_json("res://data/spots.json")
	for k in raw: spots[int(k)] = raw[k]
	gear = _load_json("res://data/gear.json")
	rods = _load_json("res://data/rod.json")
	baitpref = _load_json("res://data/baitpref.json")
	baits = _load_json("res://data/baits.json")
	tips = _load_json("res://data/tips.json")
	tips2 = _load_json("res://data/tips2.json")
	orders = _load_json("res://data/orders.json")
	load_game()

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func fresh() -> Dictionary:
	return { "day": 1, "min": 6 * 60 + 30.0, "cash": 30, "rep": 0, "x": 48.5, "y": 33.2, "face": PI / 2, "gear": {}, "cooler_cap": 5,
		"cooler": [], "journal": {}, "bait": "worms", "started": false, "news": [],
		"boat": false, "boat_kind": "kayak", "offenses": {}, "order": {}, "park_day": 0, "swept_day": 0, "story": {}, "story_day": 0, "story_told": false,
		"tips_heard": 0, "rosa": 0, "visited": {}, "busts": 0 }

func load_game() -> void:
	S = fresh()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary: S.merge(d, true)
	# JSON brings every number back as a float; keep the counters whole
	for k in ["day", "cash", "rep", "cooler_cap"]: S[k] = int(S[k])

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(S))

func reset() -> void:
	S = fresh(); save_game()

# ---------- the clock ----------
func hour() -> float: return fmod(S.min / 60.0, 24.0)
func time_band() -> String:
	var h := hour()
	if h >= 8 and h < 17: return "day"
	if (h >= 6 and h < 8) or (h >= 17 and h < 20): return "low"
	return "night"
func darkness() -> float:
	var h := hour()
	if h >= 7 and h < 18: return 0.0
	if h >= 18 and h < 20.5: return (h - 18.0) / 2.5 * 0.62
	if h >= 20.5 or h < 5: return 0.62
	return (7.0 - h) / 2.0 * 0.62
func clock_text() -> String:
	var h := int(hour())
	var m := int(fmod(S.min, 60.0))
	return "%d:%02d %s" % [12 if h % 12 == 0 else h % 12, m, "AM" if h < 12 else "PM"]

func advance(dt: float) -> void:
	var before: float = S.min
	S.min += dt * MINUTES_PER_SECOND
	if int(S.min / 1440.0) != int(before / 1440.0):
		S.day += 1
		new_day.emit()

# ---------- the king tide floods Low Street every fourth day, 10 AM to 2 PM ----------
func tide_day() -> bool: return int(S.day) % 4 == 3
func flood_level() -> float:
	if not tide_day(): return 0.0
	var h := hour()
	if h < 9.5 or h > 14.5: return 0.0
	if h < 10: return (h - 9.5) * 2
	if h > 14: return (14.5 - h) * 2
	return 1.0
func flooded() -> bool: return flood_level() > 0.5

# ---------- Lou's daily order ----------
func cur_order() -> Variant:
	if S.order.is_empty() or int(S.order.day) != int(S.day): return null
	return orders[int(S.order.i)]
func new_order() -> void:
	var pool := []
	for i in orders.size():
		var o: Dictionary = orders[i]
		var need: String = o.get("need", "")
		if need == "" or (need == "downtown" and S.visited.has("dt")) or S.gear.has(need): pool.append(i)
	S.order = { "day": S.day, "i": pool.pick_random(), "done": false }
func order_match(o: Dictionary, c: Dictionary) -> bool:
	var m: Dictionary = o.match
	if m.has("name") and c.n != m.name: return false
	if m.has("has") and not (m.has in c.n): return false
	if m.has("minw") and (c.junk or c.w < m.minw): return false
	if m.has("spot") and int(c.spot) != int(m.spot): return false
	if m.get("nojunk", false) and c.junk: return false
	return true
func order_matches() -> Array:
	var o = cur_order()
	if o == null: return []
	return S.cooler.filter(func(c): return order_match(o, c))

# ---------- helpers ----------
func money(n: float) -> String:
	var s := str(int(round(n)))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "$" + s + out

func rod_level() -> int:
	for i in [4, 3, 2, 1]:
		if S.gear.has("rod%d" % i): return i
	return 0

func rep_title() -> String:
	var t := "Nobody"
	for p in [[0, "Nobody"], [10, "Regular"], [25, "Known Liar"], [45, "Local Legend"], [80, "Port Mullet Royalty"]]:
		if S.rep >= p[0]: t = p[1]
	return t

func bait_name() -> String:
	for b in baits:
		if b.id == S.bait: return b.n
	return "Worms"

func owned_baits() -> Array:
	return baits.filter(func(b): return not b.has("gear") or S.gear.has(b.gear))

func bait_mul(f: Dictionary) -> float:
	if f.get("junk", false): return 1.0
	var l: Variant = baitpref.get(f.n)
	if l == null: return 1.0
	return 2.3 if S.bait in l else 0.55
