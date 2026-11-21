// The ponds' shore (see Outdoor._build_shore), shared by the ground (meadow.gdshader) and the snow
// on it (snow_cover.gdshader), so the snow stops exactly where the ice begins.
//
// shore_mask holds how far each spot lies from the nearest bank: 0.5 on the bank, up to 1 out
// over the water `shore_reach` metres from it, down to 0 on land (black, the default, is dry land
// everywhere). It is laid over the map like the ground mask: uv = (xz / tile + 0.5) / grid_size.

uniform sampler2D shore_mask : filter_linear, repeat_disable, hint_default_black;
uniform float shore_reach = 8.0;
uniform bool shore_on = false;

float shore_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float shore_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(shore_hash(i), shore_hash(i + vec2(1.0, 0.0)), u.x),
			mix(shore_hash(i + vec2(0.0, 1.0)), shore_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Metres from the nearest bank at xz (plus over the water, minus on land), meandering a little
// about the edge of the pond tiles so the shore never runs straight, but never so far that what
// looks like water could be walked on or the other way round.
float shore_at(vec2 uv, vec2 xz) {
	if (!shore_on) {
		return -shore_reach;
	}
	float d = (texture(shore_mask, uv).r - 0.5) * 2.0 * shore_reach;
	float wander = shore_noise(xz * 0.35 + 70.0) * 0.6 + shore_noise(xz * 0.9 + 13.0) * 0.3 + shore_noise(xz * 2.4 + 3.0) * 0.1;
	return d + (wander - 0.5) * 1.1;
}
