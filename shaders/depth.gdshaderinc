// Reading the depth buffer on both renderers. OpenGL (Compatibility) keeps depth as 0 near to
// 1 far and its clip space runs from -1 to 1; the modern renderer (Forward+) keeps it reversed,
// 1 near to 0 far, in a clip space from 0 to 1. Every shader that looks up what lies behind a
// pixel goes through here, so it works on either.

// The clip-space spot of a pixel and its depth-buffer value.
vec3 depth_ndc(vec2 screen_uv, float depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return vec3(screen_uv * 2.0 - 1.0, depth * 2.0 - 1.0);
#else
	return vec3(screen_uv * 2.0 - 1.0, depth);
#endif
}

// Whether nothing was drawn at a pixel with this depth-buffer value (the far plane).
bool depth_is_far(float depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return depth >= 0.99999;
#else
	return depth <= 0.00001;
#endif
}
