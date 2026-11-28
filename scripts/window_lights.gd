class_name WindowLights
extends RefCounted
## The village going to sleep, window by window. Every pane of a house (and the
## pool of light it throws, see WindowSpill) has its own bedtime between
## OFF_FROM and OFF_TO, worked out in the shader from where the pane stands, so
## it is the same every night and after every load, and nothing is stored.
## The panes go dark in a short fade, and stay dark until the day breaks. The
## temple's windows do not use this: they burn all night.

## Hours of the clock between which the first and the last window is lit in
## the evening (each fades in over FADE; the dusk's own glow rises meanwhile).
const ON_FROM := 18.0
const ON_TO := 20.4
## Hours of the clock between which the first and the last window goes out.
const OFF_FROM := 20.0
const OFF_TO := 22.9
## The daily cycle. Every window has a fixed time of its own for its shutters and another for its curtains,
## each drawn independently from its place (so it is the same every day and nothing is stored): in the
## morning the shutters open between SHUTTERS_OPEN and +SHUTTERS_OPEN_SPREAD, the curtains between
## CURTAINS_OPEN and +CURTAINS_OPEN_SPREAD; in the evening they close between ..._FROM and ..._TO. A leaf
## swings for SHUTTER_SWING hours and the curtains draw over CURTAIN_DRAW. Nothing runs for a window
## between its two times: the shader just evaluates the hour.
const SHUTTERS_OPEN := 6.0
const SHUTTERS_OPEN_SPREAD := 1.2
const CURTAINS_OPEN := 6.3
const CURTAINS_OPEN_SPREAD := 1.5
const SHUTTERS_CLOSE_FROM := 17.8
const SHUTTERS_CLOSE_TO := 20.6
const CURTAINS_CLOSE_FROM := 17.6
const CURTAINS_CLOSE_TO := 20.6
const SHUTTER_SWING := 0.075
## The mage's tower is different: its magic draws the curtains one window after another, MAGE_STEP hours
## apart (0.5 s of a day of DayNight.DAY_LENGTH seconds), round the tower and up its floors, then the
## shutters the same way; in the morning the shutters open, then the curtains. A window's place in
## the circle (1 up to MAGIC_LEVELS - 1, 0 for any other window) is the blue of its vertex colour.
const MAGE_STEP := 0.01
const MAGE_CURTAINS_CLOSE := 19.0
const MAGE_SHUTTERS_CLOSE := 19.5
const MAGE_SHUTTERS_OPEN := 6.3
const MAGE_CURTAINS_OPEN := 6.85
const MAGIC_LEVELS := 32.0
const CURTAIN_DRAW := 0.15
## How long one window takes to fade, in hours.
const FADE := 0.1

## GLSL: how lit (0 to 1) the window with this key is at this hour. The key
## is the pane's place in its house plus the house's place in the world.
const LIT_FUNCTION := """
uniform float hour = 12.0;
float window_off(vec2 place) {
	vec2 k = floor(place * 4.0 + 0.5);
	float h = fract(sin(dot(k, vec2(12.9898, 78.233))) * 43758.5453);
	return mix(%f, %f, h);
}
float window_lit(vec2 place) {
	vec2 k = floor(place * 4.0 + 0.5);
	float off = window_off(place);
	float h2 = fract(sin(dot(k, vec2(39.346, 11.135))) * 24634.6345);
	float on = mix(%f, %f, h2);
	// After midnight everyone sleeps; the glow itself fades with the dawn.
	if (hour < 12.0) {
		return 0.0;
	}
	return smoothstep(on, on + %f, hour) * (1.0 - smoothstep(off, off + %f, hour));
}
""" % [OFF_FROM, OFF_TO, ON_FROM, ON_TO, FADE, FADE]

## The pane seen from outside: real glass over a room. Behind the glass hang a pair of curtains (a
## woven cloth in a colour of the house's own, plain, striped or checked, in folds, tied back at the
## middle, with a short pelmet and a brass rod), and between them the dim room. At night the room is
## lit and the curtains glow in their own colour. UV is the pane in metres (0.8 wide, 0.9 high).
## The daily cycle of every window. Each has a small random lead of its own (sched, 0 to 1), so
## the village does not do it all at once. In the evening, as the residents come home, the curtains
## close first, then the shutters; they stay shut until the morning, when the shutters open first
## and the curtains after. GLSL, and `sched`, `curtains_shut` and `shutters_shut` below the same in
## GDScript (the sounds of the shutters follow the shader, see Outdoor._shutter_sounds).
const SHUT_FUNCTION := """
// A house whose people are about acts a little early (see Outdoor._mind_the_neighbours): it gets a
// copy of the material with this many hours added to its clock.
uniform float nudge = 0.0;
float sched(vec2 place) {
	vec2 k = floor(place * 4.0 + 0.5);
	return fract(dot(k, vec2(0.7548776662, 0.5698402910)));
}
float sched_shutters(vec2 place) {
	vec2 k = floor(place * 4.0 + 0.5);
	return fract(dot(k, vec2(0.6180339887, 0.4142135624)) + 0.37);
}
float curtains_shut(vec2 place, float magic) {
	float h = sched(place);
	float lag = max(magic - 1.0, 0.0) * %f;
	float now = hour + nudge;
	if (hour < 12.0) {
		float open = (magic > 0.5 ? %f + lag : %f + %f * h);
		return 1.0 - smoothstep(open, open + %f, now);
	}
	float back = (magic > 0.5 ? %f + lag : mix(%f, %f, h));
	return smoothstep(back, back + %f, now);
}
float shutters_shut(vec2 place, float magic) {
	float h = sched_shutters(place);
	float lag = max(magic - 1.0, 0.0) * %f;
	float now = hour + nudge;
	if (hour < 12.0) {
		float open = (magic > 0.5 ? %f + lag : %f + %f * h);
		return 1.0 - smoothstep(open, open + %f, now);
	}
	float back = (magic > 0.5 ? %f + lag : mix(%f, %f, h));
	return smoothstep(back, back + %f, now);
}
""" % [MAGE_STEP, MAGE_CURTAINS_OPEN, CURTAINS_OPEN, CURTAINS_OPEN_SPREAD, CURTAIN_DRAW,
		MAGE_CURTAINS_CLOSE, CURTAINS_CLOSE_FROM, CURTAINS_CLOSE_TO, CURTAIN_DRAW,
		MAGE_STEP, MAGE_SHUTTERS_OPEN, SHUTTERS_OPEN, SHUTTERS_OPEN_SPREAD, SHUTTER_SWING,
		MAGE_SHUTTERS_CLOSE, SHUTTERS_CLOSE_FROM, SHUTTERS_CLOSE_TO, SHUTTER_SWING]

## How many hours sooner a house acts when someone comes near it (see Outdoor._mind_the_neighbours).
const NEIGHBOUR_NUDGE := 0.25


## GDScript: whether any window's shutters or curtains can be moving at this hour (the two bands of the
## cycle, widened by the neighbours' nudge). Outside them nothing has to be looked at.
static func shutters_moving(at_hour: float) -> bool:
	var early := minf(SHUTTERS_OPEN, CURTAINS_OPEN) - NEIGHBOUR_NUDGE - 0.01
	var late := maxf(SHUTTERS_OPEN + SHUTTERS_OPEN_SPREAD + SHUTTER_SWING, CURTAINS_OPEN + CURTAINS_OPEN_SPREAD + CURTAIN_DRAW) + 0.01
	var dusk := minf(SHUTTERS_CLOSE_FROM, CURTAINS_CLOSE_FROM) - NEIGHBOUR_NUDGE - 0.01
	var night := maxf(SHUTTERS_CLOSE_TO + SHUTTER_SWING, CURTAINS_CLOSE_TO + CURTAIN_DRAW) + 0.01
	return (at_hour >= early and at_hour <= late) or (at_hour >= dusk and at_hour <= night)


## GDScript: the window's own draw for its curtains, 0 to 1 (see SHUT_FUNCTION).
static func sched(place: Vector2) -> float:
	var k := (place * 4.0 + Vector2(0.5, 0.5)).floor()
	return fposmod(k.x * 0.7548776662 + k.y * 0.5698402910, 1.0)


## GDScript: the same for its shutters, drawn independently of the curtains.
static func sched_shutters(place: Vector2) -> float:
	var k := (place * 4.0 + Vector2(0.5, 0.5)).floor()
	return fposmod(k.x * 0.6180339887 + k.y * 0.4142135624 + 0.37, 1.0)


## GDScript: how far (0 to 1) the curtains of the window with this key are drawn at this hour; `magic`
## is the window's place in the mage tower's circle (0 for any other, see MAGE_STEP).
static func curtains_shut(place: Vector2, at_hour: float, magic := 0) -> float:
	var lag := maxf(magic - 1.0, 0.0) * MAGE_STEP
	if at_hour < 12.0:
		var open := MAGE_CURTAINS_OPEN + lag if magic > 0 else CURTAINS_OPEN + CURTAINS_OPEN_SPREAD * sched(place)
		return 1.0 - smoothstep(open, open + CURTAIN_DRAW, at_hour)
	var back := MAGE_CURTAINS_CLOSE + lag if magic > 0 else lerpf(CURTAINS_CLOSE_FROM, CURTAINS_CLOSE_TO, sched(place))
	return smoothstep(back, back + CURTAIN_DRAW, at_hour)


## GDScript: how shut (0 to 1) the shutters of the window with this key are at this hour.
static func shutters_shut(place: Vector2, at_hour: float, magic := 0) -> float:
	var lag := maxf(magic - 1.0, 0.0) * MAGE_STEP
	if at_hour < 12.0:
		var open := MAGE_SHUTTERS_OPEN + lag if magic > 0 else SHUTTERS_OPEN + SHUTTERS_OPEN_SPREAD * sched_shutters(place)
		return 1.0 - smoothstep(open, open + SHUTTER_SWING, at_hour)
	var back := MAGE_SHUTTERS_CLOSE + lag if magic > 0 else lerpf(SHUTTERS_CLOSE_FROM, SHUTTERS_CLOSE_TO, sched_shutters(place))
	return smoothstep(back, back + SHUTTER_SWING, at_hour)


## GLSL: the curtains of a window (see the glass and CURTAIN_SHADER). `uv` is the place on the pane in
## metres (0.8 wide, 0.9 high); returns the colour of the cloth, brass or pelmet and in .a how solid it
## is there (0 in the open middle), and `lit_tint` how it takes the warm light of the room at night.
const CLOTH_FUNCTION := """
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 289.17))) * 43758.5453);
}
// What is the same all over one window, worked out once per vertex instead of in every pixel: the
// house's cloth (six dyes, a little different from house to house) and the window's own whims
// (x: the house's draw, y: the window's, z: the house's pattern).
vec3 cloth_dye(vec2 hm) {
	float hh = h21(hm);
	vec3 dye = vec3(0.85, 0.8, 0.68);
	if (hh < 0.17) {
		dye = vec3(0.72, 0.27, 0.2);
	} else if (hh < 0.34) {
		dye = vec3(0.3, 0.5, 0.34);
	} else if (hh < 0.5) {
		dye = vec3(0.82, 0.62, 0.22);
	} else if (hh < 0.66) {
		dye = vec3(0.24, 0.33, 0.58);
	} else if (hh < 0.83) {
		dye = vec3(0.52, 0.16, 0.26);
	}
	return dye * (0.9 + 0.2 * h21(hm + 3.7));
}
vec3 cloth_whims(vec2 hm, vec2 pk) {
	return vec3(h21(hm), h21(pk * 0.5 + 5.3), h21(hm + 9.1));
}
vec4 drape(vec2 uv, vec3 dye, vec3 whims, vec2 pk, float magic, out vec3 lit_tint) {
	vec2 q = clamp(vec2(uv.x / 0.8, uv.y / 0.9), 0.0, 1.0);
	// How much of the pane (in metres) one pixel covers: fine detail (the weave, folds, stripes)
	// fades out where it is finer than that, or it shimmers as the view moves.
	float px = fwidth(uv.x) + fwidth(uv.y);
	float hh = whims.x;
	float wk = whims.y;
	// The drape: a panel at each side of the window, gathered by a tieback in the lower third, narrow
	// there, wide at the rod and flaring to the hem, so the glass in the middle stays bare. Drawn shut
	// (see curtains_shut) the two panels meet in the middle.
	float d = min(q.x, 1.0 - q.x);
	float shut = curtains_shut(pk, magic);
	float tie_y = 0.3;
	float above = smoothstep(tie_y, 0.95, q.y);
	float below = smoothstep(tie_y, 0.0, q.y);
	float open_reach = 0.17 + 0.05 * wk + 0.12 * above + 0.1 * below;
	float reach = mix(open_reach, 0.52, shut);
	float cover = smoothstep(reach + 0.012, reach - 0.012, d);
	// Long soft pleats run down the cloth: deeper towards the wall, drifting a little with the height.
	float fold = 0.5 + 0.5 * sin(d * 52.0 + hh * 6.0 + sin(q.y * 2.4 + hh * 4.0) * 0.8) * clamp(1.0 - px * 32.0, 0.0, 1.0);
	float depth_in = smoothstep(0.0, reach, reach - d);
	float shade = 0.6 + 0.5 * fold - 0.18 * depth_in;
	// Shut, the pleats stay the same; open, the tieback pulls the cloth in a little: a darker crease
	// above and below the cord.
	float cord_y = abs(q.y - tie_y);
	shade *= 1.0 - 0.25 * (1.0 - shut) * smoothstep(0.1, 0.03, cord_y) * (1.0 - smoothstep(0.03, 0.0, cord_y));
	// A pattern in the cloth: stripes, checks or plain, by house.
	float kind = whims.z;
	vec3 cloth = dye;
	if (kind < 0.3) {
		cloth = mix(dye, vec3(0.9, 0.86, 0.74), mix(0.5, step(0.5, fract(d * 15.0)), clamp(1.0 - px * 20.0, 0.0, 1.0)) * 0.55);
	} else if (kind < 0.5) {
		float chk = abs(mix(0.5, step(0.5, fract(d * 12.0)), clamp(1.0 - px * 15.0, 0.0, 1.0)) - mix(0.5, step(0.5, fract(q.y * 10.0)), clamp(1.0 - px * 13.0, 0.0, 1.0)));
		cloth = mix(dye, dye * 0.55, chk);
	}
	// The weave: fine threads, left out where a pixel would cover several of them.
	float aa = clamp(1.0 - px * 90.0, 0.0, 1.0);
	float weave = 1.0 + aa * 0.09 * sin(uv.x * 240.0) * sin(uv.y * 280.0);
	cloth *= shade * weave;
	// A band of trim along the hem.
	cloth = mix(cloth, dye * 1.2 + 0.05, smoothstep(0.075, 0.06, q.y) * smoothstep(0.03, 0.04, q.y));
	// The tieback: a cord round the gathered panel with a small tassel hanging at its inner end.
	vec3 cord_col = dye * 0.55 + vec3(0.32, 0.26, 0.1);
	float cord = step(cord_y, 0.014) * (1.0 - shut) * cover;
	float tassel = (1.0 - shut) * step(abs(d - reach * 0.9), 0.012) * step(tie_y - 0.07, q.y) * step(q.y, tie_y) * cover;
	cloth = mix(cloth, cord_col * (0.8 + 0.4 * sin(uv.x * 400.0) * clamp(1.0 - px * 200.0, 0.0, 1.0)), max(cord, tassel));
	// The pelmet across the top: scalloped, and the brass rod above it.
	float scallop = 0.86 + 0.03 * abs(sin(q.x * 15.7));
	float pelmet = step(scallop, q.y);
	vec3 pel = dye * (0.92 + 0.18 * sin(q.x * 90.0 + hh * 5.0) * clamp(1.0 - px * 60.0, 0.0, 1.0)) * weave;
	vec3 brass = vec3(0.4, 0.3, 0.13) * (0.7 + 0.6 * sin(q.y * 260.0) * clamp(1.0 - px * 150.0, 0.0, 1.0));
	float rod = step(0.955, q.y);
	vec3 seen = mix(cloth, pel, pelmet);
	seen = mix(seen, brass, rod);
	lit_tint = mix(cloth * 1.4, pel * 1.4, pelmet);
	lit_tint = mix(lit_tint, brass * 1.2, rod);
	return vec4(seen, max(cover, max(pelmet, rod)));
}
"""

const GLASS_SHADER := """
shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 colour = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
varying flat vec2 key;
varying flat vec2 home;
varying flat float circle;
varying flat vec3 dye_v;
varying flat vec3 whims_v;
""" + LIT_FUNCTION + SHUT_FUNCTION + CLOTH_FUNCTION + """
void vertex() {
	key = UV2 + MODEL_MATRIX[3].xz;
	home = floor(MODEL_MATRIX[3].xz + 0.5);
	circle = floor((1.0 - COLOR.b) * 32.000000 + 0.5);
	dye_v = cloth_dye(home);
	whims_v = cloth_whims(home, key);
}
void fragment() {
	vec2 q = clamp(vec2(UV.x / 0.8, UV.y / 0.9), 0.0, 1.0);
	float wk = whims_v.y;
	vec3 lit_cloth;
	vec4 drawn = drape(UV, dye_v, whims_v, key, circle, lit_cloth);
	// The dim room between the curtains: a back wall, darker towards the top.
	vec3 room = vec3(0.17, 0.125, 0.09) * (0.55 + 0.7 * (1.0 - q.y)) * (0.8 + 0.4 * wk);
	vec3 seen = mix(room, drawn.rgb, drawn.a);
	// Glass: a faint blue tint and a slanting glint.
	float glint = smoothstep(0.07, 0.0, abs(q.x - q.y * 0.7 - 0.35)) * 0.05;
	ALBEDO = seen * vec3(0.78, 0.86, 0.95) * 0.7 + glint;
	ROUGHNESS = 0.08;
	SPECULAR = 0.55;
	// At night the room is lit: the open middle shines, the cloth in its own colour.
	vec3 lit_tint = mix(vec3(1.0), lit_cloth, drawn.a);
	lit_tint *= 0.65 + 0.35 * smoothstep(0.7, 0.0, abs(q.x - 0.5) + abs(q.y - 0.5) * 0.4);
	EMISSION = SHINE;
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
"""

## The curtains of a window one looks through (see VillageHouse._window): the same cloth as the
## glass's, cut out where the curtains are open, hung in the opening and drawn from both sides.
const CURTAIN_SHADER := """
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
uniform vec3 colour = vec3(1.0, 0.7, 0.36);
uniform float glow = 0.0;
varying flat vec2 key;
varying flat vec2 home;
varying flat float circle;
varying flat vec3 dye_v;
varying flat vec3 whims_v;
""" + LIT_FUNCTION + SHUT_FUNCTION + CLOTH_FUNCTION + """
void vertex() {
	key = UV2 + MODEL_MATRIX[3].xz;
	home = floor(MODEL_MATRIX[3].xz + 0.5);
	circle = floor((1.0 - COLOR.b) * 32.000000 + 0.5);
	dye_v = cloth_dye(home);
	whims_v = cloth_whims(home, key);
}
void fragment() {
	vec3 lit_cloth;
	vec4 drawn = drape(UV, dye_v, whims_v, key, circle, lit_cloth);
	if (drawn.a < 0.5) {
		discard;
	}
	ALBEDO = drawn.rgb * 0.8;
	ROUGHNESS = 1.0;
	EMISSION = gl_glow(colour * lit_cloth, glow * window_lit(key) * 0.5);
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
"""


## The shutters of a window: wooden leaves hinged at the window's sides. They lie open against the
## wall by day and swing shut over the window when the residents come home (at the same hour as the
## curtains, see SHUT_FUNCTION), and open again in the morning. The mesh carries each leaf's hinge
## (house frame, x and z) in UV2 and its way of swinging in COLOR.r (0 or 1); the leaf turns about
## its hinge in the vertex shader, so shadows follow it.
const SHUTTER_SHADER := """
shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
uniform sampler2D wood;
uniform vec3 tint = vec3(0.42, 0.30, 0.22);
uniform float glow = 0.0;
""" + LIT_FUNCTION + SHUT_FUNCTION + """
void vertex() {
	vec2 hinge = UV2;
	float shut = shutters_shut(hinge + MODEL_MATRIX[3].xz, floor((1.0 - COLOR.b) * 32.0 + 0.5));
	// Open (all day), the leaf stays where it is: no turning, for the main pass and the shadows alike.
	if (shut > 0.001) {
		float a = PI * shut * (COLOR.r * 2.0 - 1.0);
		float c = cos(a);
		float s = sin(a);
		vec3 pivot = vec3(hinge.x, VERTEX.y, hinge.y);
		vec3 rel = VERTEX - pivot;
		VERTEX = pivot + vec3(c * rel.x + s * rel.z, rel.y, -s * rel.x + c * rel.z);
		NORMAL = vec3(c * NORMAL.x + s * NORMAL.z, NORMAL.y, -s * NORMAL.x + c * NORMAL.z);
	}
}
void fragment() {
	ALBEDO = texture(wood, UV).rgb * tint;
	ROUGHNESS = 0.9;
	ALBEDO = gl_colour(ALBEDO);
}
"""


## Where a pane stands, as one number pair both the glass and its light pool
## carry, so that the two go out together.
static func key(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z + at.y * 3.1)


## The glass of the houses' windows; `light` is the glow colour.
## With `inside` the pane seen from within a room, which gives no light of its own.
static func glass_material(light: Color, inside := false) -> ShaderMaterial:
	var shine := "vec3(0.0)" if inside else "gl_glow(colour * lit_tint, glow * window_lit(key))"
	return _lit_material(GLASS_SHADER.replace("SHINE", shine), light)


## The shutters (see SHUTTER_SHADER); driven like the glass (see Outdoor.set_hour).
static func shutter_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	var mat := _lit_material(SHUTTER_SHADER, Color(1.0, 0.7, 0.36))
	mat.set_shader_parameter("wood", texture)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return mat


## The curtains inside the windows one looks through; driven like the glass (see Outdoor.set_hour).
static func curtain_material(light: Color) -> ShaderMaterial:
	return _lit_material(CURTAIN_SHADER, light)


static func _lit_material(code: String, light: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = code
	mat.shader = shader
	mat.set_shader_parameter("colour", Vector3(light.r, light.g, light.b))
	mat.set_shader_parameter("glow", 0.0)
	mat.set_shader_parameter("hour", 12.0)
	return mat
