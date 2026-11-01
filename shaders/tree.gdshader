shader_type spatial;
// Natural-looking trees from the flat low-poly kit models. The kit colours
// every tree from a palette texture, so each facet is one even, glossy
// colour and the trees look like moulded plastic. This keeps the palette
// colour and adds, in world space so no two trees look alike:
//   foliage: clusters of lighter and darker leaves, fine leaf speckle, a
//            touch less saturation, a matt surface and a slow sway in the wind;
//   bark:    vertical grain with dark cracks and knots, and bump lighting.
// Leaves and bark share one mesh, so they are told apart by colour: the
// palette's leaves are vivid, its bark and dead wood are greyish.

#include "res://shaders/detail.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
// 1 for the swaying, speckled foliage; 0 leaves the shape alone (stumps).
uniform float wind = 1.0;

varying vec3 world_pos;
varying float leafy;

// How vivid a colour is, 0 for grey up to 1 for a pure colour.
float saturation(vec3 c) {
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	return hi > 0.0 ? (hi - lo) / hi : 0.0;
}

void vertex() {
	vec3 c = textureLod(albedo_tex, UV, 0.0).rgb;
	leafy = smoothstep(0.55, 0.7, saturation(c));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The crown sways a little, more the higher up it is; the trunk stands.
	float h = max(wp.y - MODEL_MATRIX[3].y, 0.0);
	vec2 root = MODEL_MATRIX[3].xz;
	float gust = sin(TIME * 1.1 + root.x * 0.6 + root.y * 0.4) + 0.5 * sin(TIME * 2.3 + root.y * 1.3);
	vec3 sway = vec3(gust, 0.0, 0.6 * cos(TIME * 0.9 + root.x * 0.8)) * 0.012 * h * leafy * wind;
	wp += sway;
	world_pos = wp;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_pos;
	float px = length(fwidth(p));
	vec3 c = texture(albedo_tex, UV).rgb;
	float h = 0.0;
	if (leafy > 0.5) {
		// Leaf clusters a few hands across, lighter where they catch the sky.
		float clusters = fbm(p * 1.4);
		float leaves = vnoise(p * 9.0) * band(9.0, px);
		float speck = vnoise(p * 28.0) * band(28.0, px);
		// Gaps down into the shade between the clusters.
		float gaps = smoothstep(0.6, 0.85, vnoise(p * 3.3 + 5.0));
		float shade = 1.0 + 0.44 * (clusters - 0.5) + 0.3 * (leaves - 0.5) + 0.14 * (speck - 0.5) - 0.26 * gaps;
		// The kit's leaves are a vivid, even colour; real ones are a shade
		// greyer, and drift warmer or cooler from one cluster to the next.
		c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.22);
		c *= mix(vec3(1.0, 0.96, 0.82), vec3(0.9, 1.0, 1.05), fbm(p * 0.6 + 20.0));
		c *= shade;
		h = 0.05 * clusters + 0.015 * leaves + 0.004 * speck - 0.03 * gaps;
		ROUGHNESS = 0.95;
		SPECULAR = 0.15;
	} else {
		// Bark: grain running up the trunk, dark cracks, knots and lichen.
		vec3 q = vec3(p.x * 14.0, p.y * 1.6, p.z * 14.0);
		float grain = vnoise(q) * 0.6 + vnoise(q * 2.1 + 3.0) * 0.4;
		float cracks = smoothstep(0.3, 0.1, vnoise(vec3(p.x * 20.0, p.y * 3.0, p.z * 20.0) + 7.0));
		float knots = smoothstep(0.7, 0.9, vnoise(p * 2.5 + 11.0));
		float lichen = smoothstep(0.68, 0.82, fbm(p * 2.0 + 31.0));
		float gb = band(14.0, px);
		float shade = 1.0 + 0.3 * (grain - 0.5) * gb - 0.35 * cracks * gb - 0.15 * knots;
		c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.15) * shade;
		c = mix(c, vec3(0.55, 0.6, 0.42) * (0.8 + 0.4 * grain), lichen * 0.45);
		h = (0.02 * grain - 0.025 * cracks) * gb - 0.01 * knots;
		ROUGHNESS = 0.9 + 0.1 * grain;
		SPECULAR = 0.2;
	}
	ALBEDO = c;
	NORMAL = bumped(NORMAL, dFdx(VERTEX), dFdy(VERTEX), dFdx(h), dFdy(h));
}
