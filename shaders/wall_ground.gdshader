shader_type spatial;
// The ground at the foot of a climbing wall (see WallScenery): earth, pebbles, moss and grass in patches laid by noise
// in world space, darker and mossier right at the wall (where the rock shades it), and fading into the haze of the
// distance so it meets the mountains without an edge.
render_mode cull_disabled;

uniform vec3 earth : source_color = vec3(0.36, 0.3, 0.22);
uniform vec3 rock : source_color = vec3(0.45, 0.44, 0.41);
uniform vec3 moss : source_color = vec3(0.26, 0.36, 0.15);
uniform vec3 grass : source_color = vec3(0.36, 0.46, 0.2);
uniform vec3 haze : source_color = vec3(0.6, 0.66, 0.74);
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float wall_z = 0.0;

varying vec3 world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float big = fbm(p * 0.07);
	float mid = fbm(p * 0.35 + 3.1);
	float fine = fbm(p * 2.6);
	float grit = vnoise(p * 14.0);
	// How close to the wall's foot (the shade and the damp there), 0 away, 1 at it.
	float foot = 1.0 - smoothstep(0.0, 5.0, world.z - wall_z);
	vec3 c = mix(earth, rock, smoothstep(0.35, 0.7, mid));
	float green = smoothstep(0.42, 0.62, big + 0.25 * mid) * (0.55 + 0.6 * foot);
	c = mix(c, mix(moss, grass, fine), green * (1.0 - snow));
	// Pebbles and grit.
	c *= 0.8 + 0.4 * fine;
	c = mix(c, rock * 1.25, step(0.9, grit) * 0.5 * (1.0 - green));
	// The shade under the rock.
	c *= 1.0 - 0.3 * foot;
	c = mix(c, vec3(0.9, 0.92, 0.96), snow * (0.55 + 0.4 * fine));
	c *= 1.0 - 0.15 * wet;
	float dist = length(world - vec3(CAMERA_POSITION_WORLD.x, world.y, CAMERA_POSITION_WORLD.z));
	c = mix(c, haze, smoothstep(40.0, 180.0, dist) * 0.85);
	ALBEDO = c * 1.5;
	ROUGHNESS = mix(0.95, 0.55, wet);
}
