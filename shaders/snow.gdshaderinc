// What every snow shader shares (snow_cover, snow_cutout, snow_caps): how much snow lies, where
// fires keep it off, and how it looks. Not pure white: a cold off-white with a blue-grey shade in
// its hollows, soft drifts and a fine grain, and a gently bumpy surface that catches the light.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color = vec3(0.70, 0.73, 0.79);
// The colour of the snow in its hollows and on its steeper flanks.
uniform vec3 hollow_color = vec3(0.52, 0.59, 0.70);
// How much of the light of the hour is on the snow (0 night to 1 day): the
// night's snow glows a little blue, so it is not as black as the ground was.
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// How bright the moon is on the snow (0 none or day to 1 full moon, see Moon.light): it makes the
// snow show evenly across the whole night, as the full moon would, and hardly at all at new moon.
uniform float moon_glow : hint_range(0.0, 1.0) = 0.0;
// Where something burns (xyz) and how far round it no snow settles (w), see SnowCover.set_warm.
uniform vec4 warm[32];
uniform int warm_count = 0;

// Inside the self-built houses no snow settles (see SnowCover.set_shelter): R of the mask is the
// height of a house's top over each 2 m cell, in eighths of SHELTER_SCALE metres, 0 where no house
// keeps the snow off. The mask starts `shelter_shift` metres before the world's origin.
uniform sampler2D shelter_mask : filter_nearest, repeat_disable, hint_default_black;
uniform bool shelter_on = false;
uniform vec2 shelter_size = vec2(1.0);
uniform float shelter_shift = 2.0;
const float SHELTER_SCALE = 16.0;

// The awnings over the town's dining tables (see SnowCover.set_awnings): the ground each one
// covers (x/z of two opposite corners) and how high it stands. Nothing under one takes snow,
// so the benches, the table and the paving under the cloth stay clear to the awning's edge.
uniform vec4 awnings[8];
uniform float awning_tops[8];
uniform int awning_count = 0;

// Whether world spot `p` lies inside a built house, under its top, or under an awning.
bool snow_sheltered(vec3 p) {
	for (int i = 0; i < awning_count; i++) {
		vec4 r = awnings[i];
		if (p.x > r.x && p.x < r.z && p.z > r.y && p.z < r.w && p.y < awning_tops[i]) {
			return true;
		}
	}
	if (!shelter_on) {
		return false;
	}
	vec2 uv = (p.xz + vec2(shelter_shift)) / shelter_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return false;
	}
	return p.y < texture(shelter_mask, uv).r * SHELTER_SCALE;
}

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
// normal in view space (normal) and the moon's soft glow at night (emission).
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
	albedo *= mix(0.85, 1.0, daylight);
	// No glints: the snow is matte, bright specks on it read as too shiny.
	// No glow of its own at night: the snow is lit by the light of the hour and the lamps, like all else.
	// The moon's light on the snow: a soft, even blue-grey, in the hollows a little darker, so the
	// snow reads as the one pale thing in the dark, strongest at full moon, a hint at new moon.
	emission = albedo * vec3(0.62, 0.74, 1.0) * moon_glow * (1.0 - daylight) * 0.10;
}
