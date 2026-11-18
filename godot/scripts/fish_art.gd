class_name FishArt
## A side-on drawing of each kind of fish (and the odd crab, snake or gator) for the catch card.
## Each kind is a set of numbers: body depth, tail and fin shapes, colors and markings.
## draw() fits the animal into a rectangle, facing right.

const KINDS := {
	"bluegill": { "h": 0.46, "back": "#3e5f6e", "side": "#7d9a7a", "belly": "#e8a24a", "fin": "#4d6a70", "tail": "soft", "dorsal": "spiny", "pat": "bars", "ear": true },
	"tilapia": { "h": 0.4, "back": "#56656c", "side": "#9aa4a8", "belly": "#d6dadb", "fin": "#6d7a80", "tail": "square", "dorsal": "spiny", "pat": "bars_faint" },
	"bass": { "h": 0.32, "back": "#3f5a2e", "side": "#86a865", "belly": "#ecebcf", "fin": "#5c7a44", "tail": "square", "dorsal": "spiny", "pat": "blotch_line", "mouth": 1.6 },
	"peacock": { "h": 0.33, "back": "#4b6a2a", "side": "#c8c23e", "belly": "#f0b858", "fin": "#d0703a", "tail": "square", "dorsal": "spiny", "pat": "bars3", "eyespot": true },
	"catfish": { "h": 0.22, "back": "#4f5560", "side": "#8a9098", "belly": "#e2ded6", "fin": "#5a6068", "tail": "fork", "dorsal": "small", "pat": "specks", "whisk": true, "flat": true },
	"walking": { "h": 0.2, "back": "#5a4a3a", "side": "#8a745a", "belly": "#d8cbb6", "fin": "#5a4a3a", "tail": "round", "dorsal": "long", "pat": "specks", "whisk": true, "flat": true },
	"mullet": { "h": 0.22, "back": "#4c5c6c", "side": "#a8b4bc", "belly": "#e6ecef", "fin": "#7a8894", "tail": "fork", "dorsal": "small", "pat": "stripes" },
	"snook": { "h": 0.22, "back": "#6b6b52", "side": "#c8c6ae", "belly": "#efeee4", "fin": "#d8c46a", "tail": "fork", "dorsal": "spiny", "pat": "line", "snout": 1.3, "mouth": 1.4 },
	"tarpon": { "h": 0.28, "back": "#3e5a6c", "side": "#c6d2d8", "belly": "#f1f4f5", "fin": "#7a8e9a", "tail": "deepfork", "dorsal": "small", "pat": "bigscales", "upmouth": true },
	"bowfin": { "h": 0.22, "back": "#4d5a30", "side": "#7f8a52", "belly": "#d8d6b0", "fin": "#5d6a3a", "tail": "round", "dorsal": "long", "pat": "mottle", "eyespot": true },
	"goldfish": { "h": 0.45, "back": "#e0702a", "side": "#f29a2e", "belly": "#f8c870", "fin": "#f4a040", "tail": "veil", "dorsal": "small", "pat": "scales" },
	"koi": { "h": 0.32, "back": "#f4efe4", "side": "#f7f3ea", "belly": "#fbf8f2", "fin": "#f1e8dc", "tail": "soft", "dorsal": "long", "pat": "koi", "whisk": true },
	"butterfly": { "h": 0.3, "back": "#f4efe4", "side": "#f7f3ea", "belly": "#fbf8f2", "fin": "#f6d8c0", "tail": "veil", "dorsal": "long", "pat": "koi", "whisk": true, "longfins": true },
	"ogon": { "h": 0.32, "back": "#c9cdd0", "side": "#e8eaec", "belly": "#f6f7f8", "fin": "#d8dcdf", "tail": "soft", "dorsal": "long", "pat": "scales", "whisk": true, "shine": true },
	"eel": { "h": 0.09, "back": "#4a4f38", "side": "#6e7550", "belly": "#c8c49a", "fin": "#5a5f48", "tail": "eel", "dorsal": "eel", "pat": "none" },
	"jack": { "h": 0.42, "back": "#3c5a6a", "side": "#a9b8b4", "belly": "#e8d77a", "fin": "#d8c050", "tail": "deepfork", "dorsal": "spiny", "pat": "gillspot", "blunt": true },
	"redfish": { "h": 0.28, "back": "#9a5030", "side": "#c8784a", "belly": "#f0dcc4", "fin": "#b86a40", "tail": "square", "dorsal": "spiny", "pat": "scales", "tailspot": true },
	"gar": { "h": 0.13, "back": "#5a6038", "side": "#8a8f5a", "belly": "#d8d6b4", "fin": "#6a6a40", "tail": "round", "dorsal": "back", "pat": "spots", "snout": 2.6 },
	"oscar": { "h": 0.42, "back": "#3a3a30", "side": "#4f4a3a", "belly": "#7a5a3a", "fin": "#3a3a30", "tail": "round", "dorsal": "long", "pat": "orange_blotch", "eyespot": true },
	"pacu": { "h": 0.56, "back": "#5a6068", "side": "#9aa0a8", "belly": "#d8603a", "fin": "#6a7078", "tail": "soft", "dorsal": "small", "pat": "none", "blunt": true },
	"carp": { "h": 0.26, "back": "#6a6a3a", "side": "#b0a060", "belly": "#e2d8a8", "fin": "#8a7a48", "tail": "fork", "dorsal": "small", "pat": "scales" },
	"snakehead": { "h": 0.19, "back": "#4a4030", "side": "#7a6a4a", "belly": "#d8ccb0", "fin": "#5a4a38", "tail": "round", "dorsal": "eel", "pat": "mottle", "eyespot": true, "flat": true },
	"snapper": { "h": 0.36, "back": "#6a5048", "side": "#b07a68", "belly": "#e8c8b8", "fin": "#b0604a", "tail": "soft", "dorsal": "spiny", "pat": "scales" },
	"ladyfish": { "h": 0.19, "back": "#5a7486", "side": "#d0dae0", "belly": "#f4f6f8", "fin": "#b8c8a0", "tail": "deepfork", "dorsal": "small", "pat": "none" },
	"cichlid": { "h": 0.42, "back": "#4f5a3a", "side": "#8a8a4a", "belly": "#d8503a", "fin": "#6a6a40", "tail": "round", "dorsal": "long", "pat": "bars", "eyespot": true },
	"pinfish": { "h": 0.4, "back": "#5a7280", "side": "#c8ccb8", "belly": "#efeee0", "fin": "#d8c46a", "tail": "fork", "dorsal": "spiny", "pat": "stripes_gold", "ear": true },
	"seatrout": { "h": 0.24, "back": "#5a6a70", "side": "#b8c2c4", "belly": "#eef0f0", "fin": "#7a8a8a", "tail": "square", "dorsal": "spiny", "pat": "spots", "mouth": 1.3 },
	"sheepshead": { "h": 0.46, "back": "#5a5f60", "side": "#d8dad6", "belly": "#f0f0ec", "fin": "#4a4f50", "tail": "soft", "dorsal": "spiny", "pat": "bold_bars", "blunt": true },
	"barracuda": { "h": 0.14, "back": "#4a5a66", "side": "#c8d0d4", "belly": "#f0f2f2", "fin": "#5a6a74", "tail": "fork", "dorsal": "two", "pat": "dark_bars", "snout": 1.6, "teeth": true },
	"shark": { "h": 0.2, "back": "#6f7e88", "side": "#9aa8b0", "belly": "#eef0f0", "fin": "#6a7a84", "tail": "shark", "dorsal": "shark", "pat": "none", "gills5": true },
	"bonnet": { "h": 0.18, "back": "#7f8a8a", "side": "#a8b2b2", "belly": "#eef0f0", "fin": "#7a8686", "tail": "shark", "dorsal": "shark", "pat": "none", "gills5": true, "shovel": true },
	"mahi": { "h": 0.3, "back": "#2f8a6a", "side": "#c8c84a", "belly": "#f0e070", "fin": "#3a8aa8", "tail": "deepfork", "dorsal": "full", "pat": "blue_spots", "blunt": true },
	"kingfish": { "h": 0.16, "back": "#3e566a", "side": "#b4c0c8", "belly": "#f0f2f4", "fin": "#5a6a78", "tail": "lunate", "dorsal": "small", "pat": "none", "finlets": true, "snout": 1.3 },
	"tuna": { "h": 0.28, "back": "#1f2f4f", "side": "#8a98aa", "belly": "#eef0f2", "fin": "#d8c050", "tail": "lunate", "dorsal": "small", "pat": "gold_stripe", "finlets": true },
	"sailfish": { "h": 0.18, "back": "#1f3a6a", "side": "#8aa0b8", "belly": "#eef0f4", "fin": "#2a4a8a", "tail": "lunate", "dorsal": "sail", "pat": "dark_bars", "bill": true },
	"grouper": { "h": 0.38, "back": "#5a4a32", "side": "#8a7a52", "belly": "#c8b890", "fin": "#5a4a32", "tail": "round", "dorsal": "spiny", "pat": "mottle", "mouth": 1.8, "blunt": true },
	"arowana": { "h": 0.2, "back": "#7a8a90", "side": "#d8dee0", "belly": "#f2f4f4", "fin": "#a8b4b8", "tail": "round", "dorsal": "back", "pat": "bigscales", "upmouth": true, "barbels": true },
	# Ironwater's river fish
	"perch": { "h": 0.3, "back": "#4a5a2a", "side": "#c8b84a", "belly": "#f0e8c8", "fin": "#e07a3a", "tail": "fork", "dorsal": "two", "pat": "bars" },
	"crappie": { "h": 0.46, "back": "#3a4a4a", "side": "#b8c0b0", "belly": "#e8ece4", "fin": "#5a6a60", "tail": "soft", "dorsal": "long", "pat": "specks", "mouth": 1.3 },
	"smallmouth": { "h": 0.31, "back": "#5a4a2a", "side": "#a8864a", "belly": "#e8dcc0", "fin": "#8a6a3a", "tail": "square", "dorsal": "spiny", "pat": "bars_faint", "mouth": 1.4 },
	"walleye": { "h": 0.22, "back": "#5a5a2a", "side": "#c8b060", "belly": "#f0ecd8", "fin": "#8a7a40", "tail": "fork", "dorsal": "two", "pat": "mottle", "snout": 1.2, "teeth": true },
	"sauger": { "h": 0.21, "back": "#5a5232", "side": "#b0a070", "belly": "#ece6d0", "fin": "#7a7040", "tail": "fork", "dorsal": "two", "pat": "spots", "snout": 1.2 },
	"muskie": { "h": 0.17, "back": "#4a5a3a", "side": "#a8b07a", "belly": "#e8e8d0", "fin": "#b06a3a", "tail": "fork", "dorsal": "back", "pat": "dark_bars", "snout": 1.6, "teeth": true },
	"whitebass": { "h": 0.36, "back": "#4a5a6a", "side": "#d8dce0", "belly": "#f4f6f6", "fin": "#9aa4aa", "tail": "fork", "dorsal": "two", "pat": "stripes" },
	"striper": { "h": 0.27, "back": "#3a4a5a", "side": "#d0d6da", "belly": "#f4f6f6", "fin": "#7a8a94", "tail": "fork", "dorsal": "two", "pat": "stripes", "mouth": 1.3 },
	"skipjack": { "h": 0.24, "back": "#2f5a6a", "side": "#d0dce0", "belly": "#f4f6f8", "fin": "#8aa0a8", "tail": "deepfork", "dorsal": "small", "pat": "none", "upmouth": true },
	"drum": { "h": 0.4, "back": "#6a6a6a", "side": "#c8c8c0", "belly": "#eceae4", "fin": "#8a8a84", "tail": "round", "dorsal": "long", "pat": "scales", "blunt": true },
	"flathead": { "h": 0.22, "back": "#6a5a32", "side": "#a8905a", "belly": "#e8dcc0", "fin": "#6a5a38", "tail": "square", "dorsal": "small", "pat": "mottle", "whisk": true, "flat": true },
	"mirror": { "h": 0.3, "back": "#6a5a2a", "side": "#c0a060", "belly": "#e8d8a8", "fin": "#8a6a38", "tail": "fork", "dorsal": "long", "pat": "bigscales", "whisk": true },
	"paddle": { "h": 0.2, "back": "#4f5f6a", "side": "#8d9ca6", "belly": "#e4e8ea", "fin": "#5f6f7a", "tail": "shark", "dorsal": "small", "pat": "none", "bill": true },
	"sturgeon": { "h": 0.16, "back": "#5a5a50", "side": "#8a8a7a", "belly": "#d8d6c8", "fin": "#6a6a5a", "tail": "shark", "dorsal": "back", "pat": "spots", "barbels": true, "snout": 1.5 },
	"rainbow": { "h": 0.25, "back": "#4a6a4a", "side": "#c8c4ac", "belly": "#f0ece0", "fin": "#8a9a7a", "tail": "square", "dorsal": "small", "pat": "rainbow" },
	"brown": { "h": 0.26, "back": "#5a4a2a", "side": "#c8a868", "belly": "#f0e4c0", "fin": "#8a6a3a", "tail": "square", "dorsal": "small", "pat": "halo", "mouth": 1.3 },
	"brook": { "h": 0.25, "back": "#3a4a3a", "side": "#7a8a5a", "belly": "#e8783a", "fin": "#e8783a", "tail": "square", "dorsal": "small", "pat": "halo" },
	"chub": { "h": 0.24, "back": "#5a6a6a", "side": "#c8ccc4", "belly": "#eceee8", "fin": "#8a948e", "tail": "fork", "dorsal": "small", "pat": "line" },
	"pumpkinseed": { "h": 0.48, "back": "#4a6a5a", "side": "#c8a85a", "belly": "#e8a03a", "fin": "#6a7a5a", "tail": "soft", "dorsal": "spiny", "pat": "blue_spots", "ear": true },
	"other": { "h": 0.3, "back": "#5a6a74", "side": "#b8c4ca", "belly": "#eef0f0", "fin": "#7a8a94", "tail": "fork", "dorsal": "spiny", "pat": "none" },
}

## Which drawing goes with which catch. Specific names first, then words in the name.
const NAMES := {
	"Old Whiskers": "catfish", "The Bridge Troll": "grouper", "The Lunker of the 7th": "bass", "Mr. Chairman": "koi", "The Sewer King": "catfish",
	"The Isotope": "bass", "Reactor Goliath": "grouper", "Parking Lot Tarpon": "tarpon", "The Volcano Pacu": "pacu", "The Board President": "koi",
	"The Runway Gar": "gar", "The Night Manager": "catfish", "The Gray Ghost": "snook", "The Dock Monster": "grouper", "Old Glory": "tarpon",
	"Ol' Sawtooth": "shark", "The Golden Arowana": "arowana", "The Mayor's Pet": "goldfish", "Something From Another Dimension": "tilapia",
	"The Key to the City": "tarpon", "Walking Catfish": "walking", "Butterfly Koi": "butterfly", "Platinum Ogon Koi": "ogon", "Bonnethead Shark": "bonnet",
	"Mahi-Mahi": "mahi", "Blackfin Tuna": "tuna", "Jack Crevalle": "jack", "Spotted Seatrout": "seatrout", "Mangrove Snapper": "snapper",
	"Grass Carp": "carp", "Bullseye Snakehead": "snakehead", "Mayan Cichlid": "cichlid", "American Eel": "eel", "Silver Arowana": "arowana",
	"Goliath Grouper": "grouper", "Florida Gar": "gar",
	"Yellow Perch": "perch", "Black Crappie": "crappie", "Smallmouth Bass": "smallmouth", "Walleye": "walleye", "Sauger": "sauger",
	"Muskellunge": "muskie", "The Mayor": "muskie", "White Bass": "whitebass", "Striped Bass": "striper", "Skipjack Herring": "skipjack",
	"Freshwater Drum": "drum", "Flathead Catfish": "flathead", "Old Rivet": "flathead", "Common Carp": "carp", "Mirror Carp": "mirror",
	"The Brewmaster": "mirror", "Old Founder": "carp", "Longnose Gar": "gar", "Paddlefish": "paddle", "Lake Sturgeon": "sturgeon",
	"The Viaduct Ghost": "sturgeon", "Rainbow Trout": "rainbow", "Brown Trout": "brown", "The Foreman": "brown", "Brook Trout": "brook",
	"Creek Chub": "chub", "Pumpkinseed": "pumpkinseed", "Home Run Henry": "bass",
}
const WORDS := ["Bluegill", "Tilapia", "Peacock", "Bass", "Catfish", "Mullet", "Snook", "Tarpon", "Bowfin", "Goldfish", "Koi", "Eel", "Redfish", "Oscar",
	"Pacu", "Ladyfish", "Pinfish", "Sheepshead", "Barracuda", "Shark", "Kingfish", "Sailfish"]

## The picture at the top of a catch card: the fish on a pale print, gold-trimmed for a legend.
class Card extends Control:
	var n := ""
	var legend := false
	var junk := false
	var item := {}
	func _process(_dt: float) -> void: queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var t := Time.get_ticks_msec() / 1000.0
		draw_style_box(_box(), r)
		# faint water lines across the print
		for i in 5:
			var y := r.size.y * (0.2 + i * 0.16)
			var pts := PackedVector2Array()
			for j in 30: pts.append(Vector2(r.size.x * j / 29.0, y + sin(j * 0.6 + i + t * 0.8) * 2.0))
			draw_polyline(pts, Color(0.35, 0.55, 0.65, 0.08), 2.0)
		if legend:
			for i in 6:
				var a := t * 0.6 + i * TAU / 6
				var sp := r.get_center() + Vector2(cos(a) * r.size.x * 0.42, sin(a) * r.size.y * 0.36)
				_spark(sp, 5.0 + 2.0 * sin(t * 3.0 + i))
		if junk:
			if not JunkArt.draw(self, n, r.grow(-24), t): ItemIcons.draw_catch(self, item, Rect2(r.get_center() - Vector2(60, 60), Vector2(120, 120)))
		else: FishArt.draw(self, n, r.grow(-14), t, legend)
	func _box() -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = Color("#fbf6e6") if legend else Color("#eef4f2")
		b.border_color = Color("#d8a02a") if legend else Color(0.12, 0.16, 0.2, 0.25)
		b.set_border_width_all(3 if legend else 2)
		b.set_corner_radius_all(12)
		return b
	func _spark(p: Vector2, s: float) -> void:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0), p + Vector2(s * 0.25, s * 0.25), p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0), p + Vector2(-s * 0.25, -s * 0.25)]), Color("#f2c040"))

static func card(c: Dictionary) -> Control:
	var cd := Card.new()
	cd.n = str(c.get("n", ""))
	cd.legend = c.get("legend", false)
	cd.junk = c.get("junk", false)
	cd.item = c
	cd.custom_minimum_size = Vector2(0, 190)
	cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cd

static func kind_of(n: String) -> String:
	if NAMES.has(n): return NAMES[n]
	for w in WORDS:
		if n.contains(w): return (w as String).to_lower()
	return "other"

## The fish (or creature) named n, fitted into r, facing right. legend gives it a gold sheen.
static func draw(ci: CanvasItem, n: String, r: Rect2, t := 0.0, legend := false) -> void:
	match n:
		"Blue Crab": _crab(ci, r, t); return
		"Stingray": _ray(ci, r); return
		"Burmese Python": _snake(ci, r, t); return
		"Baby Gator": _gator(ci, r); return
		"Sewer Rat": _rat(ci, r); return
		"Glow-in-the-Dark Shrimp": _shrimp(ci, r, t); return
	var k: Dictionary = KINDS[kind_of(n)].duplicate()
	if n == "Glowing Bass" or n == "The Isotope" or n == "Reactor Goliath": k.glow = true
	if n == "Three-Eyed Tilapia" or n == "Something From Another Dimension": k.eyes = 3
	if n == "Something From Another Dimension": k.back = "#4a2a6a"; k.side = "#8a5ab0"; k.belly = "#d8b8f0"; k.glow = true
	if n == "Two-Headed Catfish": k.two = true
	if n == "Giant Tilapia": k.h = 0.44
	if n == "Snook XL": k.h = 0.25
	if n == "Mr. Chairman" or n == "The Golden Arowana" or n == "The Mayor's Pet" or n == "The Key to the City":
		k.back = "#b8861a"; k.side = "#e9b23a"; k.belly = "#f8e08a"; k.fin = "#d8a02a"; k.shine = true
		if k.pat == "koi": k.pat = "scales"
	if n == "The Volcano Pacu": k.back = "#4a2a2a"; k.side = "#a04a2a"; k.belly = "#f08a2a"; k.glow_col = Color(1, 0.45, 0.1)
	if n == "Escaped Koi": k.pat = "koi_calico"
	if n == "Old Glory": k.back = "#2a3a6a"; k.belly = "#f1f4f5"; k.pat = "bigscales"
	if n == "The Gray Ghost": k.back = "#6a7074"; k.side = "#b8bcbe"
	_fish(ci, k, r, t, legend)

static func _c(k: Dictionary, key: String) -> Color: return Color(k[key])

static func _fish(ci: CanvasItem, k: Dictionary, r: Rect2, t: float, legend: bool) -> void:
	var h: float = k.h
	var snout: float = k.get("snout", 1.0)
	# overall length so the whole thing (body, tail, bill) fits the rect
	var tail_k := 0.34 if k.tail != "eel" else 0.0
	var bill := 0.32 if k.get("bill", false) else 0.0
	var total := 1.0 + tail_k + bill
	var L := minf(r.size.x * 0.92 / total, r.size.y * 0.8 / maxf(h * 2.4 + (0.5 if k.dorsal == "sail" else 0.12), 0.3))
	var H := L * h
	var nose := Vector2(r.get_center().x + L * (total * 0.5 - bill), r.get_center().y + (H * 0.25 if k.dorsal == "sail" else 0.0))
	var arch := 0.12 if k.get("blunt", false) else 0.0
	var flat: bool = k.get("flat", false)
	var X := func(u: float) -> float: return nose.x - u * L
	var top := func(u: float) -> float:
		var ex := 0.55 if k.get("blunt", false) else (0.62 if snout < 1.5 else 0.85)
		var pk := pow(sin(PI * pow(clampf(u, 0.0, 1.0), ex)), 0.7)
		if k.tail == "eel": pk = minf(1.0, u * 12.0) * (1.0 - u * 0.75)
		return nose.y - H * (pk * 0.82 + 0.18 * smoothstep(0.55, 1.0, u)) * (1.0 + arch) * (0.85 if flat else 1.0) + _wave(k, u, L, t)
	var bot := func(u: float) -> float:
		var pk := pow(sin(PI * pow(clampf(u, 0.0, 1.0), 0.6)), 0.75)
		if k.tail == "eel": pk = minf(1.0, u * 12.0) * (1.0 - u * 0.75)
		return nose.y + H * (pk * 0.8 + 0.2 * smoothstep(0.55, 1.0, u)) * (1.1 if flat else 1.0) + _wave(k, u, L, t)
	var at := func(u: float, v: float) -> Vector2:   # v -1 top edge, 0 middle, 1 bottom edge
		var tp: float = top.call(u); var bt: float = bot.call(u)
		var mid := (tp + bt) * 0.5
		return Vector2(X.call(u), mid + v * (bt - tp) * 0.5)
	var fin := _c(k, "fin")
	var outline := Color(0.12, 0.14, 0.16, 0.85)
	var lw := maxf(1.2, L * 0.008)
	var gl: bool = k.get("glow", false)
	if gl:
		var gc: Color = k.get("glow_col", Color(0.6, 1.0, 0.35))
		for i in 4: Art.ellipse(ci, nose + Vector2(-L * 0.5, 0), L * (0.62 + i * 0.06), H * (1.4 + i * 0.2), Color(gc, 0.07))
	# tail
	var tb: Vector2 = at.call(1.0, 0.0)
	var th: float = (bot.call(1.0) - top.call(1.0)) * 0.5
	var tl := L * 0.3
	var tpts := PackedVector2Array()
	match k.tail:
		"fork", "deepfork":
			var dk := 0.55 if k.tail == "deepfork" else 0.3
			tpts = [tb + Vector2(0, -th), tb + Vector2(-tl, -H * 0.95), tb + Vector2(-tl * (1.0 - dk), 0), tb + Vector2(-tl, H * 0.95), tb + Vector2(0, th)]
		"lunate":
			tpts = [tb + Vector2(0, -th), tb + Vector2(-tl * 0.6, -H * 0.5), tb + Vector2(-tl * 1.05, -H * 1.25), tb + Vector2(-tl * 0.55, 0), tb + Vector2(-tl * 1.05, H * 1.25), tb + Vector2(-tl * 0.6, H * 0.5), tb + Vector2(0, th)]
		"square", "soft":
			var notch := 0.12 if k.tail == "soft" else 0.0
			tpts = [tb + Vector2(0, -th), tb + Vector2(-tl * 0.95, -H * 0.8), tb + Vector2(-tl * (1.0 - notch), 0), tb + Vector2(-tl * 0.95, H * 0.8), tb + Vector2(0, th)]
		"round":
			tpts.append(tb + Vector2(0, -th))
			for i in 9:
				var a := -PI * 0.5 + i * PI / 8.0
				tpts.append(tb + Vector2(-tl * 0.2 - cos(a) * tl * 0.75, sin(a) * H * 0.75))
			tpts.append(tb + Vector2(0, th))
		"veil":
			for i in 13:
				var a := -PI * 0.5 + i * PI / 12.0
				var wv := sin(t * 2.0 + i * 0.6) * 0.06
				tpts.append(tb + Vector2(-tl * (0.4 + 1.0 * absf(sin(a * 2.0)) + wv) * 1.1, sin(a) * H * 1.1))
			tpts.insert(0, tb + Vector2(0, -th)); tpts.append(tb + Vector2(0, th))
		"shark":
			tpts = [tb + Vector2(0, -th), tb + Vector2(-tl * 1.1, -H * 1.3), tb + Vector2(-tl * 0.75, -H * 0.2), tb + Vector2(-tl * 0.55, H * 0.6), tb + Vector2(0, th)]
		_: pass
	if tpts.size() > 2:
		ci.draw_colored_polygon(tpts, fin)
		ci.draw_polyline(tpts, outline, lw)
		for i in range(1, 6):
			var f := i / 6.0
			ci.draw_line(tb, tb.lerp(tpts[int(f * (tpts.size() - 1))], 0.92), Color(0, 0, 0, 0.12), lw * 0.6)
		if k.get("tailspot", false) or (k.get("eyespot", false) and k.tail != "round"):
			ci.draw_circle(tb + Vector2(L * 0.04, 0), H * 0.16, Color("#1a1a1a"))
			ci.draw_arc(tb + Vector2(L * 0.04, 0), H * 0.18, 0, TAU, 20, Color("#f2b134"), lw)
	# fins behind the body: dorsal and anal
	var dorsal := PackedVector2Array()
	match k.dorsal:
		"spiny":
			dorsal.append(at.call(0.28, -1.0))
			for i in 7: dorsal.append((at.call(0.3 + i * 0.07, -1.0) as Vector2) + Vector2(0, -H * (0.45 if i % 2 == 0 else 0.32) * (1.0 - i * 0.06)))
			dorsal.append(at.call(0.78, -1.0))
		"long", "full":
			var u0 := 0.12 if k.dorsal == "full" else 0.3
			dorsal.append(at.call(u0, -1.0))
			for i in 8:
				var u := u0 + (0.92 - u0) * i / 7.0
				dorsal.append((at.call(u, -1.0) as Vector2) + Vector2(0, -H * (0.38 if k.dorsal == "full" else 0.24) * (1.0 - i * 0.04)))
			dorsal.append(at.call(0.95, -1.0))
		"small", "two":
			dorsal = [at.call(0.36, -1.0), (at.call(0.44, -1.0) as Vector2) + Vector2(-L * 0.02, -H * 0.5), at.call(0.55, -1.0)]
			if k.dorsal == "two": ci.draw_colored_polygon(PackedVector2Array([at.call(0.7, -1.0), (at.call(0.74, -1.0) as Vector2) + Vector2(0, -H * 0.4), at.call(0.8, -1.0)]), fin)
		"back":
			dorsal = [at.call(0.68, -1.0), (at.call(0.76, -1.0) as Vector2) + Vector2(0, -H * 0.45), at.call(0.9, -1.0)]
		"sail":
			dorsal.append(at.call(0.12, -1.0))
			for i in 9:
				var u := 0.14 + i * 0.075
				dorsal.append((at.call(u, -1.0) as Vector2) + Vector2(0, -H * 2.2 * sin(PI * (0.15 + i / 8.0 * 0.8)) * (1.0 + sin(t * 1.5 + i) * 0.02)))
			dorsal.append(at.call(0.8, -1.0))
		"shark":
			dorsal = [at.call(0.32, -1.0), (at.call(0.46, -1.0) as Vector2) + Vector2(-L * 0.02, -H * 0.9), at.call(0.52, -1.0)]
		"eel":
			for i in 20: dorsal.append((at.call(0.25 + i * 0.04, -1.0) as Vector2) + Vector2(0, -H * 0.5))
			for i in range(19, -1, -1): dorsal.append(at.call(0.25 + i * 0.04, -1.0))
	if dorsal.size() > 2:
		ci.draw_colored_polygon(dorsal, Color(fin, 0.95))
		ci.draw_polyline(dorsal, outline, lw)
		if k.dorsal == "sail":
			for i in 10: ci.draw_circle((at.call(0.2 + i * 0.06, -1.0) as Vector2) + Vector2(0, -H * 1.1), H * 0.08, Color("#0f2050"))
	if k.tail != "eel":
		var anal := PackedVector2Array([at.call(0.62, 1.0), (at.call(0.72, 1.0) as Vector2) + Vector2(-L * 0.02, H * 0.38), at.call(0.82, 1.0)])
		if k.get("longfins", false): anal = PackedVector2Array([at.call(0.55, 1.0), (at.call(0.75, 1.0) as Vector2) + Vector2(-L * 0.06, H * 0.9), at.call(0.85, 1.0)])
		ci.draw_colored_polygon(anal, fin); ci.draw_polyline(anal, outline, lw)
		var pelv := PackedVector2Array([at.call(0.3, 1.0), (at.call(0.36, 1.0) as Vector2) + Vector2(-L * 0.04, H * 0.42), at.call(0.4, 1.0)])
		ci.draw_colored_polygon(pelv, Art.shade(fin, -0.1)); ci.draw_polyline(pelv, outline, lw)
	if k.get("finlets", false):
		for i in 5:
			var fp: Vector2 = at.call(0.8 + i * 0.04, -1.0)
			ci.draw_colored_polygon(PackedVector2Array([fp, fp + Vector2(-L * 0.02, -H * 0.12), fp + Vector2(-L * 0.025, 0)]), Color("#e8c840"))
			var fb: Vector2 = at.call(0.8 + i * 0.04, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([fb, fb + Vector2(-L * 0.02, H * 0.12), fb + Vector2(-L * 0.025, 0)]), Color("#e8c840"))
	# the body, shaded from back to belly
	var N := 28
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	var back := _c(k, "back"); var side := _c(k, "side"); var belly := _c(k, "belly")
	for i in N + 1:
		var u := float(i) / N
		poly.append(Vector2(X.call(u), top.call(u)))
	for i in range(N, -1, -1):
		var u := float(i) / N
		poly.append(Vector2(X.call(u), bot.call(u)))
	var rows := 6
	for j in rows:
		var v0 := -1.0 + 2.0 * j / rows
		var v1 := -1.0 + 2.0 * (j + 1) / rows
		var c0 := _grad(back, side, belly, (v0 + 1.0) * 0.5)
		var c1 := _grad(back, side, belly, (v1 + 1.0) * 0.5)
		var strip := PackedVector2Array(); var sc := PackedColorArray()
		for i in N + 1:
			var u := float(i) / N
			strip.append(at.call(u, v0)); sc.append(c0)
		for i in range(N, -1, -1):
			var u := float(i) / N
			strip.append(at.call(u, v1)); sc.append(c1)
		ci.draw_polygon(strip, sc)
	# markings
	_markings(ci, k, at, L, H, t)
	if k.get("shine", false) or legend:
		for i in 3:
			var sh := PackedVector2Array()
			for j in 12:
				var u := 0.12 + j * 0.06
				sh.append((at.call(u, -0.55 + i * 0.08) as Vector2) + Vector2(sin(t * 1.2 + u * 4.0) * 1.5, 0))
			ci.draw_polyline(sh, Color(1, 1, 0.9, 0.25 - i * 0.06), H * 0.08)
	# a light sheen along the back
	var hl := PackedVector2Array()
	for i in 14: hl.append(at.call(0.08 + i * 0.055, -0.65))
	ci.draw_polyline(hl, Color(1, 1, 1, 0.18), maxf(1.0, H * 0.07))
	ci.draw_polyline(poly, outline, lw)
	# head: gill cover, eye, mouth
	var gill := PackedVector2Array()
	for i in 9:
		var v := -0.75 + i * 0.19
		gill.append((at.call(0.2 + (0.04 if k.get("blunt", false) else 0.0), v) as Vector2) + Vector2(cos(v * 1.2) * L * 0.03, 0))
	ci.draw_polyline(gill, Color(0, 0, 0, 0.35), lw)
	if k.get("gills5", false):
		for i in 5: ci.draw_line(at.call(0.2 + i * 0.022, -0.3), at.call(0.2 + i * 0.022, 0.35), Color(0, 0, 0, 0.3), lw)
	if k.get("ear", false): Art.ellipse(ci, at.call(0.21, -0.2), L * 0.025, H * 0.13, Color("#1a2228"))
	var pect := PackedVector2Array([at.call(0.23, 0.2), (at.call(0.33, 0.45) as Vector2) + Vector2(0, H * 0.1), at.call(0.27, 0.45)])
	if k.get("longfins", false): pect = PackedVector2Array([at.call(0.23, 0.2), (at.call(0.42, 0.9) as Vector2) + Vector2(0, H * 0.6), at.call(0.27, 0.5)])
	ci.draw_colored_polygon(pect, Color(fin, 0.85)); ci.draw_polyline(pect, Color(0, 0, 0, 0.3), lw * 0.8)
	var eye_u := 0.08 if k.get("blunt", false) else 0.075 * (1.0 if snout < 1.5 else snout * 0.6)
	if k.get("shovel", false): eye_u = 0.05
	var eye: Vector2 = at.call(eye_u, -0.25 if not k.get("flat", false) else -0.35)
	var er := maxf(2.0, H * 0.13)
	var eyes: int = k.get("eyes", 1)
	for e in eyes:
		var ep := eye + Vector2(-er * 2.4 * e, -er * 0.4 * e) if eyes == 3 and e > 0 else eye
		if eyes == 3 and e == 2: ep = eye + Vector2(-er * 1.2, -er * 1.4)
		ci.draw_circle(ep, er, Color("#f2e6b8") if not k.get("glow", false) else Color("#d8ff9a"))
		ci.draw_circle(ep + Vector2(er * 0.15, 0), er * 0.62, Color("#141414"))
		ci.draw_circle(ep + Vector2(er * 0.35, -er * 0.3), er * 0.22, Color(1, 1, 1, 0.9))
	var mouth: Vector2 = at.call(0.01 * snout, 0.15)
	var mk: float = k.get("mouth", 1.0)
	if k.get("upmouth", false):
		ci.draw_line(at.call(0.005, -0.1), (at.call(0.06, 0.25) as Vector2), outline, lw * 1.2)
	else:
		ci.draw_line(mouth, mouth + Vector2(-L * 0.045 * mk, H * 0.06), outline, lw * 1.2)
	if k.get("teeth", false):
		for i in 4: ci.draw_line(mouth + Vector2(-L * 0.01 * i, 0), mouth + Vector2(-L * 0.01 * i, H * 0.06), Color.WHITE, lw * 0.6)
	if k.get("whisk", false):
		for i in 3:
			var wb: Vector2 = at.call(0.02, 0.1 + i * 0.1)
			var wl := L * (0.16 - i * 0.03) * (1.0 if k.get("flat", false) else 0.4)
			ci.draw_polyline(PackedVector2Array([wb, wb + Vector2(wl * 0.4, H * 0.15 + i * H * 0.08), wb + Vector2(wl * 0.6, H * 0.4 + i * H * 0.12)]), Color("#2a2a2a"), lw)
	if k.get("barbels", false):
		var cb: Vector2 = at.call(0.03, 0.7)
		ci.draw_line(cb, cb + Vector2(L * 0.07, -H * 0.1), Color("#5a6066"), lw)
	if k.get("bill", false):
		var bp: Vector2 = at.call(0.0, -0.05)
		ci.draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -H * 0.08), bp + Vector2(L * 0.32, 0), bp + Vector2(0, H * 0.08)]), Art.shade(back, -0.1))
	if k.get("two", false):
		# the second head, of course
		var hp: Vector2 = at.call(0.06, -1.0) + Vector2(L * 0.02, -H * 0.15)
		Art.ellipse(ci, hp, L * 0.09, H * 0.38, back)
		Art.ellipse(ci, hp + Vector2(0, H * 0.12), L * 0.08, H * 0.2, side)
		ci.draw_circle(hp + Vector2(L * 0.03, -H * 0.1), er * 0.9, Color("#f2e6b8")); ci.draw_circle(hp + Vector2(L * 0.035, -H * 0.1), er * 0.55, Color("#141414"))
		for i in 2: ci.draw_polyline(PackedVector2Array([hp + Vector2(L * 0.08, H * 0.1), hp + Vector2(L * 0.16, H * (0.1 + i * 0.2))]), Color("#2a2a2a"), lw)

## Eels wriggle: the whole body bends in a slow S.
static func _wave(k: Dictionary, u: float, L: float, t: float) -> float:
	if k.tail != "eel": return 0.0
	return sin(u * 7.0 - t * 2.0) * L * 0.05 * smoothstep(0.0, 0.3, u)

static func _grad(a: Color, b: Color, c: Color, f: float) -> Color:
	return a.lerp(b, f / 0.5) if f < 0.5 else b.lerp(c, (f - 0.5) / 0.5)

static func _markings(ci: CanvasItem, k: Dictionary, at: Callable, L: float, H: float, t: float) -> void:
	var dark := Art.shade(_c(k, "back"), -0.35)
	match k.pat:
		"bars", "bars_faint", "bold_bars", "dark_bars", "bars3":
			var n := 3 if k.pat == "bars3" else 6
			var a := 0.12 if k.pat == "bars_faint" else 0.55 if k.pat == "bold_bars" else 0.28
			for i in n:
				var u := 0.3 + i * (0.55 / n)
				var bar := PackedVector2Array([at.call(u, -0.95), at.call(u + 0.035, -0.95), at.call(u + 0.03, 0.5 if k.pat != "bold_bars" else 0.85), at.call(u - 0.005, 0.5 if k.pat != "bold_bars" else 0.85)])
				ci.draw_colored_polygon(bar, Color(Color("#141414") if k.pat == "bold_bars" else dark, a))
		"blotch_line":
			var pts := PackedVector2Array()
			for i in 16: pts.append((at.call(0.22 + i * 0.045, -0.05) as Vector2) + Vector2(0, sin(i * 1.7) * H * 0.07))
			ci.draw_polyline(pts, Color(dark, 0.6), H * 0.2)
		"line":
			var pts := PackedVector2Array()
			for i in 18: pts.append(at.call(0.2 + i * 0.045, -0.1))
			ci.draw_polyline(pts, Color("#1a1a1a"), maxf(1.5, H * 0.07))
		"gold_stripe":
			var pts := PackedVector2Array()
			for i in 16: pts.append(at.call(0.2 + i * 0.045, -0.35))
			ci.draw_polyline(pts, Color("#c8b04a", 0.7), maxf(1.5, H * 0.08))
		"stripes", "stripes_gold":
			for j in 4:
				var pts := PackedVector2Array()
				for i in 16: pts.append(at.call(0.2 + i * 0.045, -0.6 + j * 0.3))
				ci.draw_polyline(pts, Color(Color("#d8c050") if k.pat == "stripes_gold" else dark, 0.3), maxf(1.0, H * 0.05))
			if k.pat == "stripes_gold": ci.draw_circle(at.call(0.25, -0.35), H * 0.12, Color("#1a1a1a"))
		"spots", "specks", "blue_spots":
			for i in (26 if k.pat == "specks" else 18):
				var u := 0.18 + Town.hash2(i, 3) * 0.75
				var v := -0.85 + Town.hash2(i, 7) * (1.3 if k.pat != "blue_spots" else 1.1)
				var col := Color("#3a8ad8") if k.pat == "blue_spots" else Color("#1a1a1a")
				ci.draw_circle(at.call(u, v), H * (0.05 if k.pat == "specks" else 0.08), Color(col, 0.75))
		"mottle":
			for i in 14:
				var u := 0.15 + Town.hash2(i, 5) * 0.75
				var v := -0.7 + Town.hash2(i, 9) * 1.2
				Art.ellipse(ci, at.call(u, v), L * 0.04, H * 0.18, Color(dark, 0.35))
		"orange_blotch":
			for i in 7:
				var u := 0.25 + Town.hash2(i, 5) * 0.6
				var v := -0.3 + Town.hash2(i, 9) * 1.0
				Art.ellipse(ci, at.call(u, v), L * 0.05, H * 0.2, Color("#e2783a", 0.8))
		"koi", "koi_calico":
			var cols := [Color("#e2582a"), Color("#e2582a"), Color("#1a1a1a")] if k.pat == "koi_calico" else [Color("#e2582a")]
			for i in 6:
				var u := 0.1 + Town.hash2(i, 13) * 0.7
				var v := -0.7 + Town.hash2(i, 17) * 0.8
				Art.ellipse(ci, at.call(u, v), L * (0.06 + Town.hash2(i, 2) * 0.05), H * (0.3 + Town.hash2(i, 4) * 0.2), cols[i % cols.size()])
		"scales", "bigscales":
			var s := 0.045 if k.pat == "scales" else 0.07
			var u := 0.24
			var row := 0
			while u < 0.92:
				var v := -0.7 + (0.2 if row % 2 else 0.0)
				while v < 0.75:
					var p: Vector2 = at.call(u, v)
					ci.draw_arc(p, L * s * 0.5, PI * 0.5, PI * 1.5, 6, Color(0, 0, 0, 0.12), maxf(1.0, L * 0.004))
					v += 0.4 if k.pat == "scales" else 0.55
				u += s; row += 1
		"rainbow", "halo":
			if k.pat == "rainbow":
				var pts := PackedVector2Array()
				for i in 16: pts.append(at.call(0.18 + i * 0.047, 0.0))
				ci.draw_polyline(pts, Color("#e0708a", 0.55), maxf(2.0, H * 0.22))
			for i in 22:
				var u := 0.2 + Town.hash2(i, 21) * 0.72
				var v := -0.85 + Town.hash2(i, 23) * 1.3
				if k.pat == "halo":
					ci.draw_circle(at.call(u, v), H * 0.075, Color("#f4e8d0", 0.7))
					ci.draw_circle(at.call(u, v), H * 0.045, Color("#c8402a") if i % 3 == 0 else Color("#2a2018"))
				else: ci.draw_circle(at.call(u, v), H * 0.035, Color("#1a1a1a", 0.8))
		"gillspot":
			ci.draw_circle(at.call(0.22, -0.45), H * 0.1, Color("#1a1a1a"))
			for i in 8: ci.draw_line(at.call(0.7 + i * 0.03, -0.05), at.call(0.7 + i * 0.03, 0.15), Color(0, 0, 0, 0.2), 1.0)
	if k.get("eyespot", false) and k.tail == "round":
		var tb: Vector2 = at.call(0.92, 0.0)
		ci.draw_circle(tb, H * 0.14, Color("#1a1a1a"))
		ci.draw_arc(tb, H * 0.16, 0, TAU, 20, Color("#f2b134"), maxf(1.2, L * 0.006))

# ---------- not quite fish ----------

static func _crab(ci: CanvasItem, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y * 1.6) * 0.32
	var shell := Color("#3f6fa8")
	for sd in [-1, 1]:
		for i in 4:
			var b := c + Vector2(sd * s * 0.5, s * 0.05 + i * s * 0.08)
			ci.draw_polyline(PackedVector2Array([b, b + Vector2(sd * s * 0.35, -s * 0.08), b + Vector2(sd * s * 0.55, s * 0.18 + i * s * 0.03)]), Art.shade(shell, -0.15), s * 0.05)
		var cl := c + Vector2(sd * s * 0.55, -s * 0.3)
		ci.draw_line(c + Vector2(sd * s * 0.3, -s * 0.1), cl, shell, s * 0.08)
		Art.ellipse(ci, cl + Vector2(sd * s * 0.12, -s * 0.12), s * 0.18, s * 0.11, Color("#d8503a"), sd * 0.6)
	var body := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		var rr := 1.0 + (0.5 if absf(cos(a)) > 0.92 else 0.0)
		body.append(c + Vector2(cos(a) * s * 0.85 * rr, sin(a) * s * 0.38))
	ci.draw_colored_polygon(body, shell)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.1, 0.14, 0.2), 1.5)
	Art.ellipse(ci, c + Vector2(0, -s * 0.12), s * 0.5, s * 0.12, Color(1, 1, 1, 0.15))
	for sd in [-1, 1]:
		ci.draw_circle(c + Vector2(sd * s * 0.12, -s * 0.42), s * 0.05, Color("#141414"))

static func _ray(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x * 0.5, r.size.y * 0.9) * 0.55
	var body := PackedVector2Array([c + Vector2(s * 0.9, 0), c + Vector2(0, -s * 0.8), c + Vector2(-s * 0.7, 0), c + Vector2(0, s * 0.8)])
	ci.draw_line(c + Vector2(-s * 0.6, 0), c + Vector2(-s * 1.9, s * 0.1), Color("#5a5048"), s * 0.05)
	ci.draw_colored_polygon(body, Color("#7a6f62"))
	ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.15, 0.12, 0.1), 1.5)
	for i in 12: ci.draw_circle(c + Vector2((Town.hash2(i, 2) - 0.5) * s, (Town.hash2(i, 5) - 0.5) * s * 0.8), s * 0.03, Color(0.3, 0.25, 0.2, 0.5))
	for sd in [-1, 1]: ci.draw_circle(c + Vector2(s * 0.45, sd * s * 0.12), s * 0.05, Color("#141414"))

static func _snake(ci: CanvasItem, r: Rect2, t: float) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var f := i / 39.0
		pts.append(Vector2(r.position.x + r.size.x * (0.08 + f * 0.8), r.get_center().y + sin(f * TAU * 1.3 + t) * r.size.y * 0.22))
	var w := r.size.y * 0.16
	ci.draw_polyline(pts, Color("#5a4a2a"), w + 3)
	ci.draw_polyline(pts, Color("#c8a85a"), w)
	for i in range(2, 38, 3): Art.ellipse(ci, pts[i], w * 0.45, w * 0.3, Color("#6a5a32"))
	var hd: Vector2 = pts[39]
	Art.ellipse(ci, hd + Vector2(w * 0.4, 0), w * 0.9, w * 0.6, Color("#b8984a"))
	ci.draw_circle(hd + Vector2(w * 0.7, -w * 0.2), w * 0.12, Color("#141414"))
	ci.draw_line(hd + Vector2(w * 1.2, 0), hd + Vector2(w * 1.6, sin(t * 6.0) * w * 0.2), Color("#d8503a"), 1.5)

static func _gator(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var L := minf(r.size.x * 0.45, r.size.y * 1.6)
	var col := Color("#4a6a3a")
	var belly := Color("#c8c890")
	# legs, tail, body, snout
	for lx in [-0.25, 0.3]:
		ci.draw_polyline(PackedVector2Array([c + Vector2(L * lx, L * 0.1), c + Vector2(L * lx + L * 0.08, L * 0.24), c + Vector2(L * lx + L * 0.14, L * 0.26)]), Art.shade(col, -0.15), L * 0.06)
	var body := PackedVector2Array([c + Vector2(L * 1.0, L * 0.03), c + Vector2(L * 0.62, -L * 0.06), c + Vector2(L * 0.42, -L * 0.15), c + Vector2(L * 0.1, -L * 0.2),
		c + Vector2(-L * 0.35, -L * 0.17), c + Vector2(-L * 0.7, -L * 0.08), c + Vector2(-L * 1.05, -L * 0.01), c + Vector2(-L * 0.7, L * 0.05), c + Vector2(-L * 0.35, L * 0.14),
		c + Vector2(L * 0.1, L * 0.16), c + Vector2(L * 0.42, L * 0.1), c + Vector2(L * 0.62, L * 0.07)])
	ci.draw_colored_polygon(body, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(L * 0.42, L * 0.08), c + Vector2(L * 0.1, L * 0.14), c + Vector2(-L * 0.35, L * 0.12), c + Vector2(-L * 0.3, L * 0.06), c + Vector2(L * 0.1, L * 0.07)]), belly)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.1, 0.15, 0.08), 1.5)
	for i in 12:
		var x := 0.4 - i * 0.12
		var y := -0.2 + absf(x - 0.05) * 0.18
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(L * x, L * y), c + Vector2(L * (x - 0.04), L * (y - 0.05)), c + Vector2(L * (x - 0.08), L * y)]), Art.shade(col, -0.25))
	for i in 5: ci.draw_line(c + Vector2(L * (0.3 - i * 0.14), -L * 0.12), c + Vector2(L * (0.3 - i * 0.14), L * 0.1), Color(0, 0, 0, 0.12), 1.5)
	ci.draw_line(c + Vector2(L * 0.62, L * 0.04), c + Vector2(L * 1.0, L * 0.03), Color(0.1, 0.15, 0.08), 1.2)
	for i in 4: ci.draw_line(c + Vector2(L * (0.7 + i * 0.07), L * 0.035), c + Vector2(L * (0.7 + i * 0.07), L * 0.055), Color.WHITE, 1.2)
	ci.draw_circle(c + Vector2(L * 0.46, -L * 0.13), L * 0.04, Color("#e8d050")); ci.draw_circle(c + Vector2(L * 0.47, -L * 0.13), L * 0.02, Color("#141414"))

static func _rat(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y * 2.0) * 0.25
	ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.9, s * 0.1), c + Vector2(-s * 1.4, -s * 0.05), c + Vector2(-s * 1.8, s * 0.2)]), Color("#d8a0a0"), s * 0.06)
	Art.ellipse(ci, c, s, s * 0.5, Color("#7a7470"))
	Art.ellipse(ci, c + Vector2(s * 0.9, -s * 0.1), s * 0.45, s * 0.32, Color("#858080"))
	ci.draw_circle(c + Vector2(s * 0.75, -s * 0.45), s * 0.15, Color("#d8a0a0"))
	ci.draw_circle(c + Vector2(s * 1.05, -s * 0.18), s * 0.06, Color("#141414"))
	ci.draw_circle(c + Vector2(s * 1.33, -s * 0.05), s * 0.06, Color("#d88080"))
	for sd in [-0.4, 0.4]: ci.draw_line(c + Vector2(s * sd, s * 0.4), c + Vector2(s * sd + s * 0.1, s * 0.6), Color("#d8a0a0"), s * 0.08)

static func _shrimp(ci: CanvasItem, r: Rect2, t: float) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y * 2.0) * 0.26
	for i in 4: ci.draw_circle(c, s * (0.9 + i * 0.15), Color(0.6, 1.0, 0.35, 0.07))
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI * 1.1 - i * PI * 0.15
		pts.append(c + Vector2(cos(a) * s, sin(a) * s * 0.7))
	for i in 6:
		Art.ellipse(ci, pts[i], s * (0.32 - i * 0.03), s * (0.26 - i * 0.025), Color("#b8f07a") if i % 2 else Color("#9ce05a"))
	ci.draw_colored_polygon(PackedVector2Array([pts[6], pts[6] + Vector2(s * 0.3, -s * 0.2), pts[6] + Vector2(s * 0.3, s * 0.2)]), Color("#9ce05a"))
	var hd: Vector2 = pts[0]
	ci.draw_circle(hd + Vector2(-s * 0.1, -s * 0.1), s * 0.07, Color("#141414"))
	for i in 2: ci.draw_line(hd, hd + Vector2(-s * 0.9, -s * (0.5 + i * 0.25) + sin(t * 3.0 + i) * s * 0.05), Color("#7ac04a"), 1.2)
