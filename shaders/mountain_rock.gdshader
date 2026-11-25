shader_type spatial;
// Both sides drawn, as the rock's builders always did: a face seen from
// behind never leaves a hole.
render_mode cull_disabled;
#include "res://shaders/gl_colour.gdshaderinc"
// Weathered mountain rock, to match the aged stone of the village and the
// graveyard (aged_stone.gdshader): the high mountains (Mountains) and the
// mountain the dragon's lair is dug into (LairMountain) keep their low-poly
// facets and the colours their builders paint on each face (rock, moss,
// snow, earth, passed in as vertex colours), and this lays the same kind of
// weather over them that the village stone wears:
// - grain and pits, so a face reads as stone instead of flat paint,
// - strata: pale and dark layers of rock running across the steep faces,
// - grime: earthy stains at the foot of the rock,
// - streaks: dark runs of rain water down the steep faces,
// - moss in patches on what faces up, low down,
// - lichen: pale and orange crusts on the bare rock, as on the gravestones.
// Snow (the pale, colourless faces up high) stays clean.

#include "res://shaders/mountain_rock.gdshaderinc"
