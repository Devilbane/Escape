shader_type spatial;
// Short cattle hair for the cows and the bull (see FarmAnimal._fur): fine strands that run down the
// body, patches of lighter and darker coat, darker legs, no shine. The model has no UV
// coordinates, so every texture is projected from three sides in the model's own space.

uniform vec4 base_color : source_color = vec4(1.0);
// Hair strands (light/dark streaks, seamless) and their bump map, and broad blotches of coat colour.
uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D strand_bumps : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D blotches : source_color, filter_linear_mipmap, repeat_enable;
// Strand texture repeats per model unit; the blotches repeat this many times slower.
uniform float tile = 5.0;
uniform float blotch_slower = 7.0;
uniform float bump_strength = 2.5;
// Below `leg_top` (model height) the coat turns darker, down to `leg_tint` at `leg_bottom`.
uniform float leg_top = 0.9;
uniform float leg_bottom = 0.2;
uniform vec3 leg_tint : source_color = vec3(0.62, 0.58, 0.55);
// How much a soft fuzzy edge lightens the coat where it is seen at a slant.
uniform float fuzz = 0.18;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

vec3 sides(vec3 w, vec3 p, sampler2D tex, float scale) {
	// Hair runs along v: down the flanks and the legs, along the spine on the back.
	vec3 x = texture(tex, p.zy * scale).rgb;
	vec3 y = texture(tex, p.xz * scale).rgb;
	vec3 z = texture(tex, p.xy * scale).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec3 w = pow(abs(normalize(local_normal)), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 hair = sides(w, local_pos, strands, tile);
	vec3 patch = sides(w, local_pos, blotches, tile / blotch_slower);
	vec3 col = base_color.rgb * hair * mix(vec3(0.7), vec3(1.25), patch);
	float low = smoothstep(leg_top, leg_bottom, local_pos.y);
	col *= mix(vec3(1.0), leg_tint, low);
	float slant = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col += base_color.rgb * slant * fuzz;
	ALBEDO = col;
	NORMAL_MAP = sides(w, local_pos, strand_bumps, tile);
	NORMAL_MAP_DEPTH = bump_strength;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
	METALLIC = 0.0;
}
