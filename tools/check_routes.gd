extends SceneTree
## Checks that everyone who walks a set route stays on land: every guard, patrol and cart in
## data/watch.json (Port Mullet) and data/watch2.json (Ironwater), and the sidewalks and park paths
## people stroll on. (Off-duty watchers go straight home and come straight back to the start of their
## route, so there's no walk to and from home to check.)
## usage (from the repo root): godot --headless --path godot -s ../tools/check_routes.gd
## Prints each problem and exits with 1 if there are any.

const FOOT := 0.3   # how far from the middle of their feet a walker takes up, in tiles
const BLOCK := [Town.T.BLD, Town.T.WALL, Town.T.HWALL, Town.T.FENCE, Town.T.TREE]

var bad := 0

func _initialize() -> void:
	for lv in [0, 1]:
		# Town.build() on its own: Town.ensure() also resets the ground and map pictures, which
		# need the whole game loaded
		Town.built = false
		Town.level = lv
		for a in [Town.buildings, Town.labels, Town.signs, Town.lamps, Town.decor, Town.bridges, Town.driveways]: a.clear()
		Town.build()
		var tname: String = ["Port Mullet", "Ironwater"][lv]
		var f := FileAccess.open("res://data/watch.json" if lv == 0 else "res://data/watch2.json", FileAccess.READ)
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		for w in d.watchers:
			if not w.has("path"): continue
			var pts: Array = []
			for p in w.path: pts.append(Vector2(p[0], p[1]))
			for i in pts.size():
				_seg(tname, w.id, "route leg %d" % (i + 1), pts[i], pts[(i + 1) % pts.size()])
		# the sidewalks and park paths people stroll on (town_life.gd)
		for y in Town.MH:
			for x in Town.MW:
				var t := Town.t_at(x, y)
				if (t == Town.T.WALK or t == Town.T.PATH) and Town.is_water_t(t):
					bad += 1; print("%s: walkway tile %d,%d is water" % [tname, x, y])
	print("routes checked: %d problem(s)" % bad)
	quit(1 if bad > 0 else 0)

func _seg(tname: String, id: String, what: String, a: Vector2, b: Vector2) -> void:
	var n := maxi(1, ceili(a.distance_to(b) * 20))
	var hits := {}
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for o in [Vector2.ZERO, Vector2(FOOT, 0), Vector2(-FOOT, 0), Vector2(0, FOOT), Vector2(0, -FOOT)]:
			var q: Vector2 = p + o
			var x := floori(q.x)
			var y := floori(q.y)
			var t := Town.t_at(x, y)
			var why := ""
			if Town.is_water_t(t) and not Town.in_bridge(x, y): why = "water"
			elif t in BLOCK: why = Town.T.keys()[t].to_lower()
			if why != "" and not hits.has(Vector2i(x, y)):
				hits[Vector2i(x, y)] = why
	if hits.is_empty(): return
	bad += 1
	var s := []
	for c in hits: s.append("%d,%d %s" % [c.x, c.y, hits[c]])
	print("%s: %s, %s (%s -> %s) crosses %s" % [tname, id, what, a, b, ", ".join(s)])
