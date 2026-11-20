// Natural stonework, shared by the village stone (aged_stone.gdshader), the hero's
// houses (house_stone.gdshader) and the dungeon walls (stone.gdshader); see StoneLook.
//
// - lay_stones(): stones of differing size laid in courses. Each band of two
//   courses is either one tall course or split at a random height, and each
//   course is cut into stones of one, two or three lengths, so no two rows
//   repeat. The stones' corners are rounded, and with `irregular` the joints
//   wobble like those of rough field stone.
// - edge_bevel(): rounds off the hard edges of a building. StoneLook.edge_data
//   writes into CUSTOM0 how far each corner of a triangle lies from up to four
//   outer edges nearby; the distances run on across the triangle exactly, so the
//   normal can be bent towards each edge as it nears, as if the edge were round.
//
// Needs detail.gdshaderinc (hash3, vnoise, fbm, band) included first.

// One spot of the wall, `m` metres along and up it. `course`: how high (metres)
// a course of stones stands on average; `irregular`: 0 tidy cut stone, 1 rough
// field stone. Returns (distance into the stone in metres, negative in a joint;
// the stone's own random number; how far across its face (0 at its rim, 1 in its
// middle); the stone's height from the course's foot).
vec4 lay_stones(vec2 m, float course, float irregular) {
	// Rough stone: the joints wander a little.
	vec2 wob = vec2(vnoise(vec3(m * 1.9 / course * 0.35, 2.0)), vnoise(vec3(m * 1.9 / course * 0.35, 9.0))) - 0.5;
	m += wob * course * 0.5 * irregular;
	// A band of two courses: one tall course, or two of differing height.
	float band_h = course * 2.0;
	float b = floor(m.y / band_h);
	float y_in = m.y - b * band_h;
	float y0 = 0.0;
	float y1 = band_h;
	float row = b * 3.0;
	if (hash3(vec3(b, 1.0, 7.0)) > mix(0.12, 0.25, irregular)) {
		float split = mix(0.36, 0.64, hash3(vec3(b, 4.0, 2.0))) * band_h;
		if (y_in < split) {
			y1 = split;
			row += 1.0;
		} else {
			y0 = split;
			row += 2.0;
		}
	}
	// Along the course: cells of one, two or three stones, shifted per course.
	float cell_w = course * mix(3.2, 2.6, irregular);
	float x = m.x + hash3(vec3(row, 3.0, 5.0)) * cell_w;
	float c = floor(x / cell_w);
	float x_in = x - c * cell_w;
	float hc = hash3(vec3(c, row, 11.0));
	float x0 = 0.0;
	float x1 = cell_w;
	float piece = 0.0;
	if (hc > 0.72) {
		float s1 = mix(0.2, 0.4, hash3(vec3(c, row, 13.0))) * cell_w;
		float s2 = mix(0.6, 0.8, hash3(vec3(c, row, 19.0))) * cell_w;
		if (x_in < s1) {
			x1 = s1;
		} else if (x_in < s2) {
			x0 = s1;
			x1 = s2;
			piece = 1.0;
		} else {
			x0 = s2;
			piece = 2.0;
		}
	} else if (hc > 0.28) {
		float s = mix(0.3, 0.7, hash3(vec3(c, row, 23.0))) * cell_w;
		if (x_in < s) {
			x1 = s;
		} else {
			x0 = s;
			piece = 1.0;
		}
	}
	// The stone as a rectangle with rounded corners, inside its joints.
	float joint = course * mix(0.07, 0.11, irregular);
	vec2 half_size = vec2(x1 - x0, y1 - y0) * 0.5 - joint * 0.5;
	vec2 p = vec2(x_in - (x0 + x1) * 0.5, y_in - (y0 + y1) * 0.5);
	float rr = min(half_size.x, half_size.y) * mix(0.3, 0.75, irregular);
	vec2 q = abs(p) - half_size + rr;
	float sdf = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
	float id = hash3(vec3(c * 3.0 + piece, row, 17.0));
	float across = clamp(-sdf / max(min(half_size.x, half_size.y), 0.01), 0.0, 1.0);
	return vec4(-sdf, id, across, y_in - y0);
}

// The colour (rgb) and relief (a, 0 in a joint to about 1 on a stone's face) of
// natural stone at `m` metres on a wall. `tint`: the stone's colour; `px`: metres
// per pixel there (for fading out what is too small to see).
vec4 natural_stone(vec2 m, vec3 tint, float course, float irregular, float px) {
	vec4 s = lay_stones(m, course, irregular);
	float edge = s.x;
	float id = s.y;
	// Each stone its own shade and a slightly warmer or cooler hue.
	float hue = hash3(vec3(id * 31.0, 2.0, 5.0));
	vec3 col = tint * (0.82 + 0.26 * id) * mix(vec3(0.96, 0.98, 1.04), vec3(1.05, 1.0, 0.92), hue);
	// The grain of the stone, and small pits.
	vec3 g = vec3(m * 3.0, id * 13.0);
	float grain = fbm(g);
	float pits = smoothstep(0.66, 0.85, vnoise(vec3(m * 22.0, id * 7.0))) * band(22.0, px);
	col *= (0.86 + 0.28 * grain) * (1.0 - 0.14 * pits);
	// Worn, slightly darker rims round each stone.
	float aa = max(px * 1.5, 0.004);
	col *= mix(0.8, 1.0, smoothstep(0.0, course * 0.12, edge));
	// The mortar between the stones: grey, a little sandy.
	float mortar = 1.0 - smoothstep(-aa, aa, edge);
	vec3 mortar_col = vec3(dot(tint, vec3(0.33))) * vec3(0.62, 0.6, 0.56) * (0.9 + 0.2 * vnoise(vec3(m * 30.0, 1.0)));
	col = mix(col, mortar_col, mortar * band(1.0 / course, px));
	// Relief: each stone bulges like a pillow, a little higher in its middle.
	float height = mix(smoothstep(-aa, course * 0.18, edge) * (0.7 + 0.3 * sqrt(s.z)), 0.5, 1.0 - band(1.0 / course, px));
	height += (grain - 0.5) * 0.15 - pits * 0.05;
	return vec4(col, height);
}

// How far the normal is bent towards the rounded edges near this spot: the
// change of the bevel's height from one pixel to the next (x and y), for
// bumped(). `dist`: CUSTOM0, the distances (metres) to up to four outer edges;
// `radius`: how round the edges are (metres).
vec2 edge_bevel(vec4 dist, float radius) {
	if (radius <= 0.0) {
		return vec2(0.0);
	}
	vec4 dx = dFdx(dist);
	vec4 dy = dFdy(dist);
	// The bevel's height falls off as (radius - d)^2 / 2 radius towards an edge:
	// its slope reaches 45 degrees at the edge, where it meets the bevel of the
	// face round the corner.
	vec4 slope = clamp((radius - max(dist, vec4(0.0))) / radius, 0.0, 1.0);
	// Far edges (unused slots carry 1000) never bend, nor does a spot behind an
	// edge's line (where a face turns a corner inwards, the line runs on across it).
	slope *= step(dist, vec4(radius)) * step(vec4(-0.01), dist);
	return vec2(dot(slope, dx), dot(slope, dy)) * 0.95;
}
