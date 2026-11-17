shader_type canvas_item;
// Towers: when you walk behind one, a soft window opens in it around you so you can see yourself.
uniform vec2 hole = vec2(-100.0, -100.0);   // in tiles
uniform float hole_r = 2.6;
uniform float strength = 0.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 d = (local - hole) / vec2(1.0, 1.25);
	float k = 1.0 - smoothstep(hole_r * 0.55, hole_r, length(d));
	COLOR.a *= 1.0 - strength * k;
}
