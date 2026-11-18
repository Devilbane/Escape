class_name SnowPrints
extends RefCounted
## Brief grey footprints in the snow. A print is a soft grey oval pressed into the white
## layer (see SnowCover); it stays a few seconds, then the snow fills in again. Prints are
## cheap quads that free themselves, and only so many exist at once.

const HOLD := 3.5
const FADE := 4.0
## At most this many prints at once; the oldest goes first.
const MAX := 90
## Just above the snow (which lies a few centimetres over the ground).
const HEIGHT := 0.055
const GREY := Color(0.5, 0.53, 0.6, 0.85)

static var _shape: QuadMesh
static var _boot: Texture2D
static var _live: Array = []


static func _mesh() -> QuadMesh:
	if _shape == null:
		_shape = QuadMesh.new()
		_shape.size = Vector2(0.16, 0.32)
		_shape.orientation = PlaneMesh.FACE_Y
	return _shape


## A boot print, drawn once: the broad sole in front, a gap, the heel behind, soft at the edges.
static func boot() -> Texture2D:
	if _boot == null:
		var w := 32
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := (x + 0.5) / w * 2.0 - 1.0
				var v := (y + 0.5) / h
				# The sole: an oval over the front 60 %; the heel: a smaller one at the back.
				var sole := Vector2(u / 0.9, (v - 0.32) / 0.3).length()
				var heel := Vector2(u / 0.72, (v - 0.8) / 0.16).length()
				var a := maxf(1.0 - smoothstep(0.75, 1.0, sole), 1.0 - smoothstep(0.7, 1.0, heel))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_boot = ImageTexture.create_from_image(img)
	return _boot


## Presses a print at `at` facing `heading` (radians about the up axis).
static func leave(world: Node3D, at: Vector3, heading: float, size := 1.0) -> void:
	_live = _live.filter(func(n): return is_instance_valid(n))
	while _live.size() >= MAX:
		(_live.pop_front() as Node).queue_free()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = boot()
	mat.albedo_color = GREY
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_snow", true)
	world.add_child(mi)
	mi.global_position = Vector3(at.x, HEIGHT, at.z)
	mi.rotation.y = heading
	mi.scale = Vector3(size, 1.0, size)
	_live.append(mi)
	var tw := mi.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(HOLD)
	tw.tween_property(mat, "albedo_color:a", 0.0, FADE)
	tw.tween_callback(mi.queue_free)
