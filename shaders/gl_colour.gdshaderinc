// How the game's own shaders' colours are taken, the same on both renderers.
//
// The game's look was made on the OpenGL renderer (Compatibility), which handles the colours of a
// shader of our own in its own way: it hands the shader its colour inputs (textures and colour
// uniforms) as they are stored, as screen colours, and reads the colour the shader works out
// (ALBEDO, EMISSION) as a screen colour too, turning it into light only then. So all the
// shader's sums (a stone darkened to 0.62, a joint mixed towards moss) are done on screen
// colours, which reads darker and with more contrast than the same sums done on light.
//
// The modern renderer (Forward+) does them on light, as Godot means it to, and the very same
// shaders came out pale and flat there: grey cobbles without their dark joints, washed-out wood,
// pale pools of lamplight over the floor. So every shader of ours does it OpenGL's way on both:
// its colour inputs carry no source_color hint (both renderers then hand them over as stored),
// and its fragment() ends with
//
//     ALBEDO = gl_colour(ALBEDO);
//     EMISSION = gl_colour(EMISSION);   // only where the shader sets EMISSION
//
// which turns the screen colour into light on the modern renderer and leaves it to OpenGL, which
// does that itself. Godot's own materials (StandardMaterial3D) look the same on both already.
// tests/shader_colours.gd checks that every shader follows this.
#ifndef GL_COLOUR_INCLUDED
#define GL_COLOUR_INCLUDED

vec3 gl_colour(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	c = max(c, vec3(0.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
#endif
}

// A light value as a screen colour (gl_colour's inverse), for the modern renderer's sums.
vec3 gl_screen(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

// The glow of a lit thing (a window pane at night): `colour` (a screen colour, as the game picks
// colours) shining `strength` times as bright, as the value to give EMISSION before
// EMISSION = gl_colour(EMISSION). Turning colour * strength into light as one screen colour blows up
// past 1 (a window at 2.6 shone nine times as bright as its colour, a white-hot blob on the modern
// renderer): the colour is turned into light first and the strength scales that.
vec3 gl_glow(vec3 colour, float strength) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return colour * strength;
#else
	return gl_screen(gl_colour(colour) * strength);
#endif
}

// How opaque to draw a layer of `colour` (light, as the shader hands it to ALBEDO) that OpenGL
// draws `alpha` opaque, for a see-through layer laid over the picture (render_mode blend_mix):
// fog banks, mist. OpenGL mixes such a layer with what lies behind it as screen colours, the
// modern renderer as light, which lets a pale haze over a dark ground show far stronger there:
// the whole scene went dusty. What lies behind is not known here, so it is taken as a quarter
// of the layer's own brightness (dark ground under pale haze), which matches it closely there.
float gl_alpha(vec3 colour, float alpha) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return alpha;
#else
	float layer = max(dot(colour, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
	float behind = layer * 0.25;
	vec3 screen = gl_screen(vec3(behind, layer, 0.0));
	float mixed = gl_colour(vec3(mix(screen.x, screen.y, alpha))).x;
	return clamp((mixed - behind) / (layer - behind), 0.0, 1.0);
#endif
}
#endif
