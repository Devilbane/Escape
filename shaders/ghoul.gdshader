shader_type spatial;
render_mode cull_disabled;
// A ghoul's body (see Enemy "ghoul_skin"): the model's light and dark kept,
// its colours washed out to dead, grey skin, with patches of rotten flesh
// (wet, dark reddish brown) and, inside the worst of them, bare bone:
// ivory with dark grooves between ribs. The patches are noise on the rest
// position of each vertex, so they stay put on the body while it moves.

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 skin : source_color = vec3(0.74, 0.75, 0.68);
uniform vec3 rot : source_color = vec3(0.42, 0.24, 0.16);
uniform vec3 bone : source_color = vec3(0.86, 0.82, 0.68);
// Moves the patches around, so not every ghoul rots in the same places.
uniform vec3 seed = vec3(0.0);
// How much of the body has rotted (0..1).
uniform float decay = 0.5;

varying vec3 rest;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.15;
}

void vertex() {
	rest = VERTEX;
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float light = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 base = skin * (0.75 + light * 0.4);
	// Blotchy, bruised skin first.
	float blotch = fbm(rest * 3.0 + seed);
	base *= 0.85 + 0.3 * blotch;
	base = mix(base, base * vec3(0.8, 0.75, 0.9), smoothstep(0.55, 0.8, blotch));
	// Rotten flesh where the rot noise is high, bone where it is highest.
	float n = fbm(rest * 2.3 + seed + vec3(7.0));
	float edge = 0.62 - decay * 0.2;
	float rotten = smoothstep(edge, edge + 0.05, n);
	float bared = smoothstep(edge + 0.1, edge + 0.13, n);
	vec3 flesh = rot * (0.7 + 0.6 * vnoise(rest * 14.0 + seed));
	// Ribs: grooves across the bone, a dark rim where the flesh tore.
	float ribs = 0.65 + 0.35 * smoothstep(0.0, 0.5, abs(sin(rest.y * 22.0)));
	vec3 bones = bone * ribs * (0.9 + 0.1 * vnoise(rest * 30.0));
	float rim = rotten * (1.0 - smoothstep(edge + 0.05, edge + 0.1, n));
	vec3 col = mix(base, flesh, rotten);
	col = mix(col, flesh * 0.5 + vec3(0.05, 0.06, 0.0), rim * 0.5);
	col = mix(col, bones, bared);
	ALBEDO = col;
	// The rot is wet and glistens; bone and skin are dry.
	ROUGHNESS = mix(0.85, 0.3, rotten * (1.0 - bared));
	SPECULAR = mix(0.3, 0.6, rotten * (1.0 - bared));
}
