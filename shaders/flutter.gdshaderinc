// Flags and banners flutter in the wind (see FlagWind). A wave runs through
// the cloth from the edge it hangs by (the pole or the rod) to its free end:
// the fixed edge stays put and the free end swings furthest. How hard and how
// fast comes from the wind (wind_strength, wind_phase), which FlagWind sets
// each frame by the weather outside, or as a soft draught in the dungeon.
// Everything is in the mesh's own space, so it holds at any size or turn.
// A material with flutter 0 (every prop that is no flag) stays still.

// How far the free end swings, as a share of the cloth's length; 0: still.
uniform float flutter = 0.0;
// A point on the fixed edge, and the way from it to the free end.
uniform vec3 flutter_root = vec3(0.0);
uniform vec3 flutter_reach = vec3(0.0, -1.0, 0.0);
// The way the cloth swings to and fro (across its face).
uniform vec3 flutter_push = vec3(0.0, 0.0, 1.0);
// The wind: 1 is a breeze, more in a storm; and how far its waves have run.
uniform float wind_strength = 1.0;
uniform float wind_phase = 0.0;

// Moves a vertex of the cloth (and turns its normal and tangent with the
// bend, so the light ripples along); `seed` differs from flag to flag.
void flutter_vertex(inout vec3 v, inout vec3 n, inout vec3 t, float seed) {
	if (flutter <= 0.0) {
		return;
	}
	float len2 = max(dot(flutter_reach, flutter_reach), 1e-8);
	float raw = dot(v - flutter_root, flutter_reach) / len2;
	float w = clamp(raw, 0.0, 1.0);
	float inside = step(0.0, raw) * step(raw, 1.0);
	// Two quick waves running out to the free end (about one ripple along
	// the cloth), and a slow swell under them.
	float a = wind_phase + seed - w * 6.0;
	float wave = sin(a) + 0.35 * sin(1.7 * a + 1.3) + 0.4 * sin(0.37 * wind_phase + seed * 1.9);
	float dwave = -6.0 * (cos(a) + 0.35 * 1.7 * cos(1.7 * a + 1.3));
	float amp = flutter * sqrt(len2) * wind_strength;
	float d = amp * w * wave;
	// How fast the swing grows along the cloth (the slope of the bend).
	float slope = amp * (wave + w * dwave) * inside;
	vec3 grad = flutter_reach / len2;
	v += flutter_push * d;
	n = normalize(n - grad * slope * dot(flutter_push, n));
	t = normalize(t + flutter_push * slope * dot(grad, t));
}
