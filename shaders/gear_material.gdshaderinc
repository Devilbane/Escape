// The look of a worn piece of gear (see GearLook). The models only have flat
// colour gradients and a uniform shine, which makes them look like plastic.
// This adds a faint hint of what each piece is made of: a little colour
// variation, a fine grain that catches the light, and a shine that suits the
// material (cloth is matt, leather has a soft sheen, metal is hammered).
//
// The grain is computed from each vertex's rest position (CUSTOM0, filled in
// by GearLook), so it stays on the surface while a part bends. Fine grain is
// faded out where it would be smaller than a few pixels, so it never flickers.
//
// Define FADE before including this to get a version that can fade out, for a
// sneaking hero.

const int NONE = 0;
const int CLOTH = 1;
const int LEATHER = 2;
const int METAL = 3;
const int CHAIN = 4;
const int FUR = 5;
const int BONE = 6;
const int WOOD = 7;
// The hero's own outfit: cloth, leather or skin, read from the texture's colour.
const int AUTO = 8;

uniform sampler2D tex : source_color, filter_linear_mipmap;
// recolor: keep the light and dark of the texture but swap its colour for the tint.
uniform bool recolor = true;
uniform vec3 tint : source_color = vec3(1.0);
uniform float metal = 0.0;
// What the piece is made of (one of the constants above). NONE keeps the plain look.
uniform int stuff = 0;
// Greyish, bright parts of the texture are metal (blades, buckles, shield rims).
uniform bool metal_where_grey = false;
uniform float grey_metal = 0.3;
#ifdef FADE
uniform float fade = 0.0;
#endif

varying vec3 rest_pos;

#include "res://shaders/detail.gdshaderinc"

// The grain of one material at rest position p:
// x = height in model units (for the bump), y = brightness factor, z = roughness.
// shine is how metallic a metal piece is: shinier metal is smoother.
vec3 grain(int kind, vec3 p, float px, float shine) {
	float h = 0.0;
	float shade = 1.0;
	float rough = 0.85;
	if (kind == CLOTH) {
		// A plain weave of threads, and some uneven dye.
		float c = 30.0;
		float weave = sin(TAU * c * p.y) * sin(TAU * c * (p.x + p.z) * 0.7071);
		float b = band(c, px);
		h = weave * b * 0.0012 + (vnoise(p * 90.0) - 0.5) * band(90.0, px) * 0.0004;
		shade = 1.0 + 0.14 * (fbm(p * 5.0) - 0.5) + 0.05 * weave * b;
		rough = 0.95;
	} else if (kind == LEATHER) {
		// Pebbled grain, a few creases, and spots worn smooth.
		float c = 40.0;
		float pebble = smoothstep(0.25, 0.75, vnoise(p * c)) * band(c, px);
		float crease = 1.0 - smoothstep(0.0, 0.06, abs(vnoise(p * 7.0) - 0.5));
		float worn = fbm(p * 4.0);
		h = pebble * 0.0012 - crease * band(7.0, px) * 0.002;
		shade = 1.0 + 0.16 * (worn - 0.5) - 0.07 * crease + 0.04 * (pebble - 0.5);
		rough = 0.72 - 0.16 * worn;
	} else if (kind == METAL) {
		// Hammered dents, fine brushing, and duller patches.
		float dents = vnoise(p * 12.0);
		float brush = vnoise(vec3(p.x * 5.0, p.y * 90.0, p.z * 5.0)) * band(90.0, px);
		float patina = fbm(p * 3.5);
		h = dents * band(12.0, px) * 0.006 + brush * 0.0003;
		shade = 1.0 + 0.10 * (patina - 0.5) + 0.04 * (brush - 0.5);
		rough = 1.0 - shine * 0.6 + 0.2 * (patina - 0.5);
	} else if (kind == CHAIN) {
		// Rows of small rings, each row shifted by half a ring.
		float c = 24.0;
		vec2 q = vec2((p.x + p.z) * 0.7071 * c, p.y * c);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		float ring = 1.0 - clamp(abs(length(fract(q) - 0.5) - 0.3) / 0.16, 0.0, 1.0);
		float b = band(c, px);
		h = ring * b * 0.0015;
		shade = 1.0 + 0.06 * (fbm(p * 4.0) - 0.5) - 0.18 * (1.0 - ring) * b;
		rough = 1.0 - shine * 0.6;
	} else if (kind == FUR) {
		// Strands running down, gathered into soft tufts.
		float strands = vnoise(p * vec3(70.0, 16.0, 70.0));
		float tufts = fbm(p * 7.0);
		float b = band(70.0, px);
		h = (strands - 0.5) * b * 0.0012 + tufts * band(7.0, px) * 0.003;
		shade = 1.0 + 0.16 * (tufts - 0.5) + 0.12 * (strands - 0.5) * b;
		rough = 1.0;
	} else if (kind == BONE) {
		// Mottled and slightly porous.
		float mottle = fbm(p * 6.0);
		h = (vnoise(p * 60.0) - 0.5) * band(60.0, px) * 0.0004 + mottle * 0.0015;
		shade = 1.0 + 0.10 * (mottle - 0.5);
		rough = 0.75;
	} else if (kind == WOOD) {
		// Grain running along the length (up the handle, across a board).
		float rings = sin(TAU * 14.0 * (p.x + p.z) + fbm(p * vec3(3.0, 0.7, 3.0)) * 9.0);
		float b = band(14.0, px);
		h = rings * b * 0.0008;
		shade = 1.0 + 0.07 * rings * b + 0.06 * (fbm(p * 4.0) - 0.5);
		rough = 0.82;
	}
	return vec3(h, shade, rough);
}

void vertex() {
	rest_pos = CUSTOM0.xyz;
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	vec3 albedo = c;
	if (recolor) {
		float light = dot(c, vec3(0.3, 0.59, 0.11));
		albedo = tint * (0.45 + light * 1.4);
	}
	float metallic = metal;
	float roughness = 1.0 - metal * 0.6;
	float specular = 0.5;
	if (stuff != NONE) {
		float px = length(fwidth(rest_pos));
		// Read what a texel shows from its colour (roughly as it looks on screen).
		vec3 s = sqrt(c);
		float hi = max(s.r, max(s.g, s.b));
		float lo = min(s.r, min(s.g, s.b));
		float sat = hi > 0.0 ? (hi - lo) / hi : 0.0;
		vec3 g;
		if (stuff == AUTO) {
			// The hero's own clothes: warm browns are leather, light warm
			// tones are skin (left plain), everything else is cloth.
			float warm = smoothstep(0.05, 0.15, s.r - max(s.g, s.b) * 0.9);
			float skin = warm * smoothstep(0.82, 0.9, hi);
			g = mix(grain(CLOTH, rest_pos, px, metal), grain(LEATHER, rest_pos, px, metal), warm);
			g = mix(g, vec3(0.0, 1.0, 0.6), skin);
			specular = mix(0.25, 0.5, max(warm * 0.6, skin));
		} else {
			g = grain(stuff, rest_pos, px, metal);
			specular = (stuff == CLOTH || stuff == FUR) ? 0.25 : 0.4;
		}
		if (metal_where_grey) {
			// Grey and not too dark means metal: blades, buckles, shield rims.
			float w = (1.0 - smoothstep(0.12, 0.25, sat)) * smoothstep(0.35, 0.5, hi);
			g = mix(g, grain(METAL, rest_pos, px, grey_metal), w);
			metallic = mix(metal, grey_metal, w);
			specular = mix(specular, 0.5, w);
		}
		albedo *= g.y;
		roughness = clamp(g.z, 0.25, 1.0);
		NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(g.x), dFdy(g.x));
	}
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
#ifdef FADE
	ALPHA = 1.0 - fade;
#endif
}
