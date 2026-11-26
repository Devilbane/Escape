shader_type spatial;
render_mode cull_back;
#include "res://shaders/gl_colour.gdshaderinc"
// The snow cover for the houses built from the village kit (see SnowCover.house_material): the same
// as snow_cover.gdshader, and in addition patches of wind-blown snow clinging to the upright walls.
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
#include "res://shaders/shore.gdshaderinc"

// Where a roof stands over the ground: R is 1 on those tiles.
uniform sampler2D sky_mask : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(1.0);
uniform float tile = 4.0;
// Where the hero has dug a cellar (R is 1 on each dug 2 m cell, see Outdoor.set_floor_holes): the
// ground is cut away there, so no snow lies on the hole or on the cellar floor below it. A cell
// closed by a cellar ceiling is 0.5: snow lies on the ceiling, but not in the cellar under it.
uniform sampler2D hole_mask : filter_nearest, repeat_disable, hint_default_black;
uniform bool holes_on = false;
// On while the hero is down in a cellar: what is left of the map there (the ladder, the stairs, the walls)
// shows no snow, which belongs to the open air above.
uniform bool underground = false;
// The ground the herald has swept with his broom (see SnowSweep): R is the hour of snowfall (plus one) it was swept at, G how
// close it lies to the middle of the stroke, one pixel for each swept_step metres from the world's corner. It fills in again
// as snow falls: swept_refill hours of snowfall after the stroke it is white once more.
uniform sampler2D swept_mask : filter_linear, repeat_disable, hint_default_black;
uniform bool swept_on = false;
uniform float swept_fall = 0.0;
uniform float swept_refill = 1.5;
uniform float swept_step = 0.3;
// The rooms of the buildings one walks into (see SnowCover.set_rooms): R is how high they reach
// and G from which height (the upper storey's overhang), both in SHELTER_SCALE metres, in ROOM_STEP pixels from the world's corner, so the snow stops at their
// walls and stays off every storey under their roof.
uniform sampler2D room_mask : filter_nearest, repeat_disable, hint_default_black;
uniform bool rooms_on = false;
// The height under which a covered tile is not open to the sky.
uniform float roof_height = 3.6;

// How much wind-blown snow clings to the upright walls (0 keeps them bare).
uniform float wall_cling = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The snow lies a little above the surface it covers, so it wins the depth test, and
	// thicker as it deepens.
	wp += wn * (0.03 + 0.03 * amount) * smoothstep(0.3, 0.8, wn.y);
	// Wall snow stands a hair off the wall, so it wins the depth test.
	wp += wn * 0.025 * (1.0 - smoothstep(0.1, 0.5, abs(wn.y))) * 1.0;
	world_pos = wp;
	world_normal = wn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float up = smoothstep(0.5, 0.82, world_normal.y);
	// Upright faces of a mesh that takes wall snow: patches of it cling in drifts of noise.
	bool is_wall = abs(world_normal.y) < 0.4;
	vec2 xz = world_pos.xz;
	float n = snow_noise(xz * 1.3) * 0.65 + snow_noise(xz * 5.0 + 7.0) * 0.35;
	// A drift gathers where the noise is high: the snow arrives in patches and joins up.
	float lies = up * amount * 1.5 + (n - 0.5) * 0.55;
	vec2 uv = (xz / tile + 0.5) / grid_size;
	float roofed = texture(sky_mask, uv).r * (1.0 - step(roof_height, world_pos.y));
	if (rooms_on) {
		vec2 room_uv = (xz + vec2(0.5 * tile)) / (grid_size * tile);
		if (room_uv.x >= 0.0 && room_uv.y >= 0.0 && room_uv.x <= 1.0 && room_uv.y <= 1.0) {
			// Below the rooms' ceiling (the eaves), every storey is inside.
			vec2 room = texture(room_mask, room_uv).rg * SHELTER_SCALE;
			roofed = max(roofed, step(world_pos.y, room.x) * step(room.y, world_pos.y));
		}
	}
	// Melted round fires, the forge and smoking chimneys. Open water and ice stay bare (G of the
	// mask marks the pond tiles, only at ground level).
	float pond = texture(sky_mask, uv).g * (1.0 - step(0.3, world_pos.y));
	if (shore_on) {
		// The shore's own curves (see shore.gdshaderinc), and as far out as the ice reaches past
		// them (meadow.gdshader), so no strip of bare bank shows between the snow and the ice.
		pond = step(-0.5, shore_at(uv, xz)) * (1.0 - step(0.3, world_pos.y));
	}
	float dug = 0.0;
	if (holes_on && world_pos.y < 0.3) {
		vec2 hole_uv = (xz + vec2(0.5 * tile)) / (grid_size * tile);
		if (hole_uv.x >= 0.0 && hole_uv.y >= 0.0 && hole_uv.x <= 1.0 && hole_uv.y <= 1.0) {
			dug = texture(hole_mask, hole_uv).r;
		}
	}
	// Swept bare: the stroke's edge is ragged (noise moves it in and out) and a few small patches of snow stand.
	float swept = 0.0;
	if (swept_on && world_pos.y < 0.3) {
		vec2 swept_uv = (xz + vec2(0.5 * tile)) / (grid_size * tile);
		if (swept_uv.x >= 0.0 && swept_uv.y >= 0.0 && swept_uv.x <= 1.0 && swept_uv.y <= 1.0) {
			vec2 sw = texture(swept_mask, swept_uv).rg;
			float fresh = clamp((swept_fall - (sw.r - 1.0)) / swept_refill, 0.0, 1.0);
			float edge = 0.3 + 0.4 * snow_noise(xz * 4.0 + 3.0) + 0.45 * smoothstep(0.62, 0.8, snow_noise(xz * 2.6 + 11.0));
			swept = step(edge, sw.g * (1.0 - fresh) * step(0.5, sw.r));
		}
	}
	if (is_wall) {
		float wn_a = snow_noise(vec2(xz.x + xz.y, world_pos.y) * 3.5) * 0.5 + snow_noise(vec2(xz.x - xz.y, world_pos.y) * 9.0 + 3.0) * 0.5;
		// Drifted up against the foot of the wall, thinning out higher up.
		float wall_lies = wall_cling * amount + (wn_a - 0.5) * 0.9 + 0.3 * (1.0 - smoothstep(0.4, 1.8, world_pos.y));
		// Never on the inside faces of a room one walks into (the rooms mask just in front of the face).
		float inside = 0.0;
		if (rooms_on) {
			vec2 front = xz + world_normal.xz * 0.3;
			vec2 room_uv = (front + vec2(0.5 * tile)) / (grid_size * tile);
			if (room_uv.x >= 0.0 && room_uv.y >= 0.0 && room_uv.x <= 1.0 && room_uv.y <= 1.0) {
				vec2 room = texture(room_mask, room_uv).rg * SHELTER_SCALE;
				inside = step(world_pos.y, room.x) * step(room.y, world_pos.y);
			}
		}
		if (underground || inside > 0.5 || wall_lies < 0.5 || snow_melted(world_pos, n) || snow_sheltered(world_pos)) {
			discard;
		}
	} else if (swept > 0.5 || underground || dug > 0.75 || (dug > 0.25 && world_pos.y < -0.05) || lies < 0.5 || roofed > 0.5 || pond > 0.5 || up < 0.01 || snow_melted(world_pos, n) || snow_sheltered(world_pos)) {
		discard;
	}
	// Wall snow is lit as if tilted towards the sky, so it reads as snow and not as grey flanks.
	vec3 look_normal = is_wall ? normalize(mix(world_normal, vec3(0.0, 1.0, 0.0), 0.55)) : world_normal;
	snow_look(world_pos, look_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	ROUGHNESS = is_wall ? 0.95 : 0.95;
	SPECULAR = (is_wall ? 0.05 : 0.08) * mix(0.4, 1.0, daylight);
	ALBEDO = gl_colour(ALBEDO);
}
