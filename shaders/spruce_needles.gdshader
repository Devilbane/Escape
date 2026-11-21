shader_type spatial;
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
render_mode cull_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
// How far a branch tip one metre out from the trunk sways (metres).
uniform float sway = 0.08;
// The spruce's greens, from fresh to a dark blue-green.
uniform vec3 green_1 : source_color = vec3(0.38, 0.68, 0.3);
uniform vec3 green_2 : source_color = vec3(0.27, 0.6, 0.34);
uniform vec3 green_3 : source_color = vec3(0.19, 0.53, 0.42);
uniform vec3 green_4 : source_color = vec3(0.14, 0.45, 0.48);
uniform vec3 green_5 : source_color = vec3(0.11, 0.36, 0.33);
// How many of a tree's ferns are dark all through, and how many have fronds of three greens.
uniform float dark_ferns = 0.12;
uniform float mixed_ferns = 0.25;

varying vec3 tint;

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
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.9;
}
