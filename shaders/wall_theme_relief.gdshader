shader_type spatial;
// The same look for the relief that sticks out of the walls (shards, skulls, bones):
// without the see-through fade, because there are hundreds of them and every mesh
// with an instance uniform counts against the engine's limit.
#define NO_FADE
#include "res://shaders/wall_theme.gdshaderinc"
