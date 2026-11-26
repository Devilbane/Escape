class_name ClickRefusal
extends Node3D
## A click on open ground either walks the hero there or says why not (see Game._click).
##
## After the walk is planned, `verdict` compares where the path ends with where the player
## clicked. When the hero cannot get there, or only part of the way, it returns a short German
## text (an English entry is in scripts/lang/click_refusal.gd) and the game shows it together
## with a small red cross on the clicked spot (`mark`). The hero still walks as far as the
## path leads, so the anti-stuck behaviour of the grid path is untouched.

## A path that ends this close to the click (in tiles) counts as arriving.
const ARRIVED_TILES := 0.8
## A partial path that stops this far (in tiles) from the click is reported.
const PARTIAL_TILES := 1.5
## Seconds the cross stays.
const LIFE := 1.2
const RED := Color(1.0, 0.3, 0.25)

const WATER := "~≈;"
const MOUNTAIN := "="

const TEXT_WATER := "Das ist Wasser."
const TEXT_STEEP := "Zu steil."
const TEXT_WALL := "Eine Wand ist im Weg."
const TEXT_BLOCKED := "Da ist etwas im Weg."
const TEXT_UNREACHABLE := "Da komme ich nicht hin."
const TEXT_PARTIAL := "Weiter komme ich nicht."
const TEXT_SKY := "Dort ist nur Himmel."


## "" when the hero arrives (or is already there), else why the click is refused.
## `path` is the hero's planned way after `Player.walk_to(point)`.
static func verdict(level: Level, hero: Vector3, point: Vector3, path: Array) -> String:
	var tile := Level.TILE
	var end: Vector3 = hero if path.is_empty() else path[-1]
	var gap := Vector2(end.x - point.x, end.z - point.z).length()
	if gap <= tile * ARRIVED_TILES:
		return ""
	var cell := level.world_to_cell(point)
	var inside: bool = level.astar.is_in_boundsv(cell)
	var solid: bool = not inside or level.astar.is_point_solid(cell)
	if solid:
		return _why_solid(level, cell)
	if path.is_empty():
		return TEXT_UNREACHABLE
	if gap > tile * PARTIAL_TILES:
		return TEXT_PARTIAL
	return ""


static func _why_solid(level: Level, cell: Vector2i) -> String:
	var ch := level.cell_char(cell)
	if level.outdoor and WATER.contains(ch):
		return TEXT_WATER
	if level.outdoor and MOUNTAIN.contains(ch):
		return TEXT_STEEP
	if ch == "#":
		return TEXT_WALL
	return TEXT_BLOCKED


## A small red cross that fades out where the click was refused.
static func mark(level: Node, point: Vector3) -> Node3D:
	var cross := ClickRefusal.new()
	cross.position = Vector3(point.x, 0.15, point.z)
	level.add_child(cross)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 100
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = RED
	for turn in [PI * 0.25, -PI * 0.25]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.1, 0.04, 0.18)
		bar.mesh = box
		bar.material_override = mat
		bar.rotation.y = turn
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cross.add_child(bar)
	cross.scale = Vector3.ONE * 0.6
	var tween := cross.create_tween().set_parallel(true)
	tween.tween_property(cross, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, LIFE * 0.5).set_delay(LIFE * 0.5)
	tween.chain().tween_callback(cross.queue_free)
	return cross
