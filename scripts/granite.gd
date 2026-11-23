class_name Granite
extends RefCounted
## The natural granite of the village wall and its gate posts (see WallBrick): hewn blocks of the
## stonemason's size (StoneBlock) with rounded, chipped edges and slightly uneven faces, in a few
## shades of grey granite, speckled by shaders/granite.gdshader. A handful of meshes (VARIANTS)
## are made once and shared, so no two neighbouring stones are the same shape.

## Neutral grey granite with a cooler and a slightly lighter one, so a wall does not look printed.
const SHADES: Array[Color] = [Color(0.55, 0.56, 0.57), Color(0.58, 0.58, 0.58), Color(0.5, 0.52, 0.54), Color(0.56, 0.57, 0.56)]
const SHADER := preload("res://shaders/granite.gdshader")
## How many different stone shapes there are.
const VARIANTS := 6
## How round the edges are (metres), and how deep the chips go on a flat face, at an edge and at a corner.
const RADIUS := 0.095
const CHIPS := [0.008, 0.035, 0.06]

static var _meshes := {}
static var _materials := {}


## The stone of a variant (any number): a block lying along x with its bottom middle at the origin,
## as large as StoneBlock's, so the cracks of the wall (see WallCracks) sit on its faces.
static func block_mesh(variant: int) -> ArrayMesh:
	var smooth := Graphics.preset != Graphics.PERFORMANCE
	var key := absi(variant) % VARIANTS + (VARIANTS if smooth else 0)
	if not _meshes.has(key):
		var half := Vector3(StoneBlock.CELL, StoneBlock.HEIGHT * 0.5, StoneBlock.CELL * 0.5) - Vector3.ONE * StoneBlock.JOINT * 0.5
		var splits := Vector3i(3, 1, 1) if smooth else Vector3i(2, 1, 1)
		_meshes[key] = RoundedBox.make(half, RADIUS, splits, CHIPS, 7919 + key * 131, Vector3(0, StoneBlock.HEIGHT * 0.5, 0), smooth)
	return _meshes[key]


## The granite material of a shade, shared.
static func material(shade: Color) -> ShaderMaterial:
	var key := shade.to_html()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_color", shade)
		_materials[key] = m
	return _materials[key]
