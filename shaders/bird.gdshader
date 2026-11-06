shader_type spatial;
// The village's birds (see VillageBirds), all in one MultiMesh. The mesh is
// one bird at rest (VillageBirds.bird_mesh): a round body and head, eyes,
// a beak, a tail, legs and two wings spread out flat. COLOR.r says which
// part a vertex is (part / 6: 0 body, 1 head, 2 beak, 3 wing, 4 tail,
// 5 eye, 6 legs); COLOR.a is 0.5, or on a wing 0 (left) or 1 (right).
//
// Each bird's INSTANCE_CUSTOM holds its wing beat's phase (x), how wide the
// wings swing (y), whether it sits (z: 0 flying, 1 sitting, wings folded,
// legs down and leaning back a little) and its kind (w: (kind + 0.5) / KINDS).
// The vertex shader shapes the kind's beak and tail, beats or folds the
// wings, and the fragment shader paints the kind's plumage, its markings
// worked out from where on the bird (at rest) a pixel is. (The MultiMesh has
// instance colours, all white: without them the compatibility renderer hands
// the vertex shader a COLOR of zero.)
render_mode cull_disabled;

uniform float beats = 16.0;

const int KINDS = 7;
const vec3 HEAD = vec3(0.0, 0.092, 0.152);
// Where the beak starts, and the mesh's beak (length, depth, width) that the
// kinds' beaks are shaped from.
const vec3 BEAK_BASE = vec3(0.0, 0.086, 0.19);
const vec3 MESH_BEAK = vec3(0.044, 0.018, 0.016);
// Per kind: the beak's length, depth and width, and how its tip droops.
const vec4 BEAKS[7] = vec4[](
	vec4(0.038, 0.014, 0.014, 0.0),     // robin: thin
	vec4(0.026, 0.014, 0.014, 0.0),     // blue tit: tiny
	vec4(0.044, 0.02, 0.018, 0.0),      // goldfinch: a pointed cone
	vec4(0.095, 0.017, 0.015, -0.004),  // kingfisher: a long dagger
	vec4(0.026, 0.024, 0.024, 0.004),   // bullfinch: stubby and round
	vec4(0.05, 0.017, 0.015, 0.002),    // oriole
	vec4(0.036, 0.024, 0.022, 0.0)      // greenfinch: a thick cone
);
// Per kind: the tail's length (times the mesh's) and how deep its notch is.
const vec2 TAILS[7] = vec2[](vec2(1.0, 0.0), vec2(1.0, 0.3), vec2(0.9, 1.0), vec2(0.45, 0.0),
		vec2(1.0, 0.2), vec2(1.0, 0.0), vec2(0.9, 1.0));
const float TAIL = 0.13;
const float WING_Y = 0.055;
// Sitting, a bird leans back (radians, nose up); and the whole bird is
// raised so that its feet stand where the bird's origin says (see BEAK in
// VillageBirds, which follows both).
const float SIT_PITCH = 0.25;
const float LIFT = 0.02;

varying vec3 rest;
varying float v_part;
varying float v_kind;

// smoothstep that also runs downhill (edge0 > edge1).
float ss(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

void vertex() {
	int kind = clamp(int(INSTANCE_CUSTOM.w * float(KINDS)), 0, KINDS - 1);
	int part = clamp(int(round(COLOR.r * 6.0)), 0, 6);
	float sitting = INSTANCE_CUSTOM.z;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (part == 2) {
		// The kind's beak: longer or shorter, stouter or finer, drooping.
		vec4 beak = BEAKS[kind];
		vec3 o = p - BEAK_BASE;
		float along = clamp(o.z / MESH_BEAK.x, 0.0, 1.0);
		o.z = along * (beak.x + 0.004);
		o.y = o.y * beak.y / MESH_BEAK.y + along * (-beak.y * 0.15 + beak.w);
		o.x *= beak.z / MESH_BEAK.z;
		p = BEAK_BASE + o;
	} else if (part == 4 && p.z < -0.1) {
		// The tail's end: its length, notched in the middle.
		float len = TAIL * TAILS[kind].x;
		float notch = abs(p.x) < 0.01 ? 1.0 - 0.12 * TAILS[kind].y : 1.0;
		p.z = -0.09 - len * notch;
		p.y = 0.05 + len * 0.15;
	}
	rest = p;
	if (part == 3) {
		float side = COLOR.a > 0.5 ? 1.0 : -1.0;
		float x = abs(p.x);
		float d = x - 0.035;
		// Spread: turned up or down about the shoulder, the hand lagging further.
		float angle = sin(TIME * beats + INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y;
		angle *= 1.0 + 0.6 * ss(0.12, 0.28, x);
		float camber = 0.008 * sin(3.14159 * clamp((p.z + 0.09) / 0.165, 0.0, 1.0));
		vec3 spread = vec3(side * (0.035 + d * cos(angle)), WING_Y + d * sin(angle) + camber, p.z);
		vec3 spread_n = vec3(-side * sin(angle), cos(angle), 0.0);
		// Folded: laid along the upper flank, the shoulder at the front, the
		// primaries reaching back over the rump, the leading edge up by the back.
		float u = d / 0.28;
		float v = clamp((0.075 - p.z) / 0.17, 0.0, 1.0);
		vec3 folded = vec3(side * (0.042 + v * 0.034) * (1.0 - 0.4 * ss(0.55, 1.0, u)),
				0.074 - v * 0.07 * (1.0 - u * 0.55) - u * 0.012,
				0.075 - u * 0.235 - v * 0.02);
		p = mix(spread, folded, sitting);
		// (Folding turns the wing over: its upper side now faces the body,
		// so the normal points in, and Godot flips it for the side we see.)
		n = normalize(mix(spread_n, vec3(-side * 0.85, -0.5, -0.1), sitting));
	} else if (part == 6) {
		// Legs: drawn up into the body in flight.
		p = mix(vec3(p.x, -0.02, 0.02), p, sitting);
	}
	// Sitting, it leans back a little.
	float pitch = SIT_PITCH * sitting;
	float c = cos(pitch);
	float s = sin(pitch);
	p = vec3(p.x, p.y * c + p.z * s, p.z * c - p.y * s);
	n = vec3(n.x, n.y * c + n.z * s, n.z * c - n.y * s);
	VERTEX = p + vec3(0.0, LIFT, 0.0);
	NORMAL = n;
	v_part = float(part);
	v_kind = float(kind);
}

// The kind's colour (sRGB) of a part at a spot p on the bird at rest.
vec3 paint(int kind, int part, vec3 p) {
	if (part == 5) {
		return vec3(0.05, 0.04, 0.04);
	}
	vec3 q = p - HEAD;
	float ax = abs(p.x);
	// The body: underneath, front, rump.
	float under = ss(0.03, 0.005, p.y - (part == 1 ? 0.06 : 0.0));
	float front = ss(-0.03, 0.03, p.z);
	float rump = ss(-0.05, -0.08, p.z) * ss(0.03, 0.05, p.y);
	// The head: cap, face, cheeks, eye stripe, throat.
	float cap = ss(0.008, 0.02, q.y);
	float face = ss(0.012, 0.032, q.z);
	float cheek = ss(0.012, 0.03, abs(q.x)) * ss(0.012, -0.002, q.y);
	float stripe = ss(0.009, 0.004, abs(q.y - 0.009)) * ss(-0.03, -0.01, q.z);
	float throat = ss(-0.018, -0.032, q.y) * ss(-0.01, 0.015, q.z);
	// The wing, spread out: d out from the shoulder, the hand (primaries),
	// the trailing edge, a bar across the coverts, the feather tips.
	float d = ax - 0.035;
	float hand = ss(0.13, 0.17, d);
	float trailing = ss(-0.035, -0.06, p.z);
	float bar = ss(0.007, 0.003, abs(p.z + 0.022)) * (1.0 - hand);
	float tipped = ss(-0.07, -0.08, p.z);
	if (kind == 0) {
		// Robin: olive-brown, orange face and breast edged blue-grey, white belly.
		vec3 back = vec3(0.47, 0.4, 0.28);
		vec3 orange = vec3(0.92, 0.47, 0.2);
		vec3 grey = vec3(0.64, 0.66, 0.68);
		vec3 white = vec3(0.93, 0.9, 0.84);
		if (part == 2) return vec3(0.14, 0.12, 0.1);
		if (part == 6) return vec3(0.45, 0.35, 0.3);
		if (part == 3) return mix(vec3(0.44, 0.36, 0.25), vec3(0.33, 0.27, 0.19), max(hand, trailing));
		if (part == 4) return vec3(0.42, 0.34, 0.24);
		if (part == 1) {
			float o = clamp(max(face * ss(0.03, 0.012, q.y), throat + ss(0.0, -0.02, q.y)), 0.0, 1.0);
			float edge = ss(0.004, 0.014, q.y) * ss(0.03, 0.012, q.y) * (1.0 - face);
			return mix(mix(back, grey, edge * 0.8), orange, o);
		}
		float o = ss(0.0, 0.05, p.z) * ss(0.055, 0.035, p.y);
		float belly = under * (1.0 - o);
		float edge = ss(0.035, 0.015, p.y) * ss(0.015, 0.035, p.y) * front;
		return mix(mix(mix(back, grey, edge * 0.7), orange, o), white, belly);
	}
	if (kind == 1) {
		// Blue tit: blue cap, white cheeks, black eye stripe and bib, yellow breast.
		vec3 blue = vec3(0.24, 0.5, 0.86);
		vec3 white = vec3(0.95, 0.95, 0.93);
		vec3 black = vec3(0.1, 0.12, 0.2);
		vec3 yellow = vec3(0.97, 0.86, 0.28);
		vec3 olive = vec3(0.56, 0.63, 0.34);
		if (part == 2) return vec3(0.15, 0.15, 0.17);
		if (part == 6) return vec3(0.42, 0.48, 0.58);
		if (part == 3) return mix(mix(blue, vec3(0.2, 0.3, 0.5), hand * 0.6), white, bar);
		if (part == 4) return blue;
		if (part == 1) {
			vec3 c = mix(white, blue, cap);
			c = mix(c, black, stripe * (1.0 - cap));
			c = mix(c, black, throat);
			return mix(c, black, ss(-0.03, -0.045, q.z) * (1.0 - cap));
		}
		return mix(olive, yellow, under);
	}
	if (kind == 2) {
		// Goldfinch: red mask, black and white head, buff body, black wings with a gold band.
		vec3 red = vec3(0.84, 0.13, 0.12);
		vec3 black = vec3(0.08, 0.07, 0.07);
		vec3 white = vec3(0.95, 0.93, 0.88);
		vec3 buff = vec3(0.72, 0.57, 0.4);
		vec3 gold = vec3(0.98, 0.82, 0.12);
		if (part == 2) return vec3(0.92, 0.84, 0.74);
		if (part == 6) return vec3(0.8, 0.62, 0.58);
		if (part == 3) {
			float band = max(ss(0.02, 0.01, abs(d - 0.13)), ss(0.03, 0.015, abs(d - 0.13)) * ss(-0.08, 0.0, p.z));
			return mix(mix(black, gold, clamp(band, 0.0, 1.0)), white, tipped * hand * 0.8);
		}
		if (part == 4) return mix(black, white, ss(-0.18, -0.2, p.z) * 0.8);
		if (part == 1) {
			vec3 c = mix(white, black, max(cap * (1.0 - face * 0.8), ss(-0.015, -0.035, q.z) * ss(-0.01, 0.01, q.y)));
			return mix(c, red, face * ss(-0.03, -0.01, q.y));
		}
		return mix(buff, white, clamp(under * ss(-0.1, 0.0, p.z) * ss(0.0, -0.03, p.y) + under * 0.5, 0.0, 1.0));
	}
	if (kind == 3) {
		// Kingfisher: blue-green above with a bright back stripe, orange below, white throat.
		vec3 blue = vec3(0.1, 0.48, 0.66);
		vec3 bright = vec3(0.25, 0.85, 0.95);
		vec3 orange = vec3(0.93, 0.48, 0.16);
		vec3 white = vec3(0.96, 0.94, 0.88);
		if (part == 2) return vec3(0.1, 0.09, 0.09);
		if (part == 6) return vec3(0.9, 0.35, 0.22);
		if (part == 3) return mix(blue, vec3(0.06, 0.32, 0.48), max(hand, trailing) * 0.7);
		if (part == 4) return vec3(0.08, 0.3, 0.55);
		if (part == 1) {
			vec3 c = mix(orange, blue, cap);
			c = mix(c, white, throat);
			c = mix(c, white, ss(0.03, 0.04, abs(q.x)) * ss(0.0, -0.02, q.z) * ss(0.012, 0.0, q.y));
			return mix(c, blue, ss(-0.012, -0.004, q.y) * ss(0.012, 0.004, q.y) * ss(0.03, 0.01, q.z) * (1.0 - cap) * 0.8);
		}
		float back_stripe = ss(0.016, 0.006, ax) * ss(0.03, 0.05, p.y);
		return mix(mix(blue, bright, back_stripe), orange, under);
	}
	if (kind == 4) {
		// Bullfinch: black cap, rosy cheeks and breast, grey back, white rump.
		vec3 black = vec3(0.08, 0.08, 0.1);
		vec3 rose = vec3(0.88, 0.38, 0.36);
		vec3 grey = vec3(0.56, 0.56, 0.6);
		vec3 white = vec3(0.94, 0.94, 0.92);
		if (part == 2) return vec3(0.1, 0.1, 0.11);
		if (part == 6) return vec3(0.25, 0.22, 0.22);
		if (part == 3) return mix(black, vec3(0.82, 0.82, 0.82), bar);
		if (part == 4) return black;
		if (part == 1) {
			vec3 c = mix(rose, black, max(cap, face * ss(-0.005, 0.01, q.y)));
			return mix(c, grey, ss(-0.02, -0.04, q.z) * ss(-0.01, 0.01, q.y) * (1.0 - cap));
		}
		float belly = ss(0.0, -0.025, p.y) * ss(-0.02, -0.06, p.z);
		return mix(mix(mix(grey, rose, under), white, belly), white, rump);
	}
	if (kind == 5) {
		// Golden oriole: golden yellow, black wings with a yellow patch, black tail tipped yellow.
		vec3 yellow = vec3(0.98, 0.82, 0.12);
		vec3 black = vec3(0.08, 0.07, 0.06);
		if (part == 2) return vec3(0.78, 0.36, 0.36);
		if (part == 6) return vec3(0.4, 0.4, 0.42);
		if (part == 3) return mix(black, yellow, ss(0.014, 0.006, length(vec2(d - 0.1, p.z - 0.05))));
		if (part == 4) return mix(black, yellow, ss(-0.19, -0.205, p.z));
		if (part == 1) return mix(yellow, black, ss(0.008, 0.002, abs(q.y - 0.006)) * ss(0.02, 0.035, q.z));
		return yellow;
	}
	// Greenfinch: olive green, yellow flashes on wing and tail, a pale stout beak.
	vec3 green = vec3(0.47, 0.57, 0.25);
	vec3 pale = vec3(0.66, 0.74, 0.32);
	vec3 grey = vec3(0.45, 0.5, 0.42);
	vec3 yellow = vec3(0.96, 0.86, 0.2);
	if (part == 2) return vec3(0.9, 0.76, 0.7);
	if (part == 6) return vec3(0.82, 0.66, 0.6);
	if (part == 3) return mix(mix(grey, vec3(0.2, 0.22, 0.2), hand * 0.7), yellow, hand * ss(0.0, 0.02, p.z) * 0.9);
	if (part == 4) return mix(vec3(0.22, 0.24, 0.2), yellow, ss(0.02, 0.035, ax) * ss(-0.16, -0.12, p.z));
	if (part == 1) return mix(mix(green, grey, cheek * 0.3), pale, throat);
	return mix(green, pale, under);
}

void fragment() {
	int part = int(v_part + 0.5);
	vec3 c = paint(int(v_kind + 0.5), part, rest);
	if (part == 3) {
		// Wings a shade darker than the body, their trailing edge more so.
		c *= 0.82 - 0.12 * ss(-0.035, -0.06, rest.z);
	}
	// The colours are picked in sRGB; light works in linear.
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.85;
}
