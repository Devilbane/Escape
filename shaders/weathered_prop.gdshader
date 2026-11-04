shader_type spatial;
// Old, weathered props for the world outside (see WeatheredProps): the
// village's barrels, crates, sacks, lumber and stone heaps, pumpkins, tents,
// the forge, the workbenches and the food pedestal. Their colours come from a
// flat palette (the KayKit models), from vertex colours (the pieces built in
// code) or from one colour. They looked freshly painted and plastic next to
// the aged stone of the village and the graveyard; this weathers them the
// same way, by what each colour is:
// - wood (browns): bleached towards silver grey by sun and rain, with grain,
//   dark cracks along the boards and a green film low down,
// - iron (dark blue-grey, unless the grey is stone): darkened, with rust,
// - stone (grey, when the model is stone, see grey_stone): hewn and pitted,
//   warm grey like the village, with lichen and moss,
// - cloth (light, pale browns: sacks, canvas): faded, with water stains,
// - produce (pumpkins, bread, apples): their own colour, mottled and dull,
//   with earth at the foot,
// - anything else (paint): faded and stained.
// Over all of it: grime at the foot, rain streaks down the sides and moss on
// what faces up low down, as in aged_stone.gdshader. Fine detail fades out
// where it would be smaller than a few pixels, so it never flickers.

#include "res://shaders/detail.gdshaderinc"

// The colours are read and weathered as they were painted (sRGB); the
// result goes into linear light at the end.
uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_enable;
// Where the colour comes from: 0 the palette, 1 vertex colours, 2 base_colour.
uniform int source = 0;
uniform vec3 base_colour : source_color = vec3(0.5);
// What a grey means: 1 stone, 0 iron. With vertex colours, the vertex
// colour's alpha says it per piece instead (see WeatheredProps.Builder).
// With `produce`, strong colours are produce (or earth) everywhere.
uniform float grey_stone = 0.0;
// Strong colours are produce (fruit and vegetables), not paint.
uniform bool produce = false;
// The strength of the weather.
uniform float age = 1.0;

// The warm grey of the village stone (AgedStone.GRAVE_TINTS), and rust.
// All colours here are as painted (sRGB), like the palette.
const vec3 STONE = vec3(0.62, 0.61, 0.58);
// Old timber gone silver-grey in the weather (luminance about 0.53).
const vec3 SILVER = vec3(0.56, 0.53, 0.48);
const vec3 RUST = vec3(0.3, 0.15, 0.07);
const vec3 EARTH = vec3(0.24, 0.19, 0.13);

varying vec3 obj_pos;
varying vec3 wnrm;
varying float height;
varying float kind;

void vertex() {
	// The part's own shape at its real size, shifted by where it stands, so
	// the pattern differs from one barrel to the next.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	obj_pos = VERTEX * scale + NODE_POSITION_WORLD * 0.37;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - NODE_POSITION_WORLD.y;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// (Plain if/else: a ternary on the int uniform picked the wrong branch.)
	kind = grey_stone;
	if (produce) {
		kind = 0.5;
	} else if (source == 1) {
		kind = COLOR.a;
	}
}

void fragment() {
	vec3 p = obj_pos;
	vec3 n = normalize(wnrm);
	float px = length(fwidth(p));
	// The palette and base_colour arrive in linear light (source_color):
	// back to how they were painted. Vertex colours arrive as painted.
	vec3 c = pow(max(base_colour, vec3(0.0)), vec3(1.0 / 2.2));
	if (source == 0) {
		c = pow(max(texture(palette, UV).rgb, vec3(0.0)), vec3(1.0 / 2.2));
	} else if (source == 1) {
		c = COLOR.rgb;
	}
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	float hi = max(c.r, max(c.g, c.b));
	float sat = hi > 0.001 ? (hi - min(c.r, min(c.g, c.b))) / hi : 0.0;

	// What the colour is. kind: near 1 a grey is stone, near 0 it is iron,
	// in between strong colours are produce; a produce material (fruit,
	// bread, earth) takes every colour that is not grey as produce.
	float grey = 1.0 - smoothstep(0.14, 0.2, sat);
	float is_stone = grey * step(0.75, kind);
	float is_iron = grey * (1.0 - step(0.75, kind));
	float fresh = (1.0 - grey) * step(0.1, kind) * (1.0 - step(0.75, kind)) * smoothstep(0.45, 0.6, sat);
	if (produce) {
		fresh = 1.0 - grey;
	}
	float is_cloth = (1.0 - grey) * (1.0 - fresh) * smoothstep(0.58, 0.66, l) * (1.0 - smoothstep(0.5, 0.6, sat));
	float is_paint = (1.0 - grey) * (1.0 - fresh) * (1.0 - is_cloth) * smoothstep(0.66, 0.74, sat);
	float is_wood = max(0.0, 1.0 - is_stone - is_iron - fresh - is_cloth - is_paint);

	float cloud = fbm(p * 1.3);
	float stains = fbm(p * 2.2 + 4.0);
	float grit = fbm(p * 7.0) * band(7.0, px);
	float low = 1.0 - smoothstep(0.0, 0.8 + cloud * 0.5, height);
	float up = smoothstep(0.4, 0.9, n.y);
	float side = 1.0 - abs(n.y);

	// Wood: grain along the boards (upright on the sides, lying along z or x
	// on top), boards weathered unevenly, and thin dark cracks.
	vec3 gp = up > 0.5 ? vec3(p.x * 18.0, p.y * 2.0, p.z * 1.4) : vec3(p.x * 1.5 + p.y * 2.5, p.y * 18.0, p.z * 1.5);
	float grain = vnoise(gp) * band(18.0, px);
	float boards = vnoise(vec3(p.x * 0.7, p.y * 5.0, p.z * 0.7) + 31.0);
	float crack_n = vnoise(gp * vec3(0.5, 0.35, 0.5) + 13.0);
	float crack = (1.0 - smoothstep(0.0, 0.035, abs(crack_n - 0.5))) * smoothstep(0.45, 0.7, vnoise(p * 2.7 + 8.0)) * band(10.0, px);
	// Weathering greys the wood, but keeps it as light as it was painted.
	vec3 wood = mix(c, SILVER * (l / 0.53), 0.58 * age);
	wood *= 1.06 + 0.34 * (grain - 0.5) + 0.22 * (boards - 0.5);
	wood *= 1.0 - 0.5 * crack;

	// Iron: dark, with rust creeping over it in patches and specks.
	float specks = smoothstep(0.62, 0.8, vnoise(p * 30.0 + 9.0)) * band(30.0, px);
	float rust = max(smoothstep(0.5, 0.7, fbm(p * 4.0 + 3.0) + low * 0.2), specks * 0.6);
	vec3 iron = vec3(l) * vec3(0.9, 0.93, 0.97);
	iron = mix(iron, RUST * (0.75 + 0.5 * vnoise(p * 26.0)), rust * 0.65 * age);

	// Stone: hewn, warm grey, grained and pitted, crusted with lichen.
	float sgrain = fbm(p * 2.2 + 3.0);
	float pits = vnoise(p * 17.0) * band(17.0, px);
	vec3 stone = mix(STONE, c, 0.2) * (l / 0.55) * (0.74 + 0.2 * sgrain) * (0.94 + 0.12 * pits);
	vec3 lp = p * 5.0;
	float crust = smoothstep(0.62, 0.68, fbm(lp + 21.0)) * band(5.0, px);
	vec3 lichen_col = vnoise(lp * 0.6 + 9.0) > 0.62 ? vec3(0.62, 0.42, 0.16) : vec3(0.58, 0.6, 0.48);
	stone = mix(stone, lichen_col * (0.85 + 0.3 * grit), crust * 0.4 * age);

	// Cloth: faded, with water stains running down it.
	float damp = smoothstep(0.45, 0.75, stains);
	vec3 cloth = mix(c, vec3(l) * vec3(1.0, 0.95, 0.86), 0.35 * age) * (1.0 - age * (0.1 + 0.22 * damp));

	// Produce: its own colour, a little duller, mottled and speckled.
	float mottle = fbm(p * 5.0 + 17.0);
	vec3 fruit = mix(c, vec3(l), 0.25 * age) * (0.84 + 0.26 * mottle);
	fruit *= 1.0 - 0.25 * smoothstep(0.7, 0.85, vnoise(p * 24.0)) * band(24.0, px);

	// Paint: faded and stained.
	vec3 paint = mix(c, vec3(l), 0.4 * age) * (1.0 - 0.2 * damp * age);

	vec3 col = wood * is_wood + iron * is_iron + stone * is_stone + cloth * is_cloth + fruit * fresh + paint * is_paint;

	// Weather over all of it.
	col *= mix(1.0, 0.92 + 0.16 * cloud, age);
	col *= 1.0 + 0.12 * (grit - 0.5) * age;
	// Grime and earth splashed up at the foot.
	col = mix(col, col * EARTH / 0.3, low * 0.25 * age);
	// Rain streaks running down the sides.
	float streak = vnoise(vec3(p.x * 2.4 + p.z * 1.7, p.y * 0.2, 1.7)) * vnoise(vec3(p.x * 5.1 - p.z * 3.3, p.y * 0.45, 4.2));
	streak = smoothstep(0.3, 0.58, streak) * side * band(5.0, px) * (1.0 - fresh);
	col *= 1.0 - streak * 0.18 * age;
	// Moss and a green film on wood and stone that face up or stand low.
	float moss_place = max(low * 0.7, up * 0.6) * (is_wood + is_stone);
	float moss = smoothstep(0.66, 0.84, fbm(p * 2.4 + 5.0) + moss_place * 0.3) * smoothstep(0.05, 0.4, moss_place);
	vec3 moss_col = mix(vec3(0.25, 0.31, 0.14), vec3(0.36, 0.41, 0.2), vnoise(p * 4.0));
	col = mix(col, moss_col, moss * 0.45 * age);

	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2));

	// Everything outside is matt; bare iron keeps a little sheen, fruit skin
	// a soft one.
	float sheen = is_iron * (1.0 - rust);
	ROUGHNESS = mix(0.94, 0.6, sheen) - 0.2 * fresh;
	SPECULAR = mix(0.25, 0.45, sheen + fresh * 0.5);
	float h = grit * 0.012 - crack * 0.006 * is_wood + pits * 0.006 * is_stone + rust * 0.003 * is_iron + crust * 0.004;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h) * age, dFdy(h) * age);
}
