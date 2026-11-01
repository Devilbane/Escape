shader_type spatial;
render_mode cull_disabled;
// The same as hair.gdshader, but it can fade, for a sneaking hero.
// See hair.gdshaderinc.

#define FADE
#include "res://shaders/hair.gdshaderinc"
