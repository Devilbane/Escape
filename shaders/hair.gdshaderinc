// The hero's hair (see HairLook): a shaved scalp with a dark stubble, and a
// mohawk crest of hair locks.
//
// Each lock is a ribbon (UV.x across it, UV.y from root to tip) that is cut
// into single round strands, each ending at its own length and thinning
// towards its tip. The normal is tilted across every strand, so the shine
// runs along the hair in streaks instead of lying on it like on plastic.
// Strands thinner than about a pixel melt into a solid lock, so they never
// flicker.
//
// Define FADE before including this to get a version that can fade out, for
// a sneaking hero.

uniform sampler2D tex : source_color, filter_linear_mipmap;
// true for the crest of locks, false for the head (face and shaved scalp).
uniform bool crest = false;
uniform vec3 root_color : source_color = vec3(0.32, 0.14, 0.09);
uniform vec3 hair_color : source_color = vec3(0.62, 0.33, 0.22);
uniform vec3 tip_color : source_color = vec3(0.84, 0.52, 0.34);
// Strands across one lock.
uniform float strands = 6.0;
#ifdef FADE
uniform float fade = 0.0;
#endif

// Head: xyz the position (for the stubble), w = 1 on the shaved scalp.
varying vec4 rest;

#include "res://shaders/detail.gdshaderinc"

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	rest = CUSTOM0;
}

void fragment() {
	vec3 albedo;
	float roughness;
	float specular;
	bool cut = false;
	if (crest) {
		float along = UV.y;
		float s = UV.x * strands + COLOR.r * 17.0;
		float r = hash1(floor(s) + COLOR.r * 131.0);
		float f = fract(s) * 2.0 - 1.0; // -1 .. 1 across one strand
		float blur = smoothstep(0.35, 0.9, fwidth(s));
		// Each strand ends at its own length and thins towards its tip.
		float ends = 0.62 + 0.38 * r;
		float thick = mix(1.0, 0.3, smoothstep(0.15, 1.0, along / ends));
		float strand = 1.0 - smoothstep(thick - 0.2, thick, abs(f));
		// Near the root a lock is solid; further out the gaps open up.
		float cover = max(mix(strand, 1.0, blur), 1.0 - smoothstep(0.15, 0.3, along));
		cut = along > ends || cover < 0.5;

		vec3 c = mix(hair_color, tip_color, smoothstep(0.35, 1.0, along));
		c = mix(root_color, c, smoothstep(0.0, 0.3, along));
		c *= mix(1.0, 0.78 + 0.44 * r, 1.0 - blur) * (0.85 + 0.3 * COLOR.g);
		// Darker where a strand curves away, between the strands.
		c *= mix(1.0, 0.7 + 0.3 * sqrt(max(0.0, 1.0 - f * f)), 1.0 - blur);
		albedo = c;
		// Round strands: tilt the normal across each one.
		float h = sqrt(max(0.0, 1.0 - f * f)) * (1.0 - blur) * 0.004;
		NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
		roughness = 0.45;
		specular = 0.4;
	} else {
		// Face and scalp are matt, so they do not shine like plastic in the
		// lantern light; a shaved scalp shines a little.
		vec3 c = texture(tex, UV).rgb;
		float scalp = smoothstep(0.3, 0.7, rest.w);
		vec3 p = rest.xyz;
		float px = length(fwidth(p));
		// The dark stubble of short hairs, thinning out at the nape.
		float grow = smoothstep(1.35, 1.55, p.y);
		float dots = smoothstep(0.55, 0.85, vnoise(p * 300.0)) * band(300.0, px);
		float shade = 0.14 + 0.08 * (fbm(p * 9.0) - 0.5);
		albedo = mix(c, root_color, scalp * grow * (shade + 0.3 * dots));
		roughness = mix(0.95, 0.6, scalp);
		specular = mix(0.12, 0.25, scalp);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = specular;
#ifdef FADE
	ALPHA = 1.0 - fade;
#endif
	if (cut) {
		discard;
	}
}
