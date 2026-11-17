class_name GroundChunk
extends Node2D
## Draws the fine ground detail for one 8x8-tile chunk: grass blades, asphalt grain, curbs,
## pavers, dock planks, shorelines and road paint. Drawn once; Godot culls chunks off screen.
## Coordinates are in tiles: the parent World node is scaled by Game.TS.

const CH := 8
var cx := 0
var cy := 0

func _init(chunk_x: int, chunk_y: int) -> void:
	cx = chunk_x; cy = chunk_y

func R(x: float, y: float, w: float, h: float, c: Color) -> void: draw_rect(Rect2(x, y, w, h), c)

func _draw() -> void:
	var X0 := cx * CH
	var Y0 := cy * CH
	var X1 := mini(Town.MW - 1, X0 + CH - 1)
	var Y1 := mini(Town.MH - 1, Y0 + CH - 1)
	for y in range(Y0, Y1 + 1):
		for x in range(X0, X1 + 1): _detail(x, y)
	_shore(X0, X1, Y0, Y1)
	_markings(X0, X1, Y0, Y1)

func _detail(x: int, y: int) -> void:
	var T := Town.T
	var t: int = Town.tile[Town.idx(x, y)]
	var h := Town.hash2(x, y)
	if t == T.TREE or t == T.BUSH: t = Ground.under(x, y)
	match t:
		T.GRASS, T.FAIR:
			var fair := t == T.FAIR
			var bank := Ground.is_coast(x, y)
			for k in (3 if fair else 6):
				var hx := Town.hash2(x * 7 + k, y * 13 - k)
				var hy := Town.hash2(x * 3 - k, y * 5 + k * 7)
				var bx := x + 0.08 + hx * 0.84
				var by := y + 0.14 + hy * 0.8
				if bank and not Ground.dry_at(Vector2(bx, by)): continue
				draw_line(Vector2(bx, by), Vector2(bx + (hx - 0.5) * 0.1, by - 0.15), Color(0.19, 0.39, 0.14, 0.32) if k % 2 else Color(0.75, 0.91, 0.55, 0.3), 0.035)
			if not fair and not bank and Town.hash2(x * 31, y * 17) > 0.965:
				var fc: Color = [Color("#fff6d8"), Color("#f7d64a"), Color("#f48fb1"), Color("#c9b6e4")][int(Town.hash2(x, y * 3) * 4)]
				for k in 3: draw_circle(Vector2(x + 0.25 + Town.hash2(k, x) * 0.5, y + 0.25 + Town.hash2(y, k) * 0.5), 0.06, fc)
			if fair: R(x, y, 1, 0.5, Color(1, 1, 1, 0.05))
			else: _reeds(x, y)
		T.ROAD:
			for k in 10:
				R(x + Town.hash2(k, x * 7 + y) * 0.95, y + Town.hash2(y * 5 + k, x) * 0.95, 0.05, 0.05, Color(1, 1, 1, 0.06) if k % 2 else Color(0, 0, 0, 0.1))
			if h > 0.93: R(x + 0.1, y + 0.2, 0.6, 0.45, Color(0, 0, 0, 0.08))
			if h < 0.04: draw_polyline(PackedVector2Array([Vector2(x + 0.1, y + 0.3), Vector2(x + 0.4, y + 0.45), Vector2(x + 0.55, y + 0.8)]), Color(0.08, 0.09, 0.1, 0.45), 0.025)
			_wheel_wear(x, y)
			# gutters: a darker strip where the asphalt meets the curb
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nt := Town.t_at(x + d.x, y + d.y)
				if nt == T.ROAD or nt == T.RUNWAY or Town.is_water_t(nt) or Town.in_bridge(x + d.x, y + d.y): continue
				var gx := x + 0.86 if d.x == 1 else float(x)
				var gy := y + 0.86 if d.y == 1 else float(y)
				R(gx, gy, 0.14 if d.x != 0 else 1.0, 0.14 if d.y != 0 else 1.0, Color(0.05, 0.05, 0.06, 0.22))
				var lx := x + 0.8 if d.x == 1 else x + 0.14
				var ly := y + 0.8 if d.y == 1 else y + 0.14
				R(lx if d.x != 0 else float(x), ly if d.y != 0 else float(y), 0.06 if d.x != 0 else 1.0, 0.06 if d.y != 0 else 1.0, Color(1, 1, 1, 0.03))
			# manhole covers
			if h > 0.4 and h < 0.406 and not Town.in_bridge(x, y):
				var mc := Vector2(x + 0.5, y + 0.5)
				draw_circle(mc + Vector2(0.03, 0.04), 0.3, Color(0, 0, 0, 0.25))
				draw_circle(mc, 0.3, Color("#5a5c5e"))
				draw_circle(mc, 0.25, Color("#3e4042"))
				for k in range(-2, 3): R(mc.x - 0.2, mc.y + k * 0.08 - 0.015, 0.4, 0.03, Color(0.55, 0.55, 0.56, 0.5))
				draw_arc(mc, 0.3, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.15), 0.03)
		T.WALK, T.DOOR:
			R(x, y, 1, 0.03, Color(0, 0, 0, 0.08)); R(x, y, 0.03, 1, Color(0, 0, 0, 0.08))
			if h > 0.9: draw_circle(Vector2(x + 0.5, y + 0.5), 0.22, Color(0, 0, 0, 0.05))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if Town.t_at(x + d.x, y + d.y) != T.ROAD: continue
				var cxp := x + 0.88 if d.x == 1 else float(x)
				var cyp := y + 0.88 if d.y == 1 else float(y)
				R(cxp, cyp, 0.12 if d.x != 0 else 1.0, 0.12 if d.y != 0 else 1.0, Color("#efe9da"))
				# the curb's lip: lit edge on the sidewalk side
				var ix := x + 0.84 if d.x == 1 else x + 0.12
				var iy := y + 0.84 if d.y == 1 else y + 0.12
				R(ix if d.x != 0 else float(x), iy if d.y != 0 else float(y), 0.04 if d.x != 0 else 1.0, 0.04 if d.y != 0 else 1.0, Color(0, 0, 0, 0.1))
				# now and then a storm drain inlet cut into the curb
				if Town.hash2(x * 13 + d.x, y * 7 + d.y) < 0.06:
					var sx := x + 0.82 if d.x == 1 else float(x) + (0.0 if d.x == -1 else 0.2)
					var sy := y + 0.82 if d.y == 1 else float(y) + (0.0 if d.y == -1 else 0.2)
					var dr := Rect2(sx, sy, 0.18 if d.x != 0 else 0.6, 0.18 if d.y != 0 else 0.6)
					R(dr.position.x, dr.position.y, dr.size.x, dr.size.y, Color("#1e2022"))
					for k in 4:
						if d.y != 0: R(dr.position.x + 0.05 + k * 0.14, dr.position.y + 0.02, 0.04, dr.size.y - 0.04, Color(0.5, 0.5, 0.5, 0.5))
						else: R(dr.position.x + 0.02, dr.position.y + 0.05 + k * 0.14, dr.size.x - 0.04, 0.04, Color(0.5, 0.5, 0.5, 0.5))
		T.CONC:
			if x % 2 == 0: R(x, y, 0.03, 1, Color(0, 0, 0, 0.07))
			if y % 2 == 0: R(x, y, 1, 0.03, Color(0, 0, 0, 0.07))
			if h > 0.92: draw_circle(Vector2(x + 0.5, y + 0.5), 0.25, Color(0.16, 0.16, 0.16, 0.1))
		T.PLAZA:
			for j in 2:
				for i in 2: R(x + i * 0.5 + 0.02, y + j * 0.5 + 0.02, 0.46, 0.46, Color("#e0cfb0") if (i + j + x + y) % 2 else Color("#efe5d0"))
		T.SAND:
			var coast := Ground.is_coast(x, y)
			for k in 7:
				var sp := Vector2(x + Town.hash2(k, x * 3 + y) * 0.92, y + Town.hash2(y * 2 + k, x) * 0.92)
				if coast and not Ground.dry_at(sp + Vector2(0.025, 0.025)): continue
				R(sp.x, sp.y, 0.05, 0.05, Color(0.59, 0.47, 0.24, 0.28) if k % 2 else Color(1, 1, 1, 0.4))
			if y >= 156 and h > 0.5 and not coast: draw_arc(Vector2(x + 0.5, y + 1.2), 0.6, PI * 1.2, PI * 1.8, 8, Color(0.67, 0.55, 0.31, 0.25), 0.03)
		T.PATH, T.HIDE:
			for k in 4: draw_circle(Vector2(x + Town.hash2(k, x) * 0.9 + 0.05, y + Town.hash2(y, k) * 0.9 + 0.05), 0.04, Color(0.55, 0.47, 0.31, 0.3))
		T.DOCK:
			for k in range(1, 5): R(x, y + k * 0.2, 1, 0.025, Color(0.24, 0.14, 0.06, 0.35))
			for k in 5: R(x, y + k * 0.2 + 0.03, 1, 0.04, Color(1, 0.94, 0.82, 0.12))
			if h > 0.5: R(x + 0.5, y, 0.025, 1, Color(0.16, 0.1, 0.04, 0.5))
			if (x + y) % 2 == 0:
				for p in [[-1, 0, 0.02, 0.42], [1, 0, 0.82, 0.42], [0, 1, 0.42, 0.82], [0, -1, 0.42, 0.02]]:
					if Town.is_water_t(Town.t_at(x + p[0], y + p[1])): draw_circle(Vector2(x + p[2] + 0.08, y + p[3] + 0.08), 0.1, Color("#5c3a22"))
		T.RUNWAY:
			for k in 8: R(x + Town.hash2(k, x * 5 + y) * 0.95, y + Town.hash2(y + k, x * 3) * 0.95, 0.05, 0.05, Color(1, 1, 1, 0.05) if k % 2 else Color(0, 0, 0, 0.1))
			if y == 99 and x % 3 == 0 and x > 86 and x < 108: R(x, y + 0.45, 0.6, 0.1, Color("#e9edf0"))
			if (x == 84 or x == 85 or x == 109 or x == 110) and y >= 97 and y <= 101:
				for k in 3: R(x + 0.1, y + 0.15 + k * 0.3, 0.8, 0.12, Color("#e9edf0"))
		T.SFLOOR: R(x, y + 0.5, 1, 0.03, Color(0, 0, 0, 0.25))
		T.WATER:
			if Town.region[Town.idx(x, y)] in FRESH and Town.depth[Town.idx(x, y)] <= 2: _lily_pads(x, y, h)
		T.DEEP:
			if h > 0.6: draw_arc(Vector2(x + h, y + 0.8), 0.5, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.07), 0.04)

## Ponds and lakes with fresh, still water get lily pads and reeds.
const FRESH := [1, 3, 4, 10, 11, 12, 17]

func _lily_pads(x: int, y: int, h: float) -> void:
	if h > 0.32: return
	for k in 1 + int(h * 9) % 3:
		var c := Vector2(x + 0.2 + Town.hash2(k, x * 5 + y) * 0.6, y + 0.2 + Town.hash2(y * 3 + k, x) * 0.6)
		var r := 0.13 + Town.hash2(x + k, y) * 0.1
		if Ground.is_coast(x, y) and Ground.land_at(c) > 0.36: continue   # not up on a curved bank
		var a := Town.hash2(k * 7, x + y) * TAU
		var pts := PackedVector2Array()
		for i in 15:
			var t := a + 0.5 + i * (TAU - 1.0) / 14
			pts.append(c + Vector2(cos(t), sin(t)) * r)
		pts.append(c)
		draw_colored_polygon(pts, Color("#3f8a3a"))
		draw_arc(c, r * 0.95, a + 0.5, a + TAU - 0.5, 12, Color("#6fb35a"), 0.025)
		draw_line(c, c + Vector2(cos(a + 2.6), sin(a + 2.6)) * r * 0.8, Color(0.2, 0.42, 0.2, 0.6), 0.015)
		if Town.hash2(x * 9 + k, y * 11) > 0.8:
			for i in 5: draw_circle(c + Vector2(cos(i * TAU / 5), sin(i * TAU / 5)) * 0.05, 0.05, Color("#f7c6d9"))
			draw_circle(c, 0.035, Color("#f7d64a"))

## Cattails and reeds on the bank, leaning out over the water.
func _reeds(x: int, y: int) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nt := Town.t_at(x + d.x, y + d.y)
		if not Town.is_water_t(nt) or not (Town.region[Town.idx(x + d.x, y + d.y)] in FRESH): continue
		if Town.hash2(x * 5 + d.x, y * 3 + d.y) > 0.45: continue
		for k in 6:
			var u := 0.1 + Town.hash2(k, x * 7 + y + d.y) * 0.8
			var base := Vector2(x + 0.5 + d.x * 0.42, y + 0.5 + d.y * 0.42) + Vector2(d.y, d.x) * (u - 0.5)
			if Ground.is_coast(x, y):
				# on a curved bank, walk out to where the water starts
				base = Vector2(x + 0.5, y + 0.5) + Vector2(d.y, d.x) * (u - 0.5)
				var n := 0
				while n < 30 and Ground.dry_at(base + Vector2(d.x, d.y) * 0.06): base += Vector2(d.x, d.y) * 0.05; n += 1
				if n >= 30: continue
			var lean := Vector2(d.x, d.y) * 0.18 + Vector2(0, -0.32 - Town.hash2(x, k) * 0.15)
			draw_line(base, base + lean, Color("#4f7f34") if k % 2 else Color("#6c9a3e"), 0.03)
			if k % 3 == 0: draw_line(base + lean * 0.8, base + lean * 1.05, Color("#7a4e2a"), 0.06)

const HARD := [Town.T.WALK, Town.T.CONC, Town.T.PLAZA, Town.T.ROAD, Town.T.DOCK, Town.T.SFLOOR, Town.T.HWALL, Town.T.FENCE, Town.T.BLD, Town.T.WALL, Town.T.DOOR, Town.T.RUNWAY, Town.T.GATE, Town.T.GAP, Town.T.GRATE]

func _shore(X0: int, X1: int, Y0: int, Y1: int) -> void:
	for y in range(Y0, Y1 + 1):
		for x in range(X0, X1 + 1):
			if not Town.is_water_t(Town.tile[Town.idx(x, y)]): continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if not Town.inb(nx, ny): continue
				var nt: int = Town.tile[Town.idx(nx, ny)]
				if Town.is_water_t(nt): continue
				# sandy shores and natural pond banks get a smooth curved edge from the ground shader instead
				if Ground.is_coast(x, y) and Ground.is_coast(nx, ny): continue
				var bands := [[0.18, Color(0.04, 0.12, 0.16, 0.2)], [0.05, Color(1, 1, 1, 0.2)]] if (nt in HARD or Town.in_bridge(nx, ny)) else \
					[[0.22, Color(0.59, 0.67, 0.47, 0.3)], [0.12, Color(0.85, 0.78, 0.59, 0.85)], [0.05, Color(0.47, 0.39, 0.24, 0.35)]]
				for b in bands:
					var w: float = b[0]
					if d.x != 0: R(x + 1 - w if d.x == 1 else float(x), y, w, 1, b[1])
					else: R(x, y + 1 - w if d.y == 1 else float(y), 1, w, b[1])

func _is_rd(x: int, y: int) -> bool: return Town.t_at(x, y) == Town.T.ROAD

## How far the road runs from (x, y) in a direction, up to lim tiles.
func _run(x: int, y: int, dx: int, dy: int, lim: int) -> int:
	var n := 0
	while n < lim and _is_rd(x + dx * (n + 1), y + dy * (n + 1)): n += 1
	return n

## Darker, smoother tracks where tires wear the asphalt, two per lane, on straight stretches of road.
func _wheel_wear(x: int, y: int) -> void:
	var col := Color(0.02, 0.02, 0.03, 0.075)
	var up := _run(x, y, 0, -1, 5)
	var dn := _run(x, y, 0, 1, 5)
	var lf := _run(x, y, -1, 0, 5)
	var rt := _run(x, y, 1, 0, 5)
	if up + dn + 1 <= 4 and lf + rt >= 4:
		var y0 := float(y - up)
		var bh := float(up + dn + 1)
		for lane in ([0.25, 0.75] if bh >= 2 else [0.5]):
			var cyl: float = y0 + bh * lane
			for o in [-0.28, 0.28]:
				var ty: float = cyl + o
				if ty >= y and ty < y + 1: R(x, ty - 0.09, 1, 0.18, col)
	elif lf + rt + 1 <= 4 and up + dn >= 4:
		var x0 := float(x - lf)
		var bw := float(lf + rt + 1)
		for lane in ([0.25, 0.75] if bw >= 2 else [0.5]):
			var cxl: float = x0 + bw * lane
			for o in [-0.28, 0.28]:
				var tx: float = cxl + o
				if tx >= x and tx < x + 1: R(tx - 0.09, y, 0.18, 1, col)

func _markings(X0: int, X1: int, Y0: int, Y1: int) -> void:
	var yel := Color("#e8c84a")
	for x in range(X0, X1 + 1):
		if x % 2: continue
		if Y0 <= 36 and Y1 >= 34 and _is_rd(x, 35) and not _is_rd(x, 33) and not _is_rd(x, 37): R(x, 35.44, 0.55, 0.12, yel)
		for yy in [83, 117, 136, 155]:
			if Y0 <= yy + 1 and Y1 >= yy and _is_rd(x, yy) and _is_rd(x, yy + 1) and not _is_rd(x, yy - 1) and not _is_rd(x, yy + 2) and not _on_hbridge(x, yy):
				R(x, yy + 0.94, 0.55, 0.12, yel)
	for y in range(Y0, Y1 + 1):
		if y % 2: continue
		for c in [[40, 39, 42], [58, 57, 60]]:
			if X0 <= c[0] + 1 and X1 >= c[0] and _is_rd(c[0], y) and _is_rd(c[0] + 1, y) and not _is_rd(c[1], y) and not _is_rd(c[2] + 1, y) and (c[0] != 40 or y < 50 or y > 54):
				R(c[0] + 1.44, y, 0.12, 0.55, yel)
		for c in [20, 96]:
			if X0 <= c + 1 and X1 >= c and y > 118 and _is_rd(c, y) and _is_rd(c + 1, y) and not _is_rd(c - 1, y) and not _is_rd(c + 2, y): R(c + 0.94, y, 0.12, 0.55, yel)
	var wh := Color(1, 1, 1, 0.6)
	var zebra_h := func(xa: int, xb: int, yy: float) -> void:
		if yy < Y0 - 1 or yy > Y1 + 1: return
		var xx := float(xa)
		while xx <= xb + 0.8:
			if _is_rd(floori(xx), floori(yy)) and xx >= X0 - 1 and xx <= X1 + 1: R(xx + 0.05, yy - 0.05, 0.22, 0.6, wh)
			xx += 0.4
	var zebra_v := func(xx: float, ya: int, yb: int) -> void:
		if xx < X0 - 1 or xx > X1 + 1: return
		var yy := float(ya)
		while yy <= yb + 0.8:
			if _is_rd(floori(xx), floori(yy)) and yy >= Y0 - 1 and yy <= Y1 + 1: R(xx - 0.05, yy + 0.05, 0.6, 0.22, wh)
			yy += 0.4
	for z in [[40, 42, 81.2], [40, 42, 85.2], [58, 60, 82.2], [40, 42, 33.2], [40, 42, 37.2], [58, 60, 37.2]]: zebra_h.call(z[0], z[1], z[2])
	for ab in [[40, 42], [20, 21], [96, 97]]:
		for yy in [116.2, 119.2, 135.2, 138.2, 154.2]: zebra_h.call(ab[0], ab[1], yy)
	for xc in [19.2, 22.2, 39.2, 43.2, 95.2, 98.2]:
		for ab in [[117, 118], [136, 137], [155, 156]]: zebra_v.call(xc, ab[0], ab[1])
	if Y0 <= 63 and Y1 >= 63:
		for x in range(X0, X1 + 1):
			if x % 3 == 0 and x <= 36: R(x, 63.94, 0.6, 0.1, wh)
	for d in Town.decor:
		if d.k == "parking":
			if d.x1 < X0 - 1 or d.x0 > X1 + 1 or d.y1 < Y0 - 1 or d.y0 > Y1 + 1: continue
			for x in range(d.x0 + 1, d.x1 + 1):
				if x >= X0 and x <= X1: R(x, d.y0 + 0.2, 0.06, d.y1 - d.y0 + 0.6, Color(1, 1, 1, 0.7))
		elif d.k == "green":
			if absf(d.x - (X0 + 4)) > 7 or absf(d.y - (Y0 + 4)) > 6: continue
			_ellipse(Vector2(d.x, d.y), 2.55, 1.75, Color("#7fb85a"))
			_ellipse(Vector2(d.x, d.y), 2.4, 1.6, Color("#a9dc7c"))
			_ellipse(Vector2(d.x - 0.4, d.y - 0.3), 1.4, 0.9, Color(1, 1, 1, 0.1))
			draw_circle(Vector2(d.x, d.y), 0.09, Color("#2a2a2a"))
			R(d.x, d.y - 1.4, 0.07, 1.4, Color("#555555"))
			draw_colored_polygon(PackedVector2Array([Vector2(d.x + 0.07, d.y - 1.4), Vector2(d.x + 0.8, d.y - 1.15), Vector2(d.x + 0.07, d.y - 0.9)]), Color("#e2583e"))
		elif d.k == "bench":
			if d.x < X0 - 1 or d.x > X1 + 2 or d.y < Y0 - 1 or d.y > Y1 + 2: continue
			R(d.x - 0.55, d.y - 0.05, 1.2, 0.3, Color(0, 0, 0, 0.2)); R(d.x - 0.6, d.y - 0.15, 1.2, 0.3, Color("#8a5a35"))

func _on_hbridge(x: int, yy: int) -> bool:
	for b in Town.bridges:
		if b.get("h", false) and x >= b.x0 and x <= b.x1 and b.y0 <= yy and b.y1 >= yy + 1: return true
	return false

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24: pts.append(c + Vector2(cos(i * TAU / 24) * rx, sin(i * TAU / 24) * ry))
	draw_colored_polygon(pts, col)
