shader_type canvas_item;
// The ground of Port Mullet: surface texture for lawns, asphalt, concrete and sand,
// and the water: rippling light, caustics on the shallows, swells on deep water,
// foam lapping at the shore and sun glints. All of it is procedural, so it's original to the game.

uniform sampler2D water_mask : filter_linear;   // r water, g depth (0 shallow, 1 deep), b murky drain water
uniform sampler2D materials : filter_nearest;   // what the ground is made of, see Ground.make_material_tex()
uniform sampler2D coast : filter_linear;        // how much each spot is land; the curved shoreline is where it crosses 0.5
uniform sampler2D water_col : filter_linear;    // water color per tile, with a one-tile border
uniform vec2 map_size = vec2(112.0, 184.0);
uniform float sun = 1.0;                        // 1 at noon on a clear day, 0 at night
uniform float rain = 0.0;
uniform vec3 sky_col = vec3(0.55, 0.75, 0.92);  // the sky the water reflects, from Main.sky_tint()
uniform float wetness = 0.0;                        // how wet the ground still is: rises in rain, dries over a few hours
uniform float mist = 0.0;                       // morning mist lying over the water

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// distance between the nearest and second-nearest moving cell points: thin bright lines where cells meet
float cell_edge(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g);
			o = 0.5 + 0.42 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

float waves(vec2 p, float t) {
	return fbm(p * 0.55 + vec2(t * 0.16, t * 0.11)) + 0.35 * fbm(p * 1.4 - vec2(t * 0.24, -t * 0.15));
}

vec3 shade_water(vec3 col, vec2 p, vec4 wm, float t) {
	vec4 c = vec4(col, 1.0);
	float depth = wm.g;
	float murky = wm.b;
	float shallow = 1.0 - depth;
	// surface height and its slope, for light on the ripples
	float e = 0.08;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hy = waves(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h - hx) * 2.2, (h - hy) * 2.2, 1.0));
	vec3 L = normalize(vec3(-0.45, -0.65, 0.62));
	float diff = dot(n, L) - L.z;
	c.rgb *= 1.04 + diff * 0.35;
	// caustics: a net of light on the bottom of the shallows, bent by the surface
	vec2 q = p * 1.25 + n.xy * 1.4;
	float c1 = 1.0 - smoothstep(0.0, 0.16, cell_edge(q, t * 0.8));
	float c2 = 1.0 - smoothstep(0.0, 0.12, cell_edge(q * 1.7 + vec2(3.1, 1.7), -t * 1.05));
	float caus = c1 * c1 * 0.65 + c2 * c2 * 0.35;
	c.rgb += vec3(0.85, 1.0, 0.95) * caus * (0.04 + 0.13 * shallow) * (1.0 - murky * 0.85) * (0.35 + 0.65 * sun);
	// long swells rolling across deep water
	float sw = sin(dot(p, vec2(0.28, 0.96)) * 1.3 - t * 1.1 + fbm(p * 0.25 + t * 0.05) * 5.0);
	c.rgb += vec3(0.8, 0.95, 1.0) * smoothstep(0.82, 1.0, sw) * 0.07 * depth;
	c.rgb -= smoothstep(0.82, 1.0, -sw) * 0.04 * depth;
	// sun glints on the ripple tops
	vec3 r = reflect(-L, n);
	float spec = pow(max(r.z, 0.0), 60.0);
	float tw = step(0.9, hash(floor(p * 9.0) + floor(t * 3.0)));
	c.rgb += mix(vec3(1.0, 0.98, 0.9), sky_col * 1.3, 0.35) * (spec * 0.55 + spec * tw * 0.9) * sun * (1.0 - murky) * (1.0 - rain * 0.7);
	// foam lapping at the shore
	float edge = 1.0 - smoothstep(0.55, 0.97, wm.r);
	float fn = fbm(p * 3.2 + vec2(t * 0.35, -t * 0.25));
	float lap = 0.5 + 0.5 * sin(wm.r * 22.0 - t * 1.8 + fn * 4.0);
	float foam = edge * smoothstep(0.62, 0.95, lap * 0.55 + fn * 0.7) + edge * edge * 0.25;
	c.rgb = mix(c.rgb, vec3(0.94, 0.98, 1.0), clamp(foam, 0.0, 1.0) * 0.6 * (1.0 - murky * 0.8));
	// a hint of sky reflected on the deep water
	c.rgb = mix(c.rgb, sky_col, (0.06 + 0.1 * depth) * (0.4 + 0.6 * sun));
	return c.rgb;
}

// lawn: clumps, mottled color, damp near the water
vec3 shade_lawn(vec3 col, vec2 p, vec4 wm) {
	vec3 c = col;
	float big = fbm(p * 0.35);
	float fine = hash(floor(p * 32.0));
	float wet = smoothstep(0.08, 0.5, wm.r);
	float clump = fbm(p * 1.3 + 4.0);
	c *= 1.0 + (big - 0.5) * 0.1 + (fine - 0.5) * 0.04;
	c = mix(c, c * vec3(1.08, 1.05, 0.82), smoothstep(0.45, 0.75, clump) * 0.5);
	c = mix(c, c * vec3(0.86, 0.95, 0.88), smoothstep(0.5, 0.2, clump) * 0.5);
	c *= 1.0 - wet * 0.1;
	return c;
}

// sand: wind ripples, grain, darker where it's wet
vec3 shade_sand(vec3 col, vec2 p, vec4 wm) {
	vec4 c = vec4(col, 1.0);
	float big = fbm(p * 0.35);
	float fine = hash(floor(p * 32.0));
	float wet = smoothstep(0.08, 0.5, wm.r);
	float rip = sin(p.y * 6.0 + p.x * 1.5 + big * 9.0);
	c.rgb *= 0.95 + rip * 0.025 + (fine - 0.5) * 0.06 + big * 0.06;
	c.rgb *= 1.0 - wet * 0.22;
	c.rgb = mix(c.rgb, c.rgb * vec3(0.95, 0.97, 1.0), wet);
	return c.rgb;
}

// wet pavement: darker, with puddles that hold the sky and ring with raindrops
vec3 wet_ground(vec3 c, vec2 p, float amount, float t, float hold) {
	if (amount < 0.01) return c;
	c *= 1.0 - amount * 0.2;
	c += sky_col * 0.05 * amount;
	float pm = fbm(p * 0.42 + vec2(13.1, 7.7)) + noise(p * 2.1) * 0.08;
	float lvl = 0.7 - amount * 0.06 * hold;
	float puddle = smoothstep(lvl, lvl + 0.025, pm) * hold;
	if (puddle > 0.001) {
		vec3 sky = mix(sky_col, vec3(0.52, 0.62, 0.72), 0.55);
		vec3 pc = mix(c * 0.55, sky * 0.8, 0.38);
		// raindrop rings in the puddle
		vec2 g = floor(p * 2.5);
		vec2 f = fract(p * 2.5) - 0.5;
		float ph = fract(t * 1.3 + hash(g) * 7.0);
		vec2 o = (hash22(g + floor(t * 1.3 + hash(g) * 7.0)) - 0.5) * 0.5;
		float d = length(f - o);
		float ring = (1.0 - smoothstep(0.0, 0.05, abs(d - ph * 0.45))) * (1.0 - ph) * rain;
		pc += vec3(0.8, 0.9, 1.0) * ring * 0.35;
		// a soft highlight along the puddle edge
		float edge = smoothstep(lvl, lvl + 0.01, pm) - smoothstep(lvl + 0.01, lvl + 0.04, pm);
		pc += vec3(1.0) * edge * 0.08;
		c = mix(c, pc, puddle);
	}
	return c;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * map_size;           // in tiles
	vec4 wm = texture(water_mask, UV);
	float mat = floor(texture(materials, UV).r * 255.0 + 0.5);
	float t = TIME;
	if (mat > 11.5) {
		// a natural pond: the grass runs down to a muddy bank along a smooth curve
		float land = texture(coast, UV).r;
		float fw = max(fwidth(land) * 0.7, 0.004);
		float k = smoothstep(0.5 - fw, 0.5 + fw, land);
		vec3 wcol = texture(water_col, (p + 1.0) / (map_size + 2.0)).rgb;
		// the ground texture holds the grass on the land side; right at the edge use a typical lawn green
		vec3 gcol = land >= 0.5 ? c.rgb : vec3(0.47, 0.69, 0.36);
		vec3 sea = k < 0.999 ? shade_water(wcol, p, wm, t) : vec3(0.0);
		sea *= 1.0 - smoothstep(0.3, 0.5, land) * 0.12;   // shade under the bank
		vec3 bank = k > 0.001 ? shade_lawn(gcol, p, wm) * (1.0 - rain * 0.12) : vec3(0.0);
		c.rgb = mix(sea, bank, k);
	} else if (mat > 9.5) {
		// a curved coast: sand and water meet along a smooth line that ignores the tile grid
		float land = texture(coast, UV).r;
		float fw = max(fwidth(land) * 0.7, 0.004);
		float k = smoothstep(0.5 - fw, 0.5 + fw, land);
		vec3 wcol = texture(water_col, (p + 1.0) / (map_size + 2.0)).rgb;
		vec3 scol = mix(vec3(0.925, 0.863, 0.671), vec3(0.84, 0.753, 0.55), clamp(1.0 - (land - 0.5) / 0.1, 0.0, 1.0) * 0.75);
		vec3 sea = k < 0.999 ? shade_water(wcol, p, wm, t) : vec3(0.0);
		// a thin line of surf washing up and back along the sand
		float surf = smoothstep(0.34, 0.495, land + 0.035 * sin(t * 1.4 + p.x * 1.9 + p.y * 1.3));
		sea = mix(sea, vec3(0.95, 0.99, 1.0), surf * 0.5 * (0.6 + 0.4 * sun));
		vec3 shore = k > 0.001 ? shade_sand(scol, p, wm) * (1.0 - rain * 0.12) : vec3(0.0);
		c.rgb = mix(sea, shore, k);
	} else if (mat > 4.5 && mat < 5.5) {
		c.rgb = shade_water(c.rgb, p, wm, t);
	} else if (mat > 0.5) {
		float big = fbm(p * 0.35);
		float mid = noise(p * 2.2);
		float fine = hash(floor(p * 32.0));
		float wet = smoothstep(0.08, 0.5, wm.r);   // land right next to the water
		if (mat < 1.5) {          // lawn
			c.rgb = shade_lawn(c.rgb, p, wm);
		} else if (mat < 2.5) {   // asphalt: grain, patched and worn areas
			c.rgb *= 0.94 + big * 0.1 + (fine - 0.5) * 0.08;
			float patch = smoothstep(0.62, 0.66, fbm(p * 0.22 + 7.0));
			c.rgb *= 1.0 - patch * 0.07;
			c.rgb += (step(0.985, fine) * 0.08) * vec3(1.0);
		} else if (mat < 3.5) {   // concrete: speckle and weathering
			c.rgb *= 0.95 + big * 0.08 + (fine - 0.5) * 0.04;
			c.rgb *= 1.0 - smoothstep(0.6, 0.8, fbm(p * 0.8 + 2.0)) * 0.05;
		} else if (mat < 4.5) {   // sand: wind ripples, grain, darker where it's wet
			c.rgb = shade_sand(c.rgb, p, wm);
		} else if (mat < 6.5) {   // fairway
			c.rgb *= 0.95 + big * 0.1 + (mid - 0.5) * 0.04;
		} else if (mat < 7.5) {   // dirt path
			c.rgb *= 0.92 + big * 0.12 + (fine - 0.5) * 0.08;
		} else if (mat < 8.5) {   // plaza
			c.rgb *= 0.96 + big * 0.06;
		} else {                  // dock planks: wood grain
			float grain = noise(vec2(p.x * 1.5, p.y * 30.0));
			c.rgb *= 0.92 + grain * 0.12 + big * 0.06;
		}
		// rain darkens everything a little, and wet pavement keeps puddles for a while after
		c.rgb *= 1.0 - rain * 0.12;
		if ((mat > 1.5 && mat < 3.5) || (mat > 7.5 && mat < 9.5)) c.rgb = wet_ground(c.rgb, p, wetness, t, mat < 2.5 ? 1.0 : mat < 3.5 ? 0.45 : 0.7);
		else if (mat < 1.5 || (mat > 5.5 && mat < 7.5)) c.rgb *= 1.0 - wetness * 0.08;
	}
	// morning mist drifting low over the water and the banks next to it
	if (mist > 0.01) {
		float near = smoothstep(0.05, 0.85, wm.r);
		float m = fbm(p * 0.22 + vec2(t * 0.05, t * 0.018)) * 0.75 + fbm(p * 0.6 - vec2(t * 0.03, 0.0)) * 0.35;
		float a = mist * near * smoothstep(0.28, 0.75, m) * 0.9;
		c.rgb = mix(c.rgb, vec3(0.92, 0.94, 0.96) * (0.75 + 0.25 * sun), a);
	}
	COLOR = c;
}
