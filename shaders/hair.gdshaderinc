// Hair for characters built on the Rogue model (see HairLook): the head with
// its natural hair or shaved (with a dark stubble and maybe a tattoo), and a
// mohawk crest of hair locks.
//
// Each lock is a ribbon (UV.x across it, UV.y from root to tip) that is cut
// into single round strands, each ending at its own length and thinning
// towards its tip. The normal is tilted across every strand, so the shine
// runs along the hair in streaks instead of lying on it like on plastic.
// Strands thinner than about a pixel melt into a solid lock, so they never
// flicker.
//
// The head's own hair is one smooth shape; it is combed into strands here:
// they grow from a crown at the back of the head, part on the left, and lie
// in locks of a few strands each, in layers whose ends shade the lock below.
// The same strands, finer and without layers, make a short crop.
//
// Colours: root, middle and tip colour, or (mode) a rainbow running along
// the crest, or flickering flames that glow in the dark.
//
// Define FADE before including this to get a version that turns grey and can
// fade out, for a sneaking hero.

uniform sampler2D tex : source_color, filter_linear_mipmap;
// true for the crest of locks, false for the head.
uniform bool crest = false;
// Head: the hair is shaved off (the mesh is too; this switches the look).
uniform bool shaved = false;
// The hair knot of a woman: the strands are wound round it (COLOR is the
// point on a unit ball, z outwards).
uniform bool bun = false;
// Head: the hair is cut short (the mesh is too; this makes the strands finer).
uniform bool short_hair = false;
// Head with natural hair: dye it (false keeps the texture's own colour).
uniform bool recolor = false;
// 0: the colours below, 1: rainbow, 2: fire.
uniform int mode = 0;
uniform vec3 root_color : source_color = vec3(0.32, 0.14, 0.09);
uniform vec3 hair_color : source_color = vec3(0.62, 0.33, 0.22);
uniform vec3 tip_color : source_color = vec3(0.84, 0.52, 0.34);
// Head: the skin is multiplied by this (white keeps the texture's own), so
// one character can have a rosier or a darker face than the model's.
uniform vec3 skin_tint : source_color = vec3(1.0);
// Strands across one lock.
uniform float strands = 6.0;
// The crest is made of solid tufts (spiky hair): cones, UV.x round each one,
// that are grooved into strands but never cut open.
uniform bool tufts = false;
// The tattoo: a word in white on a clear background, laid onto the right
// side of a shaved head.
uniform sampler2D tattoo : filter_linear;
uniform bool show_tattoo = false;
#ifdef FADE
uniform float fade = 0.0;
#endif

// Where the tattoo sits on the head (head mesh space): the word runs from
// the back to the front above the right ear, straight or in an arch.
// It covers most of the shaved side, so the word reads from afar; the
// patch keeps the ink texture's shape (HairLook.INK_SIZE).
const float TATTOO_BACK = -0.42;
const float TATTOO_FRONT = 0.26;
const float TATTOO_TOP = 2.07;
const float TATTOO_BOTTOM = 1.552;
const vec3 INK = vec3(0.02, 0.03, 0.07);
// How bright the natural hair is in the texture, to dye it evenly.
const float NATURAL_LIGHT = 0.16;
// The combed hair, in the skull's space (see HairLook.SKULL_CENTER and
// SKULL_RADII): the crown the strands grow from, the parting running from it
// to the forehead, and how many strands and locks go once round the crown.
const vec3 SKULL_CENTER = vec3(0.0, 1.64, -0.06);
const vec3 SKULL_RADII = vec3(0.425, 0.53, 0.45);
const vec3 CROWN = vec3(0.1, 0.7, -0.72);
const vec3 PARTING = vec3(0.3, 0.45, 0.84);
const float STRANDS_ROUND = 110.0;
const float LOCKS_ROUND = 26.0;

// Head: xyz the position (for stubble and tattoo), w = 1 on the hair.
varying vec4 rest;

#include "res://shaders/detail.gdshaderinc"

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	// From screen colours to the light the renderer works in.
	return pow(mix(vec3(1.0), k, 0.85), vec3(2.2));
}

// The colour of the hair at `along` (0 root, 1 tip) and `pos` (where along
// the crest or around the head); flick is the flame noise for fire, which
// also makes it glow.
vec3 hair_tone(float along, float pos, float flick, float time, out float glow) {
	glow = 0.0;
	if (mode == 1) {
		vec3 c = hue(pos * 0.9 + time * 0.04);
		c = mix(c, vec3(1.0), 0.2 * smoothstep(0.5, 1.0, along));
		return c * mix(0.35, 1.0, smoothstep(0.0, 0.3, along));
	}
	if (mode == 2) {
		// Dark red at the root, then orange, yellow and almost white at the tips.
		float heat = clamp(along + 0.35 * (flick - 0.5), 0.0, 1.0);
		vec3 c = mix(vec3(0.25, 0.01, 0.0), vec3(1.0, 0.18, 0.0), smoothstep(0.0, 0.4, heat));
		c = mix(c, vec3(1.0, 0.62, 0.08), smoothstep(0.35, 0.75, heat));
		c = mix(c, vec3(1.0, 0.92, 0.55), smoothstep(0.75, 1.0, heat));
		glow = 0.4 + 1.6 * heat * flick;
		return c;
	}
	vec3 c = mix(hair_color, tip_color, smoothstep(0.35, 1.0, along));
	return mix(root_color, c, smoothstep(0.0, 0.3, along));
}

// The combed look of the head's hair at p (head mesh space): how light it is
// (around 1), and a height for the bump of round strands.
float combed(vec3 p, out float height) {
	vec3 u = normalize((p - SKULL_CENTER) / SKULL_RADII);
	vec3 w = normalize(CROWN);
	vec3 a = normalize(PARTING - w * dot(PARTING, w));
	vec3 b = cross(w, a);
	// Away from the crown (0 there, about 2.5 at the chin), and round it
	// (0 along the parting).
	float away = acos(clamp(dot(u, w), -1.0, 1.0));
	float round = atan(dot(u, b), dot(u, a)) / TAU;
	// Combed away from the parting on both sides, more the further out.
	float side = sign(round + 1e-4);
	float part = smoothstep(0.0, 0.012, abs(round));
	float bend = side * 0.05 * smoothstep(0.1, 1.3, away);
	float s = (round + bend) * STRANDS_ROUND * (short_hair ? 1.6 : 1.0);
	float l = (round + bend * 1.2) * LOCKS_ROUND + 0.6 * sin(away * 3.0 + round * 9.0);
	float lock_id = floor(l);
	float r = hash1(lock_id * 7.13 + 1.7);
	float px = max(fwidth(s), 1e-4);
	// Fine detail fades out where it would flicker, and round the crown,
	// where all the strands meet.
	float whorl = smoothstep(0.08, 0.35, away);
	float fine = (1.0 - smoothstep(0.15, 0.4, px)) * whorl;
	float coarse = (1.0 - smoothstep(0.15, 0.45, fwidth(l))) * whorl;
	// Single strands: round, each a little lighter or darker.
	float f = fract(s) * 2.0 - 1.0;
	float curve = sqrt(max(0.0, 1.0 - f * f));
	float strand = mix(1.0, 0.86 + 0.14 * curve, fine) * mix(1.0, 0.94 + 0.12 * hash1(floor(s)), fine);
	// Locks: a darker gap between two, each its own shade.
	float edge = abs(fract(l) * 2.0 - 1.0);
	float lock_shade = mix(1.0, (1.0 - 0.28 * edge * edge - 0.12 * smoothstep(0.8, 1.0, edge)) * (0.9 + 0.24 * r), coarse);
	// Layers: lower down, the end of a lock above shades the one below it.
	float layer = fract(away * 1.6 + r * 0.9 + 0.15 * sin(round * 40.0));
	float layered = short_hair ? 1.0 : mix(1.0, 0.86 + 0.14 * smoothstep(0.0, 0.2, layer), coarse * smoothstep(0.7, 1.1, away));
	// The parting shows a thin line of darker roots, up to the forehead.
	float parting = mix(1.0, mix(0.55, 1.0, part), 1.0 - smoothstep(0.75, 0.95, away));
	height = (curve * fine * 0.0025 + (1.0 - edge * edge) * coarse * 0.006) * part;
	return strand * lock_shade * layered * parting;
}

// The wound strands of the hair knot at q (a point on a unit ball, z out of
// the head): they run round its axis and spiral out to the middle.
float wound(vec3 q, out float height) {
	float round = atan(q.y, q.x) / TAU + 0.35 * (1.0 - q.z);
	float s = round * 70.0;
	float l = round * 9.0;
	float r = hash1(floor(l) * 7.13 + 3.1);
	float fine = 1.0 - smoothstep(0.15, 0.4, fwidth(s));
	float coarse = 1.0 - smoothstep(0.15, 0.45, fwidth(l));
	float f = fract(s) * 2.0 - 1.0;
	float curve = sqrt(max(0.0, 1.0 - f * f));
	float edge = abs(fract(l) * 2.0 - 1.0);
	height = curve * fine * 0.0025 + (1.0 - edge * edge) * coarse * 0.008;
	// The middle, where the ends are tucked in, lies in shadow.
	float tucked = mix(0.75, 1.0, smoothstep(0.75, 0.95, 1.0 - q.z) + smoothstep(0.85, 0.6, q.z));
	return mix(1.0, 0.86 + 0.14 * curve, fine) * mix(1.0, (1.0 - 0.3 * edge * edge) * (0.9 + 0.2 * r), coarse) * tucked;
}

void vertex() {
	rest = CUSTOM0;
}

void fragment() {
	vec3 albedo;
	vec3 emission = vec3(0.0);
	float roughness;
	float specular;
	bool cut = false;
	if (crest) {
		float along = UV.y;
		float s = UV.x * strands + COLOR.r * 17.0;
		float r = hash1(floor(s) + COLOR.r * 131.0);
		float f = fract(s) * 2.0 - 1.0; // -1 .. 1 across one strand
		float blur = smoothstep(0.35, 0.9, fwidth(s));
		// Flames licking up the strands.
		float flick = mode == 2 ? vnoise(vec3(UV.x * 2.0 + COLOR.r * 20.0, along * 4.0 - TIME * 3.0, COLOR.r * 5.0)) : 0.5;
		// Each strand ends at its own length and thins towards its tip.
		float ends = (0.62 + 0.38 * r) * (mode == 2 ? 0.7 + 0.45 * flick : 1.0);
		float thick = mix(1.0, 0.3, smoothstep(0.15, 1.0, along / ends));
		float strand = 1.0 - smoothstep(thick - 0.2, thick, abs(f));
		// Near the root a lock is solid; further out the gaps open up.
		float cover = max(mix(strand, 1.0, blur), 1.0 - smoothstep(0.15, 0.3, along));
		cut = !tufts && (along > ends || cover < 0.5);

		float glow;
		vec3 c = hair_tone(along, COLOR.b, flick, TIME, glow);
		float vary = mix(1.0, 0.78 + 0.44 * r, 1.0 - blur) * (0.85 + 0.3 * COLOR.g);
		// Darker where a strand curves away, between the strands.
		float curve = sqrt(max(0.0, 1.0 - f * f));
		vary *= mix(1.0, 0.7 + 0.3 * curve, 1.0 - blur);
		if (tufts) {
			// A tuft is a clump: soft grooves instead of loose strands, the
			// roots in its own shadow, the shading even all round it.
			vary = mix(1.0, 0.93 + 0.07 * curve, 1.0 - blur) * (0.9 + 0.2 * COLOR.g);
			vary *= mix(0.62, 1.0, smoothstep(0.0, 0.45, along));
		}
		albedo = c * vary;
		emission = c * glow * vary;
		// Round strands: tilt the normal across each one.
		float h = tufts ? 0.0 : curve * (1.0 - blur) * 0.004;
		NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
		roughness = 0.45;
		specular = 0.4;
	} else {
		// Face and scalp are matt, so they do not shine like plastic in the
		// lantern light; a shaved scalp shines a little.
		vec3 c = texture(tex, UV).rgb;
		float hair = smoothstep(0.3, 0.7, rest.w);
		vec3 p = rest.xyz;
		albedo = c;
		roughness = 0.95;
		specular = 0.12;
		if (shaved) {
			float px = length(fwidth(p));
			// The dark stubble of short hairs, thinning out at the nape.
			float grow = smoothstep(1.35, 1.55, p.y);
			float dots = smoothstep(0.55, 0.85, vnoise(p * 300.0)) * band(300.0, px);
			float shade = 0.14 + 0.08 * (fbm(p * 9.0) - 0.5);
			albedo = mix(c, root_color, hair * grow * (shade + 0.3 * dots));
			roughness = mix(0.95, 0.6, hair);
			specular = mix(0.12, 0.25, hair);
			if (show_tattoo) {
				vec2 t = vec2((p.z - TATTOO_BACK) / (TATTOO_FRONT - TATTOO_BACK), (TATTOO_TOP - p.y) / (TATTOO_TOP - TATTOO_BOTTOM));
				float inside = step(0.0, t.x) * step(t.x, 1.0) * step(0.0, t.y) * step(t.y, 1.0);
				float side = smoothstep(-0.18, -0.3, p.x);
				float ink = texture(tattoo, clamp(t, 0.0, 1.0)).a * inside * side * hair;
				albedo = mix(albedo, INK, ink * 0.88);
			}
		} else {
			// Combed into strands, locks and layers, with a little shine.
			float h;
			float comb = bun ? wound(COLOR.rgb * 2.0 - 1.0, h) : combed(p, h);
			NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h * hair), dFdy(h * hair));
			c *= mix(1.0, comb, hair);
			albedo = c;
			roughness = mix(0.95, 0.6, hair);
			specular = mix(0.12, 0.3, hair);
		}
		if (!shaved && (recolor || mode != 0)) {
			// Dyed natural hair: the texture's light and dark in the new colour.
			float light = clamp(dot(c, vec3(0.3, 0.59, 0.11)) / NATURAL_LIGHT, 0.4, 1.6);
			float along = clamp((2.2 - p.y) / 1.0, 0.0, 1.0);
			float around = atan(p.x, p.z) / TAU + 0.5;
			float flick = mode == 2 ? vnoise(vec3(p.x * 6.0, p.y * 5.0 + TIME * 2.5, p.z * 6.0)) : 0.5;
			float glow;
			vec3 dyed = hair_tone(along, around, flick, TIME, glow) * light;
			if (short_hair && mode == 0) {
				// A short crop is the hair's dense base: the roots' shade
				// a third of the way to the middle colour, never pale like skin.
				dyed = mix(root_color, hair_color, 0.35) * clamp(light, 0.75, 1.1);
			}
			albedo = mix(c, dyed, hair);
			emission = dyed * glow * hair * 0.5;
		}
		// The skin: the face, the ears and a shaved scalp.
		albedo *= mix(skin_tint, vec3(1.0), shaved ? 0.0 : hair);
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = roughness;
	SPECULAR = specular;
#ifdef FADE
	// Sneaking: ash grey and see-through, the same as ghost.gdshader.
	ALBEDO = vec3(0.22 + dot(albedo, vec3(0.3, 0.59, 0.11)) * 0.7) * vec3(0.93, 0.96, 1.0);
	EMISSION = vec3(0.0);
	SPECULAR = 0.2;
	ALPHA = 1.0 - fade;
#endif
	if (cut) {
		discard;
	}
}
