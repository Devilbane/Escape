shader_type spatial;
// Old, worn wood and metal for the dungeon's chests, trunks, barrels, crates,
// tables, beds and doors (see WornLook). The models' textures are clean and
// even, which looks freshly made next to the dusty floor. This keeps their
// colour and adds:
// - grime: dark, cloudy stains, thickest near the floor,
// - dust: a grey-brown layer on the surfaces that face up, like the floor's,
// - scratches: thin, light streaks where the wood or metal shows through,
// - dents and chipped spots,
// - rust on iron fittings and a dull tarnish on brass and gold ones (metal is
//   read from the texture: grey is iron, yellow is brass or gold).
// Cloth (wall flags and banners) instead fades, gets water stains and a few
// moth holes.
// The pattern is laid out from each part's own origin, so it stays on a lid
// that opens and differs from one barrel to the next. Fine detail fades out
// where it would be smaller than a few pixels, so it never flickers.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = false;
uniform vec3 albedo_color : source_color = vec3(1.0);
// 0 keeps the clean look, 1 is a long-forgotten dungeon prop.
uniform float strength = 1.0;
// The texture is flat cartoon colour (the KayKit pieces): give it wood grain,
// fade its bright paint further, and take its bluish grey for iron as well.
uniform bool flat_texture = false;
// The whole part is cloth: faded and stained, never rusty or scratched.
uniform bool cloth = false;

const vec3 DUST = vec3(0.6, 0.56, 0.5);
const vec3 RUST = vec3(0.25, 0.13, 0.07);

varying vec3 obj_pos;
varying vec3 up_normal;
varying float height;

void vertex() {
	// The part's own shape at its real size, shifted by where it stands.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	obj_pos = VERTEX * scale + NODE_POSITION_WORLD * 0.37;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height = world.y - NODE_POSITION_WORLD.y;
	up_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = obj_pos;
	float px = length(fwidth(p));
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	// Grey and not too dark: iron. Yellow (green close to red): brass or gold.
	float grey = flat_texture ? 1.0 - smoothstep(0.1, 0.18, sat) : 1.0 - smoothstep(0.035, 0.08, sat);
	float iron = grey * smoothstep(0.16, 0.32, lum);
	float brass = smoothstep(0.62, 0.78, c.g / max(c.r, 0.01)) * smoothstep(0.35, 0.55, c.r) * smoothstep(0.15, 0.3, c.r - c.b);
	if (cloth) {
		iron = 0.0;
		brass = 0.0;
	}
	float wood = 1.0 - max(iron, brass);

	float stains = fbm(p * 2.2);
	float grit = fbm(p * 7.0);
	// Low parts collect the most dirt (splashes, mud, the damp of the floor).
	float low = 1.0 - smoothstep(0.0, 0.9, height);
	float grime = smoothstep(0.3, 0.8, stains) * 0.6 + low * 0.35;

	// Scratches: thin streaks running at a slant, only in some places.
	vec3 q = vec3(p.x * 0.8 + p.z * 0.6, p.y, p.z * 0.8 - p.x * 0.6);
	float streak = vnoise(q * vec3(3.0, 38.0, 3.0) + vec3(0.0, p.x * 9.0, 0.0));
	float scratch = (1.0 - smoothstep(0.0, 0.05, abs(streak - 0.5)))
		* smoothstep(0.5, 0.72, vnoise(p * 3.3 + 17.0)) * band(38.0, px);
	// Dents and chipped spots: small, and only here and there.
	float chips = smoothstep(0.74, 0.86, vnoise(p * 18.0 + 5.0)) * smoothstep(0.45, 0.65, stains) * band(18.0, px);

	if (cloth) {
		// Moth holes: a few small, ragged ones (only when near enough to see).
		float moth = vnoise(p * 5.0 + 23.0) + 0.25 * vnoise(p * 19.0);
		if (moth * band(5.0, px) * strength > 1.0) {
			discard;
		}
		// Faded by the years and stained by the damp walls.
		vec3 faded = mix(c, vec3(lum) * vec3(1.02, 0.98, 0.9), 0.45 * strength);
		faded = mix(faded, DUST * 0.8, 0.18 * strength);
		float damp = smoothstep(0.45, 0.75, stains);
		faded *= 1.0 - strength * (0.1 + 0.3 * damp + 0.12 * (grit - 0.5));
		ALBEDO = faded;
		NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(grit * 0.004), dFdy(grit * 0.004));
		if (use_normal_map) {
			NORMAL_MAP = texture(normal_tex, UV).rgb;
		}
		ROUGHNESS = 1.0;
		SPECULAR = 0.1;
	} else {
		vec3 col = c;
		// Aged: a little greyer and darker overall, darker still where grimy.
		col = mix(col, vec3(lum), (flat_texture ? 0.35 : 0.18) * strength);
		if (flat_texture) {
			// Grain along the boards, and boards that weathered unevenly.
			float grain = vnoise(vec3(p.x * 1.5 + p.y * 3.0, p.y * 20.0, p.z * 1.5)) * band(20.0, px);
			float boards = vnoise(vec3(p.x * 0.7, p.y * 6.0, p.z * 0.7) + 31.0);
			col *= 1.0 + strength * wood * (0.4 * (grain - 0.5) + 0.3 * (boards - 0.5) - 0.12 * grime);
		}
		col *= 1.0 - strength * (0.12 + 0.32 * grime + 0.1 * (grit - 0.5));
		// Rust creeps over iron in patches, most of all near the floor, and
		// speckles the rest.
		float specks = smoothstep(0.62, 0.8, vnoise(p * 30.0 + 9.0)) * band(30.0, px);
		float rust = iron * max(smoothstep(0.52, 0.72, fbm(p * 4.0 + 3.0) + low * 0.15), specks * 0.5);
		vec3 rust_col = RUST * (0.8 + 0.5 * vnoise(p * 26.0));
		col = mix(col, rust_col, rust * 0.75 * strength);
		// Brass and gold go dull and brown.
		float tarnish = brass * (0.45 + 0.45 * smoothstep(0.35, 0.65, stains));
		col = mix(col, col * vec3(0.62, 0.55, 0.4), tarnish * strength);
		// Chips show darker, scratches show the bare, lighter wood or metal.
		col *= 1.0 - 0.22 * chips * strength;
		vec3 bare = c * (wood > 0.5 ? vec3(1.45, 1.35, 1.2) : vec3(1.25)) + 0.04;
		col = mix(col, bare, scratch * 0.7 * strength * (1.0 - rust * 0.7));
		// Dust settles on everything that faces up.
		float up = smoothstep(0.35, 0.85, up_normal.y);
		float dust = up * smoothstep(0.3, 0.7, fbm(p * 1.6 + 11.0) + 0.15) * 0.6;
		col = mix(col, DUST * (0.9 + 0.2 * grit), dust * strength);
		ALBEDO = col;

		float h = strength * (-chips * 0.004 - scratch * 0.0012 + grit * 0.01 * band(7.0, px) + rust * 0.002);
		NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
		if (use_normal_map) {
			NORMAL_MAP = texture(normal_tex, UV).rgb;
		}
		// Bare metal keeps a little shine; rust, dust and old wood are matt.
		float metal = max(iron, brass) * (1.0 - rust) * (1.0 - dust);
		ROUGHNESS = mix(0.93, 0.55 + 0.3 * grime, metal);
		SPECULAR = mix(0.2, 0.45, metal);
	}
}
