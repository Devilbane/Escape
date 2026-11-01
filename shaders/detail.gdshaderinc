// Noise and bump helpers shared by the gear and stone shaders.

float hash3(vec3 p) {
	vec3 q = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)) * 17.0;
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

// Soft, cloudy variation between 0 and 1.
float fbm(vec3 p) {
	return 0.5 * vnoise(p) + 0.3 * vnoise(p * 2.03 + 3.1) + 0.2 * vnoise(p * 4.01 + 7.7);
}

// 1 while a pattern with this many repeats per unit is large enough on screen
// (px = units per pixel), fading to 0 before it gets small enough to flicker.
float band(float repeats, float px) {
	return 1.0 - smoothstep(0.12, 0.35, px * repeats);
}

// Tilts the normal n by the slope of a height, from how the position and the
// height change from one pixel to the next (bump mapping without tangents,
// after Mikkelsen 2010).
vec3 bumped(vec3 n, vec3 dpdx, vec3 dpdy, float dhdx, float dhdy) {
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	vec3 result = abs(det) * n - grad;
	return dot(result, result) > 0.0 ? normalize(result) : n;
}
