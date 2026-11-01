shader_type spatial;
render_mode cull_disabled;
// The same as tint.gdshader, but the part can fade, for a sneaking hero.
// See gear_material.gdshaderinc.

#define FADE
#include "res://shaders/gear_material.gdshaderinc"
