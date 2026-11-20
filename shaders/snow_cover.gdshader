shader_type spatial;
render_mode cull_back;
// A layer of snow on everything that faces the sky (see SnowCover). It is laid
// over every mesh of the open air as its material overlay: wherever a surface
// faces up it draws snow, and nowhere else, so roofs, ledges, fence tops, rocks,
// branches and the ground are all covered by one shader. The snow builds up in
// patches with `amount` (0 bare, 1 deep), so the first flakes settle on the
// flattest tops and the ground fills in last. Its look is in snow.gdshaderinc.
//
// Where a roof stands over the floor (the old house) the sky mask says there
// is no snow below the roof line.

#include "res://shaders/snow.gdshaderinc"

// Where a roof stands over the ground: R is 1 on those tiles.
uniform sampler2D sky_mask : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(1.0);
uniform float tile = 4.0;
// Where the hero has dug a cellar (R is 1 on each dug 2 m cell, see Outdoor.set_floor_holes): the
// ground is cut away there, so no snow lies on the hole or on the cellar floor below it.
uniform sampler2D hole_mask : filter_nearest, repeat_disable, hint_default_black;
uniform bool holes_on = false;
// The height under which a covered tile is not open to the sky.
uniform float roof_height = 3.6;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The snow lies a little above the surface it covers, so it wins the depth test, and
	// thicker as it deepens.
	wp += wn * (0.03 + 0.03 * amount) * smoothstep(0.3, 0.8, wn.y);
	world_pos = wp;
	world_normal = wn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float up = smoothstep(0.5, 0.82, world_normal.y);
	vec2 xz = world_pos.xz;
	float n = snow_noise(xz * 1.3) * 0.65 + snow_noise(xz * 5.0 + 7.0) * 0.35;
	// A drift gathers where the noise is high: the snow arrives in patches and joins up.
	float lies = up * amount * 1.5 + (n - 0.5) * 0.55;
	vec2 uv = (xz / tile + 0.5) / grid_size;
	float roofed = texture(sky_mask, uv).r * (1.0 - step(roof_height, world_pos.y));
	// Melted round fires, the forge and smoking chimneys. Open water and ice stay bare (G of the
	// mask marks the pond tiles, only at ground level).
	float pond = texture(sky_mask, uv).g * (1.0 - step(0.3, world_pos.y));
	float dug = 0.0;
	if (holes_on && world_pos.y < 0.3) {
		vec2 hole_uv = (xz + vec2(0.5 * tile)) / (grid_size * tile);
		if (hole_uv.x >= 0.0 && hole_uv.y >= 0.0 && hole_uv.x <= 1.0 && hole_uv.y <= 1.0) {
			dug = texture(hole_mask, hole_uv).r;
		}
	}
	if (dug > 0.5 || lies < 0.5 || roofed > 0.5 || pond > 0.5 || up < 0.01 || snow_melted(world_pos, n)) {
		discard;
	}
	snow_look(world_pos, world_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	ROUGHNESS = 0.85;
	SPECULAR = 0.3 * mix(0.4, 1.0, daylight);
}
