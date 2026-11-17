class_name ParkedBoat
extends Node2D
## A boat you landed and left behind: the kayak pulled up on the bank, or the skiff tied up at the edge.
## It stays where you left it, rocking a little, until you come back and launch it again (K).

var kind := "kayak"
var t := 0.0

func _init(boat: String) -> void:
	kind = boat
	visible = false

func _process(dt: float) -> void:
	var pk := Player.parked()
	visible = pk.has(kind) and Game.S.gear.has(kind)
	if not visible: return
	var v: Array = pk[kind]
	position = Vector2(v[0], v[1])
	t += dt
	queue_redraw()

func _draw() -> void:
	if not Player.parked().has(kind): return
	var v: Array = Player.parked()[kind]
	var rot: float = v[2]
	if kind == "skiff":
		# bobbing on its line
		draw_set_transform(Vector2(0, 0.1 + sin(t * 1.3) * 0.03), rot + sin(t * 0.9) * 0.04, Vector2.ONE)
		Player.draw_skiff(self)
		draw_line(Vector2(1.45, 0), Vector2(1.85, 0.12), Color("#e9e0c8"), 0.04)
	else:
		# beached: still, its stern just in the water
		draw_set_transform(Vector2(0, 0.1), rot, Vector2.ONE)
		var tail := Vector2.from_angle(PI) * 1.05
		draw_arc(tail, 0.32 + sin(t * 1.6) * 0.04, PI * 0.6, PI * 1.4, 10, Color(1, 1, 1, 0.35), 0.04)
		Player.draw_kayak(self, null)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
