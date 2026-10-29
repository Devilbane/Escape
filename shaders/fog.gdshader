shader_type spatial;
// Fog of war drawn over the whole screen: unseen tiles are black, tiles seen
// before but out of sight are grey, and everything in sight stays untouched.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D fog_tex : filter_linear;
uniform vec2 grid_size = vec2(16.0, 16.0);
uniform float tile = 4.0;
uniform vec3 void_color : source_color = vec3(0.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	// Sample a little below the surface so wall tops belong to the wall tile.
	vec2 uv = (world.xz / tile + 0.5) / grid_size;
	vec4 fog = texture(fog_tex, uv);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 grey = mix(void_color, vec3(lum) * vec3(0.8, 0.82, 0.9), 0.55);
	float visible = fog.r;
	float explored = fog.g;
	ALBEDO = mix(void_color, grey, explored);
	ALPHA = 1.0 - visible;
	if (depth >= 0.99999) {
		ALBEDO = void_color;
	}
}
