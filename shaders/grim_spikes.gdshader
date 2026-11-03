shader_type spatial;
// Old trap spikes: iron gone to rust, caked with dirt at the foot and dark,
// dried blood running down from the tips. base_y and tip_y are the spikes'
// lowest and highest points in the mesh's own space; the grain comes from
// the world position, so spikes side by side never look alike.

uniform float base_y = -0.5;
uniform float tip_y = 0.5;

varying vec3 local_pos;
varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 0 at the foot of a spike, 1 at its tip.
	float h = clamp((local_pos.y - base_y) / max(tip_y - base_y, 0.001), 0.0, 1.0);
	// The grain rides on the spike (local) but differs from spike to spike (world).
	vec3 p = local_pos * 6.0 + floor(world_pos * 1.3) * 7.1;
	float coarse = noise(p);
	float fine = noise(p * 4.3);
	// Rust in patches over dull iron.
	vec3 iron = vec3(0.42, 0.41, 0.4);
	vec3 rust = mix(vec3(0.44, 0.25, 0.11), vec3(0.62, 0.36, 0.15), fine);
	float rusty = smoothstep(0.3, 0.7, coarse * 0.7 + fine * 0.3);
	vec3 col = mix(iron, rust, rusty);
	// Dirt caked on the lower part, with a ragged edge.
	float dirt = 1.0 - smoothstep(0.18, 0.4, h + (fine - 0.5) * 0.25);
	col = mix(col, vec3(0.24, 0.18, 0.12), dirt * 0.9);
	// Dried blood from the tips, running down in streaks.
	float streak = noise(vec3(local_pos.x * 18.0, local_pos.y * 1.5, local_pos.z * 18.0) + floor(world_pos * 1.3) * 3.7);
	float blood = smoothstep(0.72, 0.9, h + (streak - 0.5) * 0.5);
	col = mix(col, mix(vec3(0.3, 0.02, 0.02), vec3(0.48, 0.05, 0.03), fine), blood * 0.95);
	ALBEDO = col;
	METALLIC = 0.35 * (1.0 - rusty) * (1.0 - dirt) * (1.0 - blood);
	ROUGHNESS = mix(0.85, 0.45, blood);
}
