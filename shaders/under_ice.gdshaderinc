// What drifts under the ice of a frozen pond or river: leaves and sticks carried slowly along by the
// current, and now and then a fish swimming by. Drawn from shapes (a pointed leaf with its midrib and
// stalk, a forked stick, a fish with fins, tail and eye), so each reads for what it is. Used by the
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

// A fish swimming towards +x, seen from above like the game's camera sees it: a slim body with a
// darker back, pale flanks and a few bars, two pectoral fins out to the sides, a forked tail, and the two
// eyes on top of the head. The whole body bends from side to side in a wave that runs from the head to
// the tail, so the tail beats widest.
vec4 ui_fish(vec2 q, float len, float wid, float seed, float t) {
	float u = (q.x + len * 0.5) / len;
	float bend = 0.13 * len * sin(t * 6.5 - u * 6.5 + seed * 20.0) * pow(clamp(1.0 - u, 0.0, 1.0), 1.4);
	// The head turns a little against the tail.
	bend -= 0.03 * len * sin(t * 6.5 - 6.5 + seed * 20.0) * smoothstep(0.6, 1.0, u);
	q.y -= bend;
	float uc = clamp(u, 0.0, 1.0);
	float body_w = wid * pow(max(sin(3.14159 * clamp(0.1 + uc * 0.9, 0.0, 1.0)), 0.0), 0.6);
	float body = smoothstep(0.0, 0.012, body_w - abs(q.y)) * step(0.0, u) * step(u, 1.0);
	// Tail fin: a forked fan behind the narrow base of the body.
	float tu = -u;
	float tail_w = wid * (0.45 + 3.2 * tu);
	float tail = smoothstep(0.0, 0.012, tail_w - abs(q.y)) * step(0.0, tu) * step(tu, 0.26);
	tail *= step(tu * wid * 1.7, abs(q.y) + wid * 0.22);
	// Pectoral fins: small paddles at either side behind the head, swept back.
	vec2 fp = vec2(q.x - len * 0.18, abs(q.y) - body_w * 1.05);
	fp = vec2(fp.x * 0.8 + fp.y * 0.5, fp.y * 1.0 - fp.x * 0.5);
	float pect = (1.0 - smoothstep(0.0, 1.0, length(fp / vec2(len * 0.1, wid * 0.55)))) * step(body_w * 0.7, abs(q.y));
	// Colour: dark olive back, scale dots, bars across the back, pale towards the flanks.
	float across = abs(q.y) / max(body_w, 0.001);
	vec3 back = vec3(0.2, 0.27, 0.18);
	vec3 flank = vec3(0.55, 0.52, 0.34);
	vec3 col = mix(back, flank, smoothstep(0.35, 1.0, across));
	col *= 0.82 + 0.26 * step(0.55, fract(u * 6.0 + 0.2));
	vec2 sc = vec2(q.x * 38.0, q.y * 38.0 + 0.5 * floor(q.x * 38.0));
	col *= 0.9 + 0.14 * smoothstep(0.1, 0.5, length(fract(sc) - 0.5));
	vec3 fin = vec3(0.74, 0.36, 0.14);
	col = mix(col, fin * (0.8 + 0.3 * fract(u * 19.0)), max(tail, pect * 0.9));
	// Eyes: two dark dots on the sides of the head.
	float eye = 1.0 - smoothstep(0.006, 0.016, length(vec2(q.x - len * 0.38, abs(q.y) - wid * 0.5)));
	col = mix(col, vec3(0.03), eye * body);
	return vec4(col, max(body, max(tail, pect * 0.9)));
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
	// A fish now and then, swimming its own way across a wide cell and fading in and out.
	float fcell = 11.0;
	vec2 fid = floor(p / fcell);
	float fh = ui_hash(fid + 41.0);
	if (fh < 0.55) {
		float speed = 0.5 + 0.4 * ui_hash(fid + 7.0);
		float dir = ui_hash(fid + 9.0) < 0.5 ? 1.0 : -1.0;
		float phase = fract(t * speed / (fcell * 0.8) + fh * 3.0);
		float x = (phase - 0.5) * fcell * 0.9 * dir;
		float y = (ui_hash(fid + 13.0) - 0.5) * fcell * 0.5 + 0.5 * sin(phase * 9.0 + fh * 30.0);
		vec2 centre_f = (fid + 0.5) * fcell + vec2(x, y);
		vec2 fq = p - centre_f;
		fq.x *= dir;
		float fade = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.88, 1.0, phase));
		vec4 fish = ui_fish(fq, 0.42, 0.07, fh, t);
		fish.a *= fade * 0.7;
		out_col = mix(out_col, vec4(fish.rgb, 1.0), fish.a);
		out_col.a = max(out_col.a, fish.a);
	}
	return out_col;
}
