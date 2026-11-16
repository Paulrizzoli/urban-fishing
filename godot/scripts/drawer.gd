class_name Drawer
extends Node2D
## A node that draws with a callable, in world tile coordinates.
## For y-sorted things: put the Drawer inside a sort node at (0, sort_y) and pass sort_y,
## so the Drawer sits back at the origin and can draw in plain tile coordinates.

var fn: Callable
var animated := false

static func make(draw_fn: Callable, sort_y := 0.0, anim := false) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(0, sort_y)
	var d := Drawer.new()
	d.fn = draw_fn
	d.animated = anim
	d.position = Vector2(0, -sort_y)
	holder.add_child(d)
	return holder

func _draw() -> void:
	if fn.is_valid(): fn.call(self)

func _process(_dt: float) -> void:
	if animated: queue_redraw()
