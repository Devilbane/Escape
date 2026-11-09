// The see-through circle around the hero (see HeroReveal): stone that stands between the camera and
// the hero drops out in a soft-edged disc around the hero, so the hero and the floor around them are
// never hidden behind a wall top or a wall, even in a narrow corridor under a low camera.
// hero_reveal holds the hero's chest (xyz, world space) and the disc's radius in metres at the hero's
// depth (w); a radius of 0 switches it off.
global uniform vec4 hero_reveal;

// True for a pixel that lies inside the disc and so must be dropped. `view_pos` is the pixel's
// view-space position (VERTEX in fragment()), `view` the VIEW_MATRIX. The edge is a fine ordered
// dither, so the stone stays an ordinary solid one in the opaque pass.
bool reveal_cut(vec3 view_pos, mat4 view, vec2 frag) {
	float radius = hero_reveal.w;
	if (radius <= 0.0) {
		return false;
	}
	vec3 h = (view * vec4(hero_reveal.xyz, 1.0)).xyz;
	// Only what stands nearer to the camera than the hero can hide the hero.
	if (view_pos.z < h.z + 0.4) {
		return false;
	}
	// The pixel, seen along the same line of sight but at the hero's depth.
	vec2 at_hero = view_pos.xy * (h.z / view_pos.z);
	float cut = 1.0 - smoothstep(radius * 0.55, radius, length(at_hero - h.xy));
	if (cut <= 0.0) {
		return false;
	}
	ivec2 q = ivec2(frag) % 4;
	int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(bayer[q.y * 4 + q.x]) + 0.5) / 16.0 < cut;
}
