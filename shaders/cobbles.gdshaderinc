// The village square's paving and the noise it is drawn from, shared by the
// open ground (meadow.gdshader) and the stone floors of the player's houses
// (house_flagstones.gdshader). Needs detail.gdshaderinc (band) included first.

// Hashes without sin(), which loses precision far from the origin on some
// (web) GPUs.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.7 + 1.7) * 0.15;
}

// Scattered cells (Worley noise): x = distance to the nearest point, y = to
// the second nearest, z and w two random numbers for the nearest cell.
vec4 cells(vec2 x, float jitter) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.5 + (hash22(n + g) - 0.5) * jitter - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = n + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(sqrt(d1), sqrt(d2), hash12(id), hash12(id + 17.31));
}

// Round cobbles of uneven size (`paving` is their colour) with joints of soil,
// moss and weeds. Where old is 1 (the graveyard) they are older: greyer and
// darker, sunk, with moss over many of them and some gone, grass growing in
// the gaps.
vec3 cobbles(vec2 p, float px, float old, vec3 paving, out float h) {
	vec2 q = p / 0.42;
	q += (vec2(noise(p * 1.3), noise(p * 1.3 + 9.0)) - 0.5) * 0.7;
	vec4 c = cells(q, 0.6);
	// Rounded corners: the face shrinks where three stones meet.
	float edge = (c.y - c.x) * (0.75 + 0.25 * noise(q * 3.0));
	float face = smoothstep(0.06, 0.16, edge);
	// Old paving: a stone gone here and there, and the rest worn flat.
	face *= 1.0 - step(c.z, 0.2 * old);
	float dome = sqrt(smoothstep(0.04, 0.5, edge)) * (1.0 - 0.4 * old);
	// Each stone its own shade, some warmer, some cooler, a few dark ones.
	vec3 stone = mix(paving, vec3(dot(paving, vec3(0.33))), 0.45) * (0.8 + 0.3 * c.z);
	stone *= mix(vec3(1.04, 1.0, 0.94), vec3(0.94, 0.98, 1.05), c.w);
	stone *= c.z < 0.06 ? 0.75 : 1.0;
	// Grain, pits and the polish of feet on the tops.
	float grain = noise(p * 26.0 + c.z * 10.0);
	float fine = noise(p * 80.0);
	stone *= 1.0 + (grain - 0.5) * 0.22 * band(26.0, px) + (fine - 0.5) * 0.14 * band(80.0, px);
	stone *= 0.62 + 0.42 * dome;
	// Soot and dirt in large stains across the square.
	float stain = fbm2(p * 0.4 + 70.0);
	stone *= 0.88 + 0.24 * stain;
	// Joints: dark soil with moss and a little grass growing in them.
	float moss = smoothstep(0.45 - 0.2 * old, 0.75 - 0.15 * old, fbm2(p * 1.6 + 5.0));
	stone = mix(stone, vec3(dot(stone, vec3(0.33))) * 0.86, 0.5 * old);
	vec3 joint = mix(paving * 0.4, vec3(0.17, 0.24, 0.11), max(moss, old * 0.7));
	joint *= (0.8 + 0.4 * noise(p * 45.0)) * (0.7 + 0.5 * smoothstep(0.0, 0.06, edge));
	// Moss creeps onto the edge of some stones.
	stone = mix(stone, vec3(0.2, 0.28, 0.12), moss * (1.0 - smoothstep(0.1 + 0.25 * old, 0.24 + 0.4 * old, edge)) * (0.7 + 0.2 * old));
	h = 0.025 * dome * face + 0.0015 * grain * band(26.0, px) + 0.0008 * fine * band(80.0, px);
	return mix(joint, stone, face);
}
