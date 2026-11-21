shader_type spatial;
// A spruce's fronds (see Fern.needle_tree_mesh): the frond picture, cut out where it is empty,
// times the vertex colours, both sides drawn. A spruce is too dense to be lit leaf by leaf (its own
// shadow would turn it black inside), so it takes no shadows; its lower tiers are darker instead.
//
// The wind stirs the branches very gently: each frond's outer part sways a few centimetres, more
// towards its tip, the trunk and the branches' roots stay put. Every branch has its own beat, so
// the crown ripples instead of rocking as one.
render_mode cull_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
// How far a branch tip one metre out from the trunk sways (metres).
uniform float sway = 0.035;

void vertex() {
	vec2 out_from_trunk = VERTEX.xz;
	float r = length(out_from_trunk);
	// Nothing near the trunk moves; the outer branches move most.
	float give = smoothstep(0.12, 1.3, r);
	vec2 root = MODEL_MATRIX[3].xz;
	// Each branch (its direction round the trunk and its height) has its own phase.
	float branch = atan(out_from_trunk.y, out_from_trunk.x) * 2.0 + VERTEX.y * 1.7;
	float t = TIME * 1.3 + root.x * 0.37 + root.y * 0.29;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + root.x * 0.05);
	vec2 push = vec2(sin(t + branch), 0.6 * cos(t * 0.83 + branch * 1.3)) * sway * gust * give * r;
	VERTEX.xz += push;
	VERTEX.y += 0.4 * sway * gust * give * r * sin(t * 1.21 + branch * 0.7);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.9;
}
