shader_type spatial;
#include "res://shaders/gl_colour.gdshaderinc"
// A spruce's fronds (see Fern.needle_tree_mesh): the frond picture, cut out where it is empty,
// times the frond's colour, both sides drawn. A spruce is too dense to be lit leaf by leaf (its own
// shadow would turn it black inside), so it takes no shadows; its lower tiers are darker instead.
//
// The colour, a patchwork of greens: the mesh gives each frond only its brightness (the vertex
// colour) and, in UV2, which fern of the tree it belongs to and which way round the trunk it points
// (0 to 1 each). The colour is chosen here, from where the tree stands, so no two spruces share it
// although they share a mesh:
// - every fern is cut into three wedges round the trunk, each wedge one of five greens, from a fresh
//   green to a dark blue-green; the wedges turn and the greens change from tree to tree,
// - some ferns are dark all through, some have fronds of three different greens,
// - and the whole tree leans a little greener or bluer.
//
// The wind stirs the branches gently: each frond's outer part sways up to about ten centimetres, more
// towards its tip, the trunk and the branches' roots stay put. Every branch has its own beat, so
// the crown ripples instead of rocking as one.
//
// Snow (see SnowCover, which keeps `amount` and the rest of snow.gdshaderinc in step): it lies on
// the fronds where they run level, the shoulders of the tiers, in drifts that join up as it
// deepens, and only on the leaflets themselves (the cut-out shape). It stays put while the
// branches sway (its pattern is taken from where the frond rests), and keeps off near fires and
// under shelters like the snow on the ground. The overlay is not laid on the spruces (it cannot
// see the cut-out leaflets nor follow the sway).
render_mode cull_disabled, shadows_disabled;

#include "res://shaders/snow.gdshaderinc"

uniform sampler2D albedo_tex : filter_linear_mipmap_anisotropic, repeat_enable;
// How far a branch tip one metre out from the trunk sways (metres).
uniform float sway = 0.08;
// The spruce's greens, from fresh to a dark blue-green.
uniform vec3 green_1 = vec3(0.38, 0.68, 0.3);
uniform vec3 green_2 = vec3(0.27, 0.6, 0.34);
uniform vec3 green_3 = vec3(0.19, 0.53, 0.42);
uniform vec3 green_4 = vec3(0.14, 0.45, 0.48);
uniform vec3 green_5 = vec3(0.11, 0.36, 0.33);
// How many of a tree's ferns are dark all through, and how many have fronds of three greens.
// The far model (see Fern.FAR_WIDTH): its fronds are broader and have fewer segments, so its snow
// stripe is narrowed to the near one's width and its level test is looser, to look the same.
uniform bool far_model = false;
uniform float dark_ferns = 0.12;
uniform float mixed_ferns = 0.25;

varying vec3 tint;
varying vec3 rest_pos;
varying vec3 rest_normal;
varying float shade;
varying float cap;

// A number from 0 to 1 for `p`, the same every time.
float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	vec2 out_from_trunk = VERTEX.xz;
	float r = length(out_from_trunk);
	vec2 root = MODEL_MATRIX[3].xz;
	float round_trunk = atan(out_from_trunk.y, out_from_trunk.x);

	// The tree's own dice.
	float s1 = rand(root);
	float s2 = rand(root + 17.3);
	float s3 = rand(root + 41.9);
	vec3 greens[5] = vec3[5](green_1, green_2, green_3, green_4, green_5);
	vec2 ids = UV2;
	// The fern's wedge round the trunk, turned for this tree, and its green.
	float wedge = floor(fract(ids.y + s1) * 3.0);
	float pick = rand(vec2(ids.x * 91.7 + wedge * 7.1, s2 * 13.1));
	vec3 colour = greens[int(pick * 4.999)];
	float fern = fract(ids.x * 13.7 + s1 * 5.3);
	if (fern < dark_ferns) {
		colour = green_5 * 0.85;
	} else if (fern < dark_ferns + mixed_ferns) {
		// Fronds of three greens, one after the other round the fern.
		float frond = floor(fract(ids.y * 12.0 + s3) * 3.0);
		colour = greens[int(mod(floor(pick * 5.0) + frond * 2.0, 5.0))];
	}
	// The whole tree leans greener or bluer.
	colour = mix(colour, s3 < 0.5 ? green_1 : green_4, abs(s3 - 0.5) * 0.4);
	tint = colour * COLOR.rgb;
	rest_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	shade = COLOR.r;
	// How near the tree's tip (see Fern.CAP_DEPTH): its snow cap.
	cap = COLOR.a;

	// Nothing near the trunk moves; the outer branches move most.
	float give = smoothstep(0.12, 1.3, r);
	// Each branch (its direction round the trunk and its height) has its own phase.
	float branch = round_trunk * 2.0 + VERTEX.y * 1.7;
	float t = TIME * 1.3 + root.x * 0.37 + root.y * 0.29;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + root.x * 0.05);
	vec2 push = vec2(sin(t + branch), 0.6 * cos(t * 0.83 + branch * 1.3)) * sway * gust * give * r;
	VERTEX.xz += push;
	VERTEX.y += 0.4 * sway * gust * give * r * sin(t * 1.21 + branch * 0.7);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * tint;
	if (amount > 0.001) {
		// The fronds' normals lean up already (see Fern._card): a level frond is nearly 1.
		float level = far_model ? smoothstep(0.45, 0.75, rest_normal.y) : smoothstep(0.6, 0.88, rest_normal.y);
		// Only on the upper side: from below, a frond shows its green.
		float above = step(0.0, dot(CAMERA_POSITION_WORLD - rest_pos, rest_normal));
		float n = snow_noise(rest_pos.xz * 2.2 + rest_pos.y * 1.3) * 0.6 + snow_noise(rest_pos.xz * 7.0 + 3.0) * 0.4;
		// The upper tiers are open to the sky, the lower ones lie under them (`shade` runs from the
		// foot's 0.72 to the top's 1.0, see Fern.NEEDLE_FOOT_SHADE).
		float tier = clamp((shade - 0.72) / 0.28, 0.0, 1.0);
		// The crown's top (the last tiers and the leader) is steep and short, so it is given more:
		// a looser level test, so it takes snow on its steeper fronds, and a head start on `lies`.
		float crown = smoothstep(0.75, 1.0, tier);
		level = max(level, crown * smoothstep(0.3, 0.7, rest_normal.y));
		// The snow cap: the tip and the upper tiers take snow on their steeper fronds too, and
		// farther along them, so a small white hat sits on the tree top.
		float hat = smoothstep(0.2, 1.0, cap) * smoothstep(0.0, 0.25, amount);
		level = max(level, hat * smoothstep(0.1, 0.5, rest_normal.y));
		float lies = level * above * amount * 0.85 + (n - 0.5) * 0.55 + (tier - 0.5) * 0.25 + crown * 0.2 + hat * 0.35;
		if (lies > 0.5 && !snow_melted(rest_pos, n) && !snow_sheltered(rest_pos)) {
			vec3 snow_albedo;
			vec3 snow_normal;
			vec3 snow_glow;
			snow_look(rest_pos, vec3(0.0, 1.0, 0.0), VIEW_MATRIX, TIME, snow_albedo, snow_normal, snow_glow);
			// The lower tiers, in the crown's shade, are greyer (see Fern's NEEDLE_FOOT_SHADE).
			snow_albedo *= mix(0.65, 1.0, shade);
			// Along each frond's middle, wider the deeper it lies, with a crisp edge (no grey
			// half-snow). It lies on the outer part of the frond, towards the tips, and the roots
			// near the trunk stay green, so every tier shows green at the centre and white
			// outside, with green between one tier and the next (not a pillar of snow).
			float wide = 0.1 + 0.14 * smoothstep(0.5, 0.9, lies);
			if (far_model) {
				wide *= 0.58;
			}
			wide += crown * 0.12 + hat * 0.16;
			float ridge = 1.0 - smoothstep(wide - 0.03, wide, abs(UV.x - 0.5));
			float thick = smoothstep(0.5, 0.53, lies) * ridge * smoothstep(0.3 - max(crown, hat) * 0.25, 0.45 - max(crown, hat) * 0.25, UV.y) * smoothstep(1.0, 0.85, UV.y) * mix(0.85, 1.0, tex.r);
			ALBEDO = mix(ALBEDO, snow_albedo, thick);
			EMISSION = snow_glow * thick;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
			// The snow on the ground, the roofs and the bushes gives its moonlit glow (snow_look's
			// emission) as it is, not turned into light by gl_colour; so does this snow (gl_screen
			// undoes the gl_colour below), or on a dark night the spruces stood black and bare over
			// the pale ground.
			EMISSION = gl_screen(EMISSION);
#endif
			// Lit as the snow on the ground is, from above, not as the leaning frond under it.
			NORMAL = normalize(mix(NORMAL, snow_normal, thick));
		}
	}
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.9;
	ALBEDO = gl_colour(ALBEDO);
	EMISSION = gl_colour(EMISSION);
}
