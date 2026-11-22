shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// The same as hair.gdshader, but it turns grey and can fade, for a sneaking hero.
// See hair.gdshaderinc.

#define FADE
#include "res://shaders/hair.gdshaderinc"
