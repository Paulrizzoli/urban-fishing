class_name Drawer
extends Node2D
## A node that draws with a callable, in world tile coordinates.
## For y-sorted things: put the Drawer inside a sort node at (0, sort_y) and pass sort_y,
## so the Drawer sits back at the origin and can draw in plain tile coordinates.

var fn: Callable
var animated := false
var sway := false          # only animated to sway in the wind
var area := Rect2()        # where it draws, in tiles; an animated Drawer only redraws while this is on screen

static var still := false   # low graphics: things that only sway (trees) stop redrawing
static var view := Rect2(-1e6, -1e6, 2e6, 2e6)   # the visible part of the world, in tiles, set by Main each frame

static func make(draw_fn: Callable, sort_y := 0.0, anim := false, bounds := Rect2()) -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(0, sort_y)
	var d := Drawer.new()
	d.fn = draw_fn
	d.animated = anim
	d.area = bounds
	d.position = Vector2(0, -sort_y)
	holder.add_child(d)
	return holder

func _draw() -> void:
	if fn.is_valid(): fn.call(self)

func _process(_dt: float) -> void:
	if not animated or (sway and still): return
	if area.has_area() and not view.intersects(area): return
	queue_redraw()
