// What drifts under the ice of a frozen pond or river: leaves and sticks carried slowly along by the
// current (the fish are animated models, see IceFish). Drawn from shapes (a pointed leaf with its midrib and
// stalk, a forked stick), so each reads for what it is. Used by the
// ground shader (see meadow.gdshader), only where the ice lies, and tinted a little by the ice over them.

float ui_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 ui_rot(vec2 q, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * q.x - s * q.y, s * q.x + c * q.y);
}

// Distance from q to the segment a-b.
float ui_seg(vec2 q, vec2 a, vec2 b) {
	vec2 pa = q - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// A leaf lying along x, `len` long and `wid` wide: pointed at both ends, curved, with a midrib and a
// short stalk. Returns the colour in rgb and how much of it covers the point in a.
vec4 ui_leaf(vec2 q, float len, float wid, vec3 tint, float seed) {
	q.y += 0.18 * q.x * q.x / len;
	float u = q.x / len + 0.5;
	float half_w = wid * pow(max(sin(3.14159 * clamp(u, 0.0, 1.0)), 0.0), 0.7);
	// Lobed edge, as on an oak or maple leaf.
	half_w *= 0.88 + 0.12 * sin(u * 31.0 + seed * 6.0);
	float edge = half_w - abs(q.y);
	float cover = smoothstep(-0.01, 0.04, edge) * step(0.0, u) * step(u, 1.0);
	// The stalk past the base.
	float stalk = 1.0 - smoothstep(0.012, 0.03, ui_seg(q, vec2(-len * 0.5, 0.0), vec2(-len * 0.5 - 0.14, 0.0)));
	vec3 col = tint * (0.82 + 0.3 * fract(seed * 7.0));
	// Midrib and side veins, lighter than the blade.
	float rib = 1.0 - smoothstep(0.008, 0.022, abs(q.y));
	float vein = (1.0 - smoothstep(0.0, 0.012, abs(fract((q.x + abs(q.y) * 0.9) * 9.0) - 0.5) - 0.4)) * step(0.02, abs(q.y));
	col = mix(col, col * 1.45 + 0.08, max(rib, vein * 0.5));
	col = mix(col, tint * 0.6, stalk * (1.0 - cover));
	return vec4(col, max(cover, stalk));
}

// A stick `len` long with a forked twig, darker at the ends.
vec4 ui_stick(vec2 q, float len, vec3 tint, float seed) {
	q.y += 0.06 * sin(q.x * 3.0 + seed * 9.0);
	float thick = 0.032 * (1.0 - 0.45 * abs(q.x) / (len * 0.5));
	float d = ui_seg(q, vec2(-len * 0.5, 0.0), vec2(len * 0.5, 0.0)) - thick;
	float fork_at = (seed - 0.5) * len * 0.5;
	vec2 base = vec2(fork_at, 0.0);
	vec2 tip = base + vec2(0.18, 0.25 + 0.15 * seed) * len * 0.5 * (seed > 0.5 ? 1.0 : -1.0);
	float d2 = ui_seg(q, base, tip) - 0.018;
	float cover = 1.0 - smoothstep(-0.005, 0.035, min(d, d2));
	// Bark: rings along the stick, and a pale cut at one end.
	float bark = 0.85 + 0.25 * step(0.5, fract(q.x * 14.0 + seed * 5.0));
	vec3 col = tint * bark;
	col = mix(col, vec3(0.72, 0.6, 0.4), (1.0 - smoothstep(0.0, 0.03, abs(q.x + len * 0.5))) * 0.8);
	return vec4(col, cover);
}

// The picture under the ice at ground position p (metres) and time t: rgb colour and cover in a.
vec4 under_ice(vec2 p, float t) {
	vec4 out_col = vec4(0.0);
	// Leaves and sticks, carried along by the slow current.
	vec2 flow = vec2(0.14, 0.03);
	vec2 d = p - flow * t;
	float cell = 3.0;
	vec2 id = floor(d / cell);
	vec2 f = fract(d / cell);
	float h = ui_hash(id);
	float k = ui_hash(id + 17.0);
	vec2 centre = vec2(0.32 + 0.36 * ui_hash(id + 3.0), 0.32 + 0.36 * ui_hash(id + 5.0));
	vec2 q = (f - centre) * cell;
	q = ui_rot(q, h * 6.2832 + 0.35 * sin(t * 0.3 + h * 20.0));
	if (h < 0.5) {
		vec3 tint = h < 0.17 ? vec3(0.66, 0.32, 0.1) : (h < 0.34 ? vec3(0.5, 0.4, 0.12) : vec3(0.74, 0.56, 0.16));
		out_col = ui_leaf(q, 0.38 + 0.17 * k, 0.1 + 0.03 * k, tint, k);
	} else if (h < 0.68) {
		out_col = ui_stick(q, 0.65 + 0.3 * k, vec3(0.34, 0.23, 0.12), k);
	}
	return out_col;
}
