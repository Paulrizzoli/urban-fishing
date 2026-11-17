shader_type canvas_item;
// The ground of Port Mullet: surface texture for lawns, asphalt, concrete and sand,
// and the water: rippling light, caustics on the shallows, swells on deep water,
// foam lapping at the shore and sun glints. All of it is procedural, so it's original to the game.

uniform sampler2D water_mask : filter_linear;   // r water, g depth (0 shallow, 1 deep), b murky drain water
uniform sampler2D materials : filter_nearest;   // what the ground is made of, see Ground.make_material_tex()
uniform vec2 map_size = vec2(112.0, 184.0);
uniform float sun = 1.0;                        // 1 at noon on a clear day, 0 at night
uniform float rain = 0.0;
uniform vec3 sky_col = vec3(0.55, 0.75, 0.92);  // the sky the water reflects, from Main.sky_tint()

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * map_size;           // in tiles
	vec4 wm = texture(water_mask, UV);
	float mat = floor(texture(materials, UV).r * 255.0 + 0.5);
	float t = TIME;
	if (mat > 4.5 && mat < 5.5) {
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
	} else if (mat > 0.5) {
		float big = fbm(p * 0.35);
		float mid = noise(p * 2.2);
		float fine = hash(floor(p * 32.0));
		float wet = smoothstep(0.08, 0.5, wm.r);   // land right next to the water
		if (mat < 1.5) {          // lawn: clumps, mottled color, damp near the water
			float clump = fbm(p * 1.3 + 4.0);
			c.rgb *= 1.0 + (big - 0.5) * 0.1 + (fine - 0.5) * 0.04;
			c.rgb = mix(c.rgb, c.rgb * vec3(1.08, 1.05, 0.82), smoothstep(0.45, 0.75, clump) * 0.5);
			c.rgb = mix(c.rgb, c.rgb * vec3(0.86, 0.95, 0.88), smoothstep(0.5, 0.2, clump) * 0.5);
			c.rgb *= 1.0 - wet * 0.1;
		} else if (mat < 2.5) {   // asphalt: grain, patched and worn areas
			c.rgb *= 0.94 + big * 0.1 + (fine - 0.5) * 0.08;
			float patch = smoothstep(0.62, 0.66, fbm(p * 0.22 + 7.0));
			c.rgb *= 1.0 - patch * 0.07;
			c.rgb += (step(0.985, fine) * 0.08) * vec3(1.0);
		} else if (mat < 3.5) {   // concrete: speckle and weathering
			c.rgb *= 0.95 + big * 0.08 + (fine - 0.5) * 0.04;
			c.rgb *= 1.0 - smoothstep(0.6, 0.8, fbm(p * 0.8 + 2.0)) * 0.05;
		} else if (mat < 4.5) {   // sand: wind ripples, grain, darker where it's wet
			float rip = sin(p.y * 6.0 + p.x * 1.5 + big * 9.0);
			c.rgb *= 0.95 + rip * 0.025 + (fine - 0.5) * 0.06 + big * 0.06;
			c.rgb *= 1.0 - wet * 0.22;
			c.rgb = mix(c.rgb, c.rgb * vec3(0.95, 0.97, 1.0), wet);
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
		// rain darkens everything a little
		c.rgb *= 1.0 - rain * 0.12;
	}
	COLOR = c;
}
