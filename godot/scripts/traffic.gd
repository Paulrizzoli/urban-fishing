class_name Traffic
extends Node
## Cars driving around Port Mullet. Each car keeps to the right-hand lane of its street, picks a way
## at each crossing and slows behind other cars. Step out in front of one and it honks. A few drivers
## stop and wait for you; most slow a little and keep coming, and if you're still in the lane a moment
## after the horn they knock you down (main handles that). A car never hits you without honking first,
## and every car stops for you while you have a line in the water.
## Cars leave at the map edge or a dead end and a new one pulls in somewhere you can't see.

signal hit_player(car)

const WARN := 0.9          # seconds between the horn and a car being able to hit you
const HIT_SPEED := 1.2     # slower than this, a car just nudges you

const COUNT := 34

var player: Player
var test_hold := false          # test hook: the first car stands still where it was put
var holder: Node2D              # the y-sorted node the cars are drawn in
var cars: Array = []            # Car nodes

class Car extends Node2D:
	var d := Vector2i(1, 0)     # heading, one of the four directions
	var speed := 0.0
	var cruise := 3.6
	var ang := 0.0
	var col := Color.WHITE
	var L := 1.7
	var W := 0.82
	var turn_at := INF          # distance along d where the car turns
	var turn_d := Vector2i.ZERO
	var skip_to := -INF         # crossing already decided: don't look again until past this
	var last_cell := Vector2i(-99, -99)
	var fade := 0.0             # fades in when it appears, out when it leaves
	var leaving := false
	var braking := false
	var stuck := 0.0           # seconds stopped behind other cars
	var squeeze := 0.0         # after a long wait it ignores other cars for a moment and squeezes through
	var careful := false       # stops for you instead of driving on
	var horn_age := -1.0       # seconds since it honked at you, -1 if it hasn't
	var horn_cd := 0.0
	var horn_fx := 0.0        # the horn lines in front of it fade out over this

	func along() -> float: return position.dot(Vector2(d))

	func _process(dt: float) -> void:
		horn_fx = maxf(horn_fx - dt / 0.7, 0.0)
		if Drawer.view.grow(2).has_point(position): queue_redraw()

	func _draw() -> void:
		modulate.a = fade
		Art.car(self, Vector2.ZERO, ang, col, L, W)
		if braking:
			draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
			for sy in [-1, 1]: draw_rect(Rect2(-L / 2 - 0.02, sy * W * 0.3 - 0.08, 0.08, 0.16), Color("#ff3b2e"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if horn_fx > 0.0: Art.horn_lines(self, Vector2.from_angle(ang) * (L * 0.5 + 0.1), ang, horn_fx)

static func _road(x: int, y: int) -> bool: return Town.t_at(x, y) == Town.T.ROAD

## How many road tiles in a row run through (x, y) along step s, and where the run starts.
static func _run(x: int, y: int, s: Vector2i, cap := 8) -> Vector2i:
	var a := 0
	while a < cap and _road(x - s.x * (a + 1), y - s.y * (a + 1)): a += 1
	var b := 0
	while b < cap and _road(x + s.x * (b + 1), y + s.y * (b + 1)): b += 1
	return Vector2i(a, b)      # tiles before and after (x, y)

static func _right(d: Vector2i) -> Vector2i: return Vector2i(-d.y, d.x)

func setup(ents: Node2D) -> void:
	holder = ents
	for i in COUNT:
		var c := Car.new()
		var hue: String = Art.CAR_COLORS[i % Art.CAR_COLORS.size()]
		c.col = Color(hue)
		c.cruise = randf_range(3.0, 4.2)
		var big := randf() < 0.15
		c.L = 2.05 if big else randf_range(1.6, 1.8)
		c.W = 0.92 if big else 0.82
		holder.add_child(c)
		cars.append(c)
		_spawn(c, false)

## Put a car on a random straight bit of road, in its lane. Away from the screen unless anywhere is fine.
func _spawn(c: Car, hidden := true) -> void:
	var view := _view().grow(4)
	for tries in 200:
		var x := randi_range(1, Town.MW - 2)
		var y := randi_range(1, Town.MH - 2)
		if not _road(x, y): continue
		var hr := _run(x, y, Vector2i(1, 0))
		var vr := _run(x, y, Vector2i(0, 1))
		var d := Vector2i.ZERO
		var span := Vector2i.ZERO
		if vr.x + vr.y + 1 in [2, 3] and hr.x >= 3 and hr.y >= 3:
			d = Vector2i(1, 0) if randf() < 0.5 else Vector2i(-1, 0); span = Vector2i(y - vr.x, y + vr.y)
		elif hr.x + hr.y + 1 in [2, 3] and vr.x >= 3 and vr.y >= 3:
			d = Vector2i(0, 1) if randf() < 0.5 else Vector2i(0, -1); span = Vector2i(x - hr.x, x + hr.y)
		else: continue
		var w := float(span.y - span.x + 1)
		var centre := (span.x + span.y + 1) / 2.0
		var r := _right(d)
		var lane := centre + float(r.x + r.y) * w / 4.0
		var p := Vector2(x + 0.5, lane) if d.y == 0 else Vector2(lane, y + 0.5)
		if hidden and view.has_point(p): continue
		var clear := true
		for o in cars:
			if o != c and o.position.distance_to(p) < 3.0: clear = false; break
		if not clear or (player != null and player.position.distance_to(p) < 4.0): continue
		c.position = p
		c.d = d
		c.ang = Vector2(d).angle()
		c.speed = c.cruise
		c.turn_at = INF; c.skip_to = -INF; c.last_cell = Vector2i(-99, -99)
		c.leaving = false
		c.careful = randf() < 0.3
		c.horn_age = -1.0
		c.fade = 0.0 if hidden else 1.0
		return

func _view() -> Rect2:
	var vp := holder.get_viewport()
	var cam_rect := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return Rect2(cam_rect.position / Game.TS, cam_rect.size / Game.TS)

## How many cars are out for each graphics setting.
const ACTIVE := [12, 24, 34]

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var n: int = ACTIVE[Game.quality]
	for i in cars.size():
		var c: Car = cars[i]
		if i >= n:
			if c.visible: c.visible = false; c.leaving = true; c.fade = 0.0
			continue
		if not c.visible: c.visible = true; _spawn(c)
		if test_hold and i == 0: continue
		_drive(c, dt)

func _drive(c: Car, dt: float) -> void:
	var fw := Vector2(c.d)
	var side := Vector2(_right(c.d))
	if c.leaving:
		c.fade -= dt * 2.0
		c.position += fw * c.speed * dt
		if c.fade <= 0: _spawn(c)
		return
	c.fade = minf(c.fade + dt * 1.5, 1.0)
	# what's in front: other cars, and you
	var target := c.cruise
	var front_gap := INF
	for o in cars:
		if o == c or o.leaving or not o.visible or c.squeeze > 0.0: continue
		var rel: Vector2 = o.position - c.position
		var ahead := rel.dot(fw)
		if ahead > 0.2 and absf(rel.dot(side)) < 0.75: front_gap = minf(front_gap, ahead - (c.L + o.L) * 0.5)
	c.squeeze = maxf(c.squeeze - dt, 0.0)
	c.stuck = c.stuck + dt if (front_gap < 0.5 and c.speed < 0.1) else 0.0
	if c.stuck > 6.0: c.stuck = 0.0; c.squeeze = 1.5
	# you, in the street in front of it: honk, then stop (careful drivers, or you're fishing, or there
	# hasn't been time to warn you) or slow a little and keep coming
	c.horn_cd = maxf(c.horn_cd - dt, 0.0)
	var in_lane := false
	if player != null and not player.in_boat():
		var rel := player.position - c.position
		var ahead := rel.dot(fw)
		in_lane = ahead > 0.0 and ahead < 8.0 and absf(rel.dot(side)) < 0.9
		if in_lane:
			var gap := ahead - c.L * 0.5 - 0.3
			if c.horn_cd <= 0.0 and c.fade > 0.8:
				c.horn_cd = 2.2
				c.horn_fx = 1.0
				if c.horn_age < 0.0: c.horn_age = 0.0
				Sound.play("horn", clampf(-1.0 - ahead * 1.2, -12.0, -1.0), 0.06)
			if c.careful or player.fishing_pose or Obstacles.player_busy or c.horn_age < WARN: front_gap = minf(front_gap, gap)
			else: target = minf(target, c.cruise * 0.75)
	if c.horn_age >= 0.0: c.horn_age += dt
	if not in_lane and c.horn_age > 3.0: c.horn_age = -1.0
	if front_gap < 2.5: target = minf(target, c.cruise * clampf((front_gap - 0.4) / 2.1, 0.0, 1.0))
	# slow for a turn
	var to_turn := c.turn_at - c.along()
	if to_turn < 2.5: target = minf(target, 1.8)
	c.braking = target < c.speed - 0.3
	c.speed = move_toward(c.speed, target, (9.0 if c.braking else 2.5) * dt)
	c.position += fw * c.speed * dt
	c.ang = lerp_angle(c.ang, fw.angle(), minf(1.0, dt * 7.0))
	# drove into you
	if player != null and not player.in_boat() and c.speed >= HIT_SPEED and c.horn_age >= WARN and not c.careful and not Obstacles.player_busy \
			and Obstacles.box_hit(player.position, 0.32, c.position, c.ang, c.L * 0.5, c.W * 0.5):
		c.speed *= 0.4
		hit_player.emit(c)
	# turn when we reach the lane of the cross street
	if c.along() >= c.turn_at:
		var over := c.along() - c.turn_at
		c.position -= fw * over
		c.d = c.turn_d
		c.position += Vector2(c.d) * over
		c.turn_at = INF
		c.skip_to = c.along() + 1.5
		return
	# look at the tile under the front bumper
	var nose := c.position + fw * (c.L * 0.5 + 0.2)
	var cell := Vector2i(floori(nose.x), floori(nose.y))
	if cell == c.last_cell: return
	c.last_cell = cell
	if not _road(cell.x, cell.y):
		if c.turn_at == INF: c.leaving = true
		return
	if c.turn_at != INF or c.along() < c.skip_to: return
	# a crossing: road carries on to the side, well past this street's width
	var opts := []
	var span_end := -INF
	for d2 in [_right(c.d), -_right(c.d)]:
		var dv: Vector2i = d2
		var open := true
		for k in range(1, 5): open = open and _road(cell.x + dv.x * k, cell.y + dv.y * k)
		if not open: continue
		var probe := cell + dv * 4
		var run := _run(probe.x, probe.y, c.d, 4)
		var cw := run.x + run.y + 1
		if cw < 2 or cw > 3: continue
		# centre of the cross street, along d (in tile units, d may point either way)
		var lo: Vector2i = probe - c.d * run.x
		var hi: Vector2i = probe + c.d * run.y
		var centre_pt := (Vector2(lo) + Vector2(hi)) * 0.5 + Vector2(0.5, 0.5)
		var cc := centre_pt.dot(Vector2(c.d))
		var r2 := _right(dv)
		var at := cc + float(r2.x * c.d.x + r2.y * c.d.y) * float(cw) / 4.0
		if at <= c.along() + 0.3: continue
		opts.append([dv, at])
		span_end = maxf(span_end, cc + cw * 0.5)
	if opts.is_empty(): return
	c.skip_to = span_end + 0.5
	# can we go straight on past the crossing?
	var past := c.position + fw * (span_end - c.along() + 1.5)
	var straight := _road(floori(past.x), floori(past.y))
	if straight and randf() < 0.55: return
	var pick: Array = opts.pick_random()
	c.turn_d = pick[0]
	c.turn_at = pick[1]
