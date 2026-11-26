class_name NohpaanLife
extends Node3D
## The slow movement of Nohpaan (see Nohpaan.dress): the prayer wheels turn, the prayer flags flutter, and two sheets
## of mist slide over the meadow, thinning out round the hero (shaders/nohpaan_mist.gdshader). One node per map;
## it does a few dozen transforms and two shader uniforms a frame.

const MIST_SHADER := preload("res://shaders/nohpaan_mist.gdshader")
## Turns of a prayer wheel a second, and the sway of a flag in radians.
const WHEEL_SPEED := 0.35
const FLAG_SWAY := 0.18
## Heights of the two sheets of mist (metres), their strength and the clear space round the hero.
const MIST := [{"y": 0.35, "density": 0.38, "scale": 0.03, "drift": Vector2(0.9, 0.3)}, {"y": 1.6, "density": 0.22, "scale": 0.022, "drift": Vector2(-0.6, 0.5)}]
const CLEAR := 7.0

var level: Level
var drums: Array = []
var flags: Array = []
var _mats: Array[ShaderMaterial] = []
var _clock := 0.0


func setup(lvl: Level) -> void:
	level = lvl
	name = "NohpaanLife"
	var size := Vector2(lvl.width, lvl.height) * Level.TILE
	for layer: Dictionary in MIST:
		var quad := PlaneMesh.new()
		quad.size = size
		var mat := ShaderMaterial.new()
		mat.shader = MIST_SHADER
		mat.set_shader_parameter("density", layer.density)
		mat.set_shader_parameter("scale", layer.scale)
		mat.set_shader_parameter("drift", layer.drift)
		mat.set_shader_parameter("clear_radius", CLEAR)
		var sheet := MeshInstance3D.new()
		sheet.mesh = quad
		sheet.material_override = mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = Vector3(size.x * 0.5 - Level.TILE * 0.5, layer.y, size.y * 0.5 - Level.TILE * 0.5)
		sheet.name = "Mist"
		add_child(sheet)
		_mats.append(mat)
	drums = lvl.get_meta("nohpaan_drums", [])
	for flag: Node3D in lvl.find_children("Flag", "MeshInstance3D", true, false):
		flags.append(flag)


func _process(delta: float) -> void:
	_clock += delta
	for drum: Node3D in drums:
		if is_instance_valid(drum):
			drum.rotation.y += TAU * WHEEL_SPEED * delta
	for i in flags.size():
		var flag: Node3D = flags[i]
		if is_instance_valid(flag):
			flag.rotation.z = sin(_clock * 2.3 + float(i) * 0.7) * FLAG_SWAY
	var at := Vector3.ZERO
	if level.player != null and is_instance_valid(level.player):
		at = level.player.global_position
	for mat in _mats:
		mat.set_shader_parameter("hero", at)
