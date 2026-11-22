// Inside the houses no weather shows (see IndoorMask): the fog clouds, the rain, the snowflakes,
// the drifting mist and the falling leaves leave out every spot that lies in a self-built house or
// a village room one walks into, below the top of it. From in there the weather still shows outside,
// through the windows, the open door and over the walls.
// R of indoor_mask is that top over each spot, in 255ths of INDOOR_SCALE metres, 0 out in the open.
// indoor_area: xy = the world x/z of the mask's first pixel's corner, z = metres per pixel, w = 1
// while there is a mask at all.
global uniform sampler2D indoor_mask;
global uniform vec4 indoor_area;
const float INDOOR_SCALE = 16.0;

bool indoors(vec3 p) {
	if (indoor_area.w < 0.5) {
		return false;
	}
	ivec2 size = textureSize(indoor_mask, 0);
	ivec2 px = ivec2(floor((p.xz - indoor_area.xy) / indoor_area.z));
	if (px.x < 0 || px.y < 0 || px.x >= size.x || px.y >= size.y) {
		return false;
	}
	// 0 is the open air (the ground there may lie a little below 0 m).
	float top = texelFetch(indoor_mask, px, 0).r * INDOOR_SCALE;
	return top > 0.0 && p.y < top;
}

// The world spot of the solid surface seen at a pixel (from the depth buffer).
vec3 indoor_surface(sampler2D depth_tex, vec2 screen_uv, mat4 inv_projection, mat4 inv_view) {
	float depth = texture(depth_tex, screen_uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth * 2.0 - 1.0);
#else
	// The modern renderer keeps depth in a clip space from 0 to 1 (see depth.gdshaderinc).
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return (inv_view * vec4(view.xyz, 1.0)).xyz;
}
