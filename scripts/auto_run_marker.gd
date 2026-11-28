class_name AutoRunMarker
extends Node3D
## What shows where the hero is running to (see AutoRun): a pulsing golden ring on the goal and a
## dotted line along the rest of the way, which shortens as the hero goes. Both are drawn over
## whatever stands in front, like the red cross of a refused click (see ClickRefusal).

## Metres between two dots of the route.
const SPACING := 1.4
const MAX_DOTS := 200
const GOLD := Color(1.0, 0.82, 0.4)
const HEIGHT := 0.15

var player: Player
var goal := Vector3.ZERO
var _ring: MeshInstance3D
var _dots: MultiMeshInstance3D
var _time := 0.0
var _ending := false


static func make(level: Node, hero: Player, target: Vector3) -> AutoRunMarker:
	var marker := AutoRunMarker.new()
	marker.player = hero
	marker.goal = target
	level.add_child(marker)
	return marker


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 100
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(GOLD, 0.9)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.8
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.scale = Vector3(1.0, 0.1, 1.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(goal.x, HEIGHT, goal.z)
	add_child(_ring)
	var dot := CylinderMesh.new()
	dot.top_radius = 0.14
	dot.bottom_radius = 0.14
	dot.height = 0.03
	dot.radial_segments = 8
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dot
	multi.instance_count = MAX_DOTS
	multi.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = multi
	_dots.material_override = mat
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)


func _process(delta: float) -> void:
	_time += delta
	if _ending:
		return
	if not is_instance_valid(player):
		queue_free()
		return
	_ring.scale = Vector3(1.0, 0.1, 1.0) * (1.0 + 0.1 * sin(_time * 6.0))
	var multi := _dots.multimesh
	var count := 0
	var at := player.global_position
	var carry := SPACING * 0.6
	for next in player.path:
		var leg := Vector2(next.x - at.x, next.z - at.z)
		var length := leg.length()
		var along := carry
		while along < length and count < MAX_DOTS:
			var p := at + (next - at) * (along / length)
			multi.set_instance_transform(count, Transform3D(Basis.IDENTITY, Vector3(p.x, HEIGHT, p.z)))
			count += 1
			along += SPACING
		carry = along - length
		at = next
	multi.visible_instance_count = count


## The run is over: the dots go and the ring fades out.
func finish() -> void:
	_ending = true
	_dots.visible = false
	var mat := _ring.material_override as StandardMaterial3D
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
