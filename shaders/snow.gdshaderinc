// What every snow shader shares (snow_cover, snow_cutout, snow_caps): how much snow lies, where
// fires keep it off, and how it looks. Not pure white: a cold off-white with a blue-grey shade in
// its hollows, soft drifts and a fine grain, and a gently bumpy surface that catches the light.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.78, 0.81, 0.86);
// The colour of the snow in its hollows and on its steeper flanks.
uniform vec3 hollow_color : source_color = vec3(0.56, 0.63, 0.74);
// How much of the light of the hour is on the snow (0 night to 1 day): the
// night's snow glows a little blue, so it is not as black as the ground was.
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// Where something burns (xyz) and how far round it no snow settles (w), see SnowCover.set_warm.
uniform vec4 warm[32];
uniform int warm_count = 0;

float snow_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise on a lattice turned off the axes and bent a little, so that no straight rows or
// columns of cells show (they made the snow look like woven white cloth).
float snow_noise(vec2 p) {
	p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	p += 0.45 * vec2(sin(p.y * 0.83 + 1.3), sin(p.x * 0.71 + 4.1));
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(snow_hash(i), snow_hash(i + vec2(1, 0)), f.x),
			mix(snow_hash(i + vec2(0, 1)), snow_hash(i + vec2(1, 1)), f.x), f.y);
}

// Drifts: a few octaves of noise, 0 to 1.
float snow_drift(vec2 p) {
	return snow_noise(p) * 0.5 + snow_noise(mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * p * 2.03 + 3.1) * 0.3 + snow_noise(mat2(vec2(0.28, 0.96), vec2(-0.96, 0.28)) * p * 4.1 + 7.7) * 0.2;
}

// Whether a fire keeps the snow off this spot: a column of heat from a little below each warm
// spot to well above it (a chimney's cap, the branches over a campfire), with a ragged edge (n).
bool snow_melted(vec3 p, float n) {
	for (int i = 0; i < warm_count; i++) {
		vec3 d = p - warm[i].xyz;
		float r = warm[i].w * (0.8 + 0.4 * n);
		if (length(d.xz) < r && d.y > -r && d.y < warm[i].w * 2.5) {
			return true;
		}
	}
	return false;
}

// The look of the snow at world spot `p` with world normal `wn`: its colour (albedo), its bumped
// normal in view space (normal) and small glints of ice by day (emission).
void snow_look(vec3 p, vec3 wn, mat4 view, float time, out vec3 albedo, out vec3 normal, out vec3 emission) {
	vec2 xz = p.xz;
	float drift = snow_drift(xz * 0.8);
	float grain = snow_noise(xz * 11.0 + p.y * 3.0);
	// Soft bumps: the slope of a small drift field tilts the normal a little.
	float e = 0.06;
	float h0 = snow_drift(xz * 2.4);
	float hx = snow_drift((xz + vec2(e, 0.0)) * 2.4);
	float hz = snow_drift((xz + vec2(0.0, e)) * 2.4);
	vec3 bumped = normalize(wn + vec3(h0 - hx, 0.0, h0 - hz) / e * 0.05);
	normal = normalize((view * vec4(bumped, 0.0)).xyz);
	// Flat tops are lightest; flanks and the low spots of the drifts turn blue-grey.
	float flat_top = smoothstep(0.45, 1.0, wn.y);
	float light = clamp(0.35 + 0.4 * flat_top + 0.35 * drift, 0.0, 1.0);
	albedo = mix(hollow_color, snow_color, light) * (0.93 + 0.07 * grain);
	// Snow at night is dim blue-grey, not bright white: the moon on pale snow, and the bloom on it,
	// read as the snow glowing by itself next to the dark things round it.
	albedo *= mix(0.55, 1.0, daylight);
	vec2 cell_id = floor(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * xz * 30.0);
	float cell = snow_hash(cell_id + floor(time * 0.7 + snow_hash(cell_id) * 8.0));
	// Glints are the sun on ice: none at night, where they showed as many very white spots.
	float glint = step(0.996, cell) * smoothstep(0.6, 0.95, daylight);
	// No glow of its own at night: the snow is lit by the light of the hour and the lamps, like all else.
	emission = vec3(0.9, 0.95, 1.0) * glint * 0.12;
}
