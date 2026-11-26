shader_type spatial;
render_mode cull_back;
#include "res://shaders/gl_colour.gdshaderinc"
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
// The same rooms exactly (see SnowCover.set_rooms): each one's ground floor as x0, z0, x1, z1 and,
// in room_extra, how far its upper storey juts out (x) and from which height (y). The mask above is
// coarse (one pixel is ROOM_STEP wide), so where it says "inside" these draw the true walls: no strip of
// bare lawn is left outside them. Off (rooms_exact false) when there are too many to list.
const int ROOM_MAX = 48;
uniform vec4 room_rects[ROOM_MAX];
uniform vec4 room_extra[ROOM_MAX];
uniform int room_count = 0;
uniform bool rooms_exact = false;
// The height under which a covered tile is not open to the sky.
uniform float roof_height = 3.6;

// How high the snow of the plain climbs the foot of a steep slope before it gives out (metres), and how steep
// a face it still climbs, as the y of its normal: none on a vertical wall (0.05), all of it from 0.3, which is
// leaner than the mountain's foot (about 0.38) and its facets.
const float SKIRT_HEIGHT = 3.0;
const float SKIRT_SLOPE_FROM = 0.16;
const float SKIRT_SLOPE_TO = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The snow lies a little above the surface it covers, so it wins the depth test, and
	// thicker as it deepens.
	// (and on the skirt of snow up the foot of a steep slope, see fragment)
	float lift = max(smoothstep(0.3, 0.8, wn.y), (1.0 - smoothstep(0.0, SKIRT_HEIGHT, wp.y)) * smoothstep(SKIRT_SLOPE_FROM, SKIRT_SLOPE_TO, wn.y));
	wp += wn * (0.03 + 0.03 * amount) * lift;
	world_pos = wp;
	world_normal = wn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	vec2 xz = world_pos.xz;
	float n = snow_noise(xz * 1.3) * 0.65 + snow_noise(xz * 5.0 + 7.0) * 0.35;
	// The foot of a mountain face: where the snow of the plain meets steep rock it must not stop at a
	// hard line. Close to the ground the slope counts as lying snow, fading out with height along a
	// ragged edge (the noise moves it up and down), and its snow is lit like the flat snow below it.
	// Noise of the spot in 3D (a slope's x, y and z all move it, so no horizontal bands or cell lines form), at
	// three scales: big drifts, ledges and fine feathering.
	vec3 sp = world_pos * vec3(1.0, 1.4, 1.0);
	float drift = snow_noise(sp.xz * 0.5 + sp.y * 0.9) * 0.6 + snow_noise(sp.xz * 1.7 - sp.y * 1.3 + 4.0) * 0.4;
	float feather = snow_noise(vec2(sp.x * 3.1 + sp.y * 2.3, sp.z * 3.1 - sp.y * 2.7)) * 0.6 + snow_noise(vec2(sp.x * 8.3 - sp.y * 6.1, sp.z * 8.3 + sp.y * 5.2) + 9.0) * 0.4;
	float skirt = (1.0 - smoothstep(0.0, SKIRT_HEIGHT * (0.45 + 1.1 * drift), world_pos.y)) * smoothstep(SKIRT_SLOPE_FROM, SKIRT_SLOPE_TO, world_normal.y);
	float up_plain = smoothstep(0.5, 0.82, world_normal.y);
	float up = max(up_plain, skirt);
	vec3 look_normal = normalize(mix(world_normal, vec3(0.0, 1.0, 0.0), skirt));
	// A drift gathers where the noise is high: the snow arrives in patches and joins up.
	float lies = up_plain * amount * 1.5 + (n - 0.5) * 0.55;
	// The skirt gives out in a feathered, noisy fade: the lower the snow lies on the slope (skirt is 1 at the
	// ground and thins with height and steepness) the more of the noise it takes to hold, so the edge is a soft
	// cloud of patches that thin out into the bare rock, not a line or a band of stripes.
	lies = max(lies, skirt * amount * 1.2 + (drift - 0.5) * 0.35 + (feather - 0.5) * 0.7);
	vec2 uv = (xz / tile + 0.5) / grid_size;
	float roofed = texture(sky_mask, uv).r * (1.0 - step(roof_height, world_pos.y));
	if (rooms_on) {
		vec2 room_uv = (xz + vec2(0.5 * tile)) / (grid_size * tile);
		if (room_uv.x >= 0.0 && room_uv.y >= 0.0 && room_uv.x <= 1.0 && room_uv.y <= 1.0) {
			// Below the rooms' ceiling (the eaves), every storey is inside.
			vec2 room = texture(room_mask, room_uv).rg * SHELTER_SCALE;
			float inside = step(world_pos.y, room.x) * step(room.y, world_pos.y);
			if (inside > 0.5 && rooms_exact) {
				// Only where the coarse mask says inside: is the spot within a room's true walls?
				float within = 0.0;
				for (int i = 0; i < ROOM_MAX; i++) {
					if (i >= room_count) {
						break;
					}
					vec4 r = room_rects[i];
					float grow = world_pos.y >= room_extra[i].y ? room_extra[i].x : 0.0;
					within = max(within, step(r.x - grow, xz.x) * step(xz.x, r.z + grow) * step(r.y - grow, xz.y) * step(xz.y, r.w + grow));
				}
				inside *= within;
			}
			roofed = max(roofed, inside);
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
	if (swept > 0.5 || underground || dug > 0.75 || (dug > 0.25 && world_pos.y < -0.05) || lies < 0.5 || roofed > 0.5 || pond > 0.5 || up < 0.01 || snow_melted(world_pos, n) || snow_sheltered(world_pos)) {
		discard;
	}
	snow_look(world_pos, look_normal, VIEW_MATRIX, TIME, ALBEDO, NORMAL, EMISSION);
	ROUGHNESS = 0.95;
	SPECULAR = 0.08 * mix(0.4, 1.0, daylight);
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
