class_name Harbor
extends Node
## The boats tied up at Mullet Bay Marina. Now and then, by day, one backs out of its slip and heads out:
## across Mullet Bay to the east or west, or straight out offshore. A while later it comes back and ties
## up again. A boat under way sounds its horn when your kayak or skiff is in its path, slows a little and
## keeps coming; stay in its way and it rolls you over (main handles that). It never hits you without
## blowing the horn first, and it waits for you while it's easing in and out of its slip.

signal hit_player(boat)

const SLIP_Y := 160.4
const SLIPS := [[93.5, "#2b7ea6", false, "center console"], [103.5, "#e2583e", true, "sailboat"], [108.5, "#13807b", false, "fishing boat"]]
const HL := 1.5          # half length and half width of a hull, for bumping into
const HW := 0.58
const CRUISE := 3.0
const SLOW := 1.1        # backing out, or easing into the slip
const OUT_Y := 166.8     # where a boat backing out stops and turns
const LANE_Y := 168.5    # the line boats take across the bay
const WARN := 1.3        # seconds between the horn and a boat being able to hit you
const HIT_SPEED := 1.5   # slower than this, a bump is just a bump

var player: Player
var boats: Array = []
var leave_t := 0.0       # seconds until the next boat may head out
var test_go := false     # test hook: send a boat out right away
var test_route := -1     # test hook: which way it goes (0 west, 1 east, 2 offshore)
var test_hold := false   # test hook: everything stands still where it was put

class Boat extends Node2D:
	var slip := Vector2.ZERO
	var col := Color.WHITE
	var sail := false
	var what := "boat"
	var centre := Vector2.ZERO
	var heading := -PI / 2      # the way the bow points
	var speed := 0.0
	var state := "moored"       # moored, out, away, back
	var route: Array = []       # [point, reverse, speed] legs still to go
	var reverse := false
	var away_t := 0.0
	var horn_age := -1.0        # seconds since it sounded its horn at you, -1 if it hasn't
	var horn_cd := 0.0
	var waiting := false
	var last_wake := Vector2(-99, -99)
	var wait_t := 0.0
	var horn_fx := 0.0

	func out_of_sight() -> bool: return state == "away"

	func _process(dt: float) -> void:
		horn_fx = maxf(horn_fx - dt / 1.2, 0.0)
		position = centre + Vector2.from_angle(heading) * -1.2   # sort by the stern, like the old moored boats
		if Drawer.view.grow(4).has_point(centre): queue_redraw()

	func _draw() -> void:
		if state == "away": return
		var a := 1.0
		if centre.x < 1.0: a = clampf(centre.x + 3.0, 0.0, 4.0) / 4.0
		elif centre.x > Town.MW - 1.0: a = clampf(Town.MW + 3.0 - centre.x, 0.0, 4.0) / 4.0
		elif centre.y > Town.MH - 1.0: a = clampf(Town.MH + 3.0 - centre.y, 0.0, 4.0) / 4.0
		modulate.a = a
		Art.moored_boat(self, centre - position, Time.get_ticks_msec() / 1000.0, col, sail, heading + PI / 2)
		if horn_fx > 0.0: Art.horn_lines(self, centre - position + Vector2.from_angle(heading) * (HL + 0.2), heading, horn_fx, true)

func setup(ents: Node2D) -> void:
	for s in SLIPS:
		var b := Boat.new()
		b.slip = Vector2(s[0], SLIP_Y)
		b.centre = b.slip
		b.col = Color(s[1])
		b.sail = s[2]
		b.what = s[3]
		ents.add_child(b)
		boats.append(b)
	leave_t = randf_range(25.0, 70.0)

## The way out from a slip: back out, then across the bay one way or the other, or out to sea.
func _route_out(b: Boat) -> Array:
	var x := b.slip.x
	var legs := [[Vector2(x, OUT_Y), true, SLOW]]
	match test_route if test_route >= 0 else randi() % 3:
		0: legs.append_array([[Vector2(x - 7.0, LANE_Y), false, CRUISE], [Vector2(-5.0, LANE_Y + randf_range(-0.4, 0.6)), false, CRUISE]])
		1: legs.append_array([[Vector2(minf(x + 4.0, 110.0), LANE_Y), false, CRUISE], [Vector2(Town.MW + 5.0, LANE_Y + randf_range(-0.4, 0.6)), false, CRUISE]])
		_: legs.append_array([[Vector2(x - 3.0, 172.0), false, CRUISE], [Vector2(x - 6.0 + randf_range(-4, 4), Town.MH + 5.0), false, CRUISE]])
	return legs

## And back in: the same way, turned around, ending bow first in the slip.
func _route_in(b: Boat, from: Array) -> Array:
	var legs := []
	for i in range(from.size() - 2, 0, -1): legs.append([from[i][0], false, CRUISE])
	legs.append([Vector2(b.slip.x, OUT_Y + 0.5), false, CRUISE * 0.6])
	legs.append([b.slip, false, SLOW])
	return legs

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if player == null: return
	var h := Game.hour()
	var any_out := boats.any(func(o): return o.state != "moored")
	leave_t -= dt
	if (leave_t <= 0.0 or test_go) and not any_out and (test_go or (h >= 6.5 and h < 19.5)):
		var b: Boat = boats.pick_random()
		if test_go: b = boats[0]
		test_go = false
		b.route = _route_out(b)
		b.set_meta("out_route", b.route.duplicate(true))
		b.state = "out"
		leave_t = randf_range(70.0, 160.0)
	if test_hold: return
	for b in boats: _run(b, dt)

func _run(b: Boat, dt: float) -> void:
	match b.state:
		"moored":
			b.speed = 0.0; b.horn_age = -1.0
			b.heading = -PI / 2
			b.centre = b.slip
			return
		"away":
			b.away_t -= dt
			if b.away_t <= 0.0:
				var out: Array = b.get_meta("out_route")
				b.centre = out[-1][0]
				b.heading = (out[-2][0] - b.centre).angle()
				b.route = _route_in(b, out)
				b.state = "back"
			return
	if b.route.is_empty():
		if b.state == "out": b.state = "away"; b.away_t = randf_range(40.0, 110.0)
		else: b.state = "moored"
		return
	var leg: Array = b.route[0]
	var to: Vector2 = leg[0] - b.centre
	b.reverse = leg[1]
	var target: float = leg[2]
	if not b.reverse:
		var want := to.angle()
		var diff := absf(angle_difference(b.heading, want))
		b.heading = rotate_toward(b.heading, want, 0.9 * dt)
		if diff > PI / 2: target *= 0.2                       # swinging the bow round
		elif diff > 0.4: target *= 0.6
	# what's in the way: your kayak or skiff
	b.waiting = false
	var mv := Vector2.from_angle(b.heading) * (-1.0 if b.reverse else 1.0)
	b.horn_cd = maxf(b.horn_cd - dt, 0.0)
	var in_path := false
	if player.in_boat():
		# look along where it's headed (the next leg), not just where the bow points mid-turn
		var look := mv if b.reverse or to.length() < 0.5 else to.normalized()
		var rel := player.position - b.centre
		var ahead := rel.dot(look)
		var lat := absf(rel.dot(look.orthogonal()))
		in_path = ahead > 0.0 and ahead < 10.0 and lat < 1.7
		if in_path:
			if b.horn_cd <= 0.0 and (target >= CRUISE * 0.5 or ahead < HL + 3.0):
				b.horn_cd = 3.0
				b.horn_fx = 1.0
				if b.horn_age < 0.0: b.horn_age = 0.0
				Sound.play("boathorn", clampf(-2.0 - b.centre.distance_to(player.position) * 0.8, -14.0, -2.0), 0.02)
			# easing in or out of the slip, or no warning yet: wait for you
			var close := ahead - HL - (1.0 if player.boat_kind() == "skiff" else 0.8)
			var warned := b.horn_age >= WARN and not Obstacles.player_busy
			if close < 2.0 and (target < CRUISE * 0.5 or not warned):
				target = 0.0; b.waiting = true
			elif warned: target = minf(target, CRUISE * 0.8)
			# you've been sitting in its way a while (fishing, say): it swings out around you
			if b.waiting and b.wait_t > 5.0 and not b.reverse:
				b.wait_t = 0.0
				var sd := -1.0 if rel.dot(mv.orthogonal()) > 0.0 else 1.0
				for k in [3.5, 5.0]:
					var around: Vector2 = b.centre + mv * 3.0 + mv.orthogonal() * sd * k
					if Player.boatable(floori(around.x), floori(around.y), "skiff"):
						b.route.insert(0, [around + mv * 3.0, false, CRUISE * 0.6])
						b.route.insert(0, [around, false, CRUISE * 0.6])
						break
	b.wait_t = b.wait_t + dt if b.waiting else 0.0
	if b.horn_age >= 0.0: b.horn_age += dt
	if not in_path and b.horn_age > 3.0: b.horn_age = -1.0
	b.speed = move_toward(b.speed, target, (3.0 if target < b.speed else 1.2) * dt)
	b.centre += mv * b.speed * dt
	# a wake behind it, through the water effects
	if b.speed > 1.0 and Drawer.view.grow(3).has_point(b.centre):
		var stern := b.centre - Vector2.from_angle(b.heading) * HL + Vector2(0, 0.1)
		if b.last_wake.distance_to(stern) > 0.3:
			b.last_wake = stern
			WaterFx.trail.append({ "p": stern, "a": b.heading, "t": 0.0, "kind": "skiff" })
	if to.length() < (0.15 if b.route.size() == 1 else 0.7):
		if b.route.size() == 1 and b.state == "back": b.centre = leg[0]
		b.route.remove_at(0)
	# ran into you
	if player.in_boat() and b.speed >= HIT_SPEED and b.horn_age >= WARN and not Obstacles.player_busy and player.bumps_boat(b):
		b.speed = 0.6
		hit_player.emit(b)
