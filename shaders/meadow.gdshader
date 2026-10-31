shader_type spatial;
// The open ground outside the dungeon in one piece: grass with patches of
// lighter and darker green, dirt paths, dark forest floor and still water.
// A small mask texture (one pixel per tile) says what lies where; noise
// frays the edges so nothing looks cut along the tile grid.

uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(16.0, 16.0);
uniform float tile = 4.0;
uniform vec3 grass_a : source_color = vec3(0.22, 0.33, 0.14);
uniform vec3 grass_b : source_color = vec3(0.31, 0.40, 0.17);
uniform vec3 forest : source_color = vec3(0.11, 0.17, 0.08);
uniform vec3 dirt : source_color = vec3(0.40, 0.31, 0.22);
uniform vec3 grave_soil : source_color = vec3(0.20, 0.23, 0.14);
uniform vec3 water : source_color = vec3(0.16, 0.30, 0.38);
uniform vec3 paving : source_color = vec3(0.50, 0.47, 0.43);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.7 + 1.7) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = (p / tile + 0.5) / grid_size;
	vec4 m = texture(ground_mask, uv);
	float n = fbm(p * 0.18);
	float fine = noise(p * 1.7);
	vec3 col = mix(grass_a, grass_b, smoothstep(0.35, 0.75, n));
	col *= 0.92 + fine * 0.16;
	// Forest floor where the mask is dark (alpha), soil on the graveyard.
	col = mix(col, forest * (0.9 + fine * 0.2), smoothstep(0.45, 0.75, 1.0 - m.a + (n - 0.5) * 0.4));
	float square = smoothstep(0.55, 0.75, min(m.r, m.g) + (n - 0.5) * 0.15);
	col = mix(col, grave_soil * (0.9 + fine * 0.2), smoothstep(0.4, 0.7, m.g + (n - 0.5) * 0.3) * (1.0 - square));
	float path = smoothstep(0.42, 0.62, m.r + (n - 0.5) * 0.35);
	vec3 earth = dirt * (0.85 + fbm(p * 0.9) * 0.3);
	col = mix(col, earth, path * (1.0 - square));
	// Paving stones in rows, each a little different, with dark joints.
	vec2 sp = p / vec2(1.1, 0.75);
	sp.x += step(1.0, mod(floor(sp.y), 2.0)) * 0.5;
	vec2 stone_id = floor(sp);
	vec2 inner = fract(sp);
	float joint = smoothstep(0.0, 0.08, inner.x) * smoothstep(1.0, 0.92, inner.x)
			* smoothstep(0.0, 0.1, inner.y) * smoothstep(1.0, 0.9, inner.y);
	vec3 stone = paving * (0.8 + hash(stone_id) * 0.35) * (0.9 + fine * 0.15);
	col = mix(col, mix(paving * 0.45, stone, joint), square);
	float wet = smoothstep(0.5, 0.62, m.b + (n - 0.5) * 0.15);
	vec3 pond = water * (0.85 + 0.15 * sin(TIME * 0.8 + p.x * 0.7 + p.y * 0.4));
	col = mix(col, pond, wet);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.15, wet);
	SPECULAR = mix(0.2, 0.6, wet);
}
