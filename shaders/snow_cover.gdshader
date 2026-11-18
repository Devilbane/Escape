shader_type spatial;
render_mode cull_back;
// A layer of snow on everything that faces the sky (see SnowCover). It is laid
// over every mesh of the open air as its material overlay: wherever a surface
// faces up it draws white snow, and nowhere else, so roofs, ledges, fence
// tops, rocks, branches and the ground are all covered by one shader. The
// snow builds up in patches with `amount` (0 bare, 1 deep), so the first
// flakes settle on the flattest tops and the ground fills in last.
//
// Where a roof stands over the floor (the old house) the sky mask says there
// is no snow below the roof line.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.93, 0.95, 1.0);
// How much of the light of the hour is on the snow (0 night to 1 day): the
// night's snow glows a little blue, so it is not as black as the ground was.
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// Where a roof stands over the ground: R is 1 on those tiles.
uniform sampler2D sky_mask : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(1.0);
uniform float tile = 4.0;
// The height under which a covered tile is not open to the sky.
uniform float roof_height = 3.6;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The snow lies a hair above the surface it covers, so it wins the depth test.
	wp += wn * 0.03 * smoothstep(0.3, 0.8, wn.y);
	world_pos = wp;
	world_normal = wn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float up = smoothstep(0.5, 0.82, world_normal.y);
	vec2 xz = world_pos.xz;
	float n = noise(xz * 1.3) * 0.65 + noise(xz * 5.0 + 7.0) * 0.35;
	float strength = up * amount;
	// A drift gathers where the noise is high: the snow arrives in patches and joins up.
	float lies = strength * 1.5 + (n - 0.5) * 0.55;
	vec2 uv = (xz / tile + 0.5) / grid_size;
	float roofed = texture(sky_mask, uv).r * (1.0 - step(roof_height, world_pos.y));
	if (lies < 0.5 || roofed > 0.5 || up < 0.01) {
		discard;
	}
	// A touch of shade in the hollows of the drifts, so the layer is not flat white.
	float shade = 0.9 + 0.1 * noise(xz * 2.2 + 3.0);
	ALBEDO = snow_color * shade;
	ROUGHNESS = 0.8;
	SPECULAR = 0.35;
	// Glints of ice in the snow, and a faint cold glow at night.
	vec2 cell_id = floor(xz * 30.0);
	float cell = hash(cell_id + floor(TIME * 0.7 + hash(cell_id) * 8.0));
	float glint = step(0.995, cell) * daylight;
	EMISSION = vec3(0.55, 0.65, 0.95) * 0.06 * (1.0 - daylight) + vec3(0.9, 0.95, 1.0) * glint * 0.35;
}
